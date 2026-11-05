import Foundation
import Observation

/// Résultat d'exécution d'un plan de nettoyage validé.
public struct ExecutionReport: Sendable, Equatable {
    public let planId: UUID
    public let succeededCount: Int
    public let failedCount: Int
    public let totalBytesFreed: Int64
    public let logEntries: [AuditLogEntry]

    public init(
        planId: UUID,
        succeededCount: Int,
        failedCount: Int,
        totalBytesFreed: Int64,
        logEntries: [AuditLogEntry]
    ) {
        self.planId = planId
        self.succeededCount = succeededCount
        self.failedCount = failedCount
        self.totalBytesFreed = totalBytesFreed
        self.logEntries = logEntries
    }
}

/// File d'attente de préparation (`StagingQueue`) et moteur d'exécution contrôlée (`ActionEngine`).
/// Aucune opération de nettoyage n'est exécutée sans validation préalable par `SafetyEngine`.
@Observable
@MainActor
public final class StagingQueue {
    public private(set) var items: [ScanCandidate] = []
    public var preferredMode: FileActionMode = .moveToTrash
    public private(set) var lastExecutionReport: ExecutionReport?

    public init(items: [ScanCandidate] = []) {
        self.items = items
    }

    /// Nombre d'éléments actuellement sélectionnés dans le panier.
    public var selectedItems: [ScanCandidate] {
        items.filter(\.isSelected)
    }

    /// Volume total sélectionné en octets.
    public var selectedBytes: Int64 {
        selectedItems.reduce(0) { $0 + $1.sizeBytes }
    }

    /// Indique si le panier contient au moins un élément à risque conditionnel.
    public var requiresExplicitConfirmation: Bool {
        selectedItems.contains { $0.safetyLevel == .conditional }
    }

    /// Ajoute ou met à jour un candidat dans le panier de staging.
    public func addOrUpdate(_ candidate: ScanCandidate) {
        guard candidate.safetyLevel != .protected else { return }
        if let index = items.firstIndex(where: { $0.path == candidate.path }) {
            items[index] = candidate
        } else {
            items.append(candidate)
        }
    }

    /// Inverse l'état de sélection d'un élément s'il n'est pas protégé.
    public func toggleSelection(for candidateId: UUID) {
        guard let index = items.firstIndex(where: { $0.id == candidateId }) else { return }
        guard items[index].safetyLevel != .protected else { return }
        items[index].isSelected.toggle()
    }

    /// Désélectionne tous les éléments de niveau `.conditional` pour ne conserver que les éléments `.safe`.
    public func deselectConditionalItems() {
        for index in items.indices where items[index].safetyLevel == .conditional {
            items[index].isSelected = false
        }
    }

    /// Sélectionne tous les éléments non protégés présents dans le panier.
    public func selectAllItems() {
        for index in items.indices where items[index].safetyLevel != .protected {
            items[index].isSelected = true
        }
    }

    /// Retire un élément du panier.
    public func remove(candidateId: UUID) {
        items.removeAll { $0.id == candidateId }
    }

    /// Vide le panier de préparation.
    public func clear() {
        items.removeAll()
    }

    /// Construit un plan d'exécution immuable (`StagingPlan`) à partir des éléments sélectionnés.
    public func buildPlan() -> StagingPlan {
        StagingPlan(
            candidates: selectedItems,
            actionMode: preferredMode
        )
    }

    /// Exécute le plan après validation stricte par `SafetyEngine`, et journalise chaque opération dans `DatabaseManager`.
    /// - Parameters:
    ///   - moduleName: Nom du module déclencheur.
    ///   - safetyEngine: Moteur de sécurité.
    ///   - database: Gestionnaire SQLite d'audit.
    ///   - customTrashDirectory: Répertoire de corbeille/quarantaine personnalisé (utile pour les tests d'intégration ou environnements sans corbeille volume).
    public func executeCurrentPlan(
        moduleName: String,
        safetyEngine: SafetyEngine,
        database: DatabaseManager,
        customTrashDirectory: URL? = nil
    ) async throws -> ExecutionReport {
        let plan = buildPlan()
        try safetyEngine.validate(plan: plan)

        var succeeded = 0
        var failed = 0
        var freedBytes: Int64 = 0
        var logs: [AuditLogEntry] = []
        let fm = FileManager.default

        for candidate in plan.candidates {
            let sourceURL = URL(fileURLWithPath: candidate.path)
            var destinationPath: String?
            var status = "SUCCESS"
            var errorText: String?
            var itemFreed: Int64 = 0

            do {
                // 1. Re-vérifie unitairement la sécurité juste avant l'opération
                let eval = safetyEngine.evaluate(path: candidate.path, category: candidate.category)
                if eval.level == .protected {
                    throw SafetyValidationError.protectedItemInPlan(path: candidate.path, reason: eval.reason)
                }

                // 2. Garde pré-vol : anti-symlink et vérification des applications en cours d'exécution
                let processGuard = ActiveProcessGuard(activeBundleIdentifiers: safetyEngine.runningBundleIdentifiers)
                try processGuard.verifyPreFlight(candidate: candidate, safetyEngine: safetyEngine)

                switch plan.actionMode {
                case .moveToTrash:
                    if let customTrashDirectory {
                        try fm.createDirectory(at: customTrashDirectory, withIntermediateDirectories: true)
                        let targetURL = customTrashDirectory.appendingPathComponent("\(UUID().uuidString)-\(sourceURL.lastPathComponent)")
                        try fm.moveItem(at: sourceURL, to: targetURL)
                        destinationPath = targetURL.path
                    } else {
                        var resultingURL: NSURL?
                        try fm.trashItem(at: sourceURL, resultingItemURL: &resultingURL)
                        destinationPath = (resultingURL as URL?)?.path
                    }
                    itemFreed = candidate.sizeBytes
                    succeeded += 1
                    freedBytes += itemFreed

                case .quarantineFolder:
                    let qURL = customTrashDirectory ?? FileManager.default.temporaryDirectory.appendingPathComponent("MacCareQuarantine", isDirectory: true)
                    try fm.createDirectory(at: qURL, withIntermediateDirectories: true)
                    let targetURL = qURL.appendingPathComponent("\(UUID().uuidString)-\(sourceURL.lastPathComponent)")
                    try fm.moveItem(at: sourceURL, to: targetURL)
                    destinationPath = targetURL.path
                    itemFreed = candidate.sizeBytes
                    succeeded += 1
                    freedBytes += itemFreed

                case .permanentDelete:
                    try fm.removeItem(at: sourceURL)
                    itemFreed = candidate.sizeBytes
                    succeeded += 1
                    freedBytes += itemFreed

                case .restoreFromTrash:
                    break
                }
            } catch {
                status = "FAILED"
                errorText = error.localizedDescription
                failed += 1
            }

            let logEntry = AuditLogEntry(
                module: moduleName,
                actionMode: plan.actionMode,
                originalPath: candidate.path,
                destinationPath: destinationPath,
                bytesFreed: itemFreed,
                status: status,
                errorMessage: errorText
            )
            try? await database.insertAuditLog(logEntry)
            logs.append(logEntry)
        }

        // Retire du panier les éléments traités avec succès
        let succeededPaths = Set(logs.filter { $0.status == "SUCCESS" }.map(\.originalPath))
        items.removeAll { succeededPaths.contains($0.path) }

        let report = ExecutionReport(
            planId: plan.id,
            succeededCount: succeeded,
            failedCount: failed,
            totalBytesFreed: freedBytes,
            logEntries: logs
        )
        self.lastExecutionReport = report
        return report
    }

    /// Restaure un élément déplacé dans la Corbeille ou en quarantaine vers son chemin d'origine à partir d'une entrée `AuditLogEntry`,
    /// et enregistre l'opération de restauration dans `DatabaseManager`.
    @discardableResult
    public func restoreFromTrash(
        logEntry: AuditLogEntry,
        database: DatabaseManager
    ) async throws -> AuditLogEntry {
        guard let trashPath = logEntry.destinationPath, !trashPath.isEmpty else {
            throw PreFlightSecurityError.restorationSourceMissing(trashPath: "Inconnu")
        }

        let fm = FileManager.default
        guard fm.fileExists(atPath: trashPath) else {
            throw PreFlightSecurityError.restorationSourceMissing(trashPath: trashPath)
        }

        guard !fm.fileExists(atPath: logEntry.originalPath) else {
            throw PreFlightSecurityError.restorationTargetAlreadyExists(originalPath: logEntry.originalPath)
        }

        let sourceURL = URL(fileURLWithPath: trashPath)
        let targetURL = URL(fileURLWithPath: logEntry.originalPath)
        let parentDir = targetURL.deletingLastPathComponent()

        try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
        try fm.moveItem(at: sourceURL, to: targetURL)

        let restoredLog = AuditLogEntry(
            module: logEntry.module,
            actionMode: .restoreFromTrash,
            originalPath: logEntry.originalPath,
            destinationPath: trashPath,
            bytesFreed: 0,
            status: "RESTORED"
        )
        try await database.insertAuditLog(restoredLog)
        return restoredLog
    }
}

