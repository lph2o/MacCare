import AppKit
import Foundation
import Observation

/// Coordinateur central `@Observable` orchestrant la navigation, la télémétrie Mach/APFS, le diagnostic Smart Care, le moteur de sécurité et la base SQLite.
@Observable
@MainActor
public final class NavigationCoordinator {
    public var selectedModule: AppModule = .smartCare
    public private(set) var systemSnapshot: SystemSnapshot
    public private(set) var fullDiskAccessStatus: PermissionStatus
    public private(set) var candidates: [ScanCandidate] = []
    public private(set) var recommendations: [SmartCareRecommendation] = []
    public private(set) var recentScanSessions: [ScanSessionRecord] = []
    public private(set) var storageScanReport: StorageScanReport?
    public private(set) var systemJunkReport: SystemJunkScanReport?
    public private(set) var appManagerReport: AppManagerReport?
    public private(set) var duplicateScanReport: DuplicateScanReport?
    public private(set) var runningProcesses: [RunningProcessItem] = []
    public private(set) var telemetryHistory: [TelemetryHistoryPoint] = []
    public private(set) var startupItems: [StartupLaunchItem] = []
    public private(set) var startupBackups: [StartupBackupRecord] = []
    public private(set) var maintenanceResults: [String: MaintenanceExecutionResult] = [:]
    public private(set) var securityPostureReport: SecurityPostureReport?
    public private(set) var isAnalyzingStorage: Bool = false
    public private(set) var isAnalyzingApps: Bool = false
    public private(set) var isDetectingDuplicates: Bool = false
    public private(set) var isRunningMaintenance: Bool = false
    public private(set) var healthScore: Int = 95
    public private(set) var lastDiagnosticDurationMs: Double = 0.0
    public private(set) var exclusionRules: [ExclusionRule] = []
    public private(set) var recentAuditLogs: [AuditLogEntry] = []
    public private(set) var cumulativeBytesFreed: Int64 = 0
    public private(set) var isScanning: Bool = false
    public var showMenuBarExtra: Bool = true
    public var statusBannerMessage: String?
    public var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "maccare.selected_language")
        }
    }

    public var stagingQueue: StagingQueue
    public let permissionsManager: PermissionsManager
    public let snapshotService: SystemSnapshotService
    public let diagnosticService: SmartCareDiagnosticService
    public let systemJunkScanner: SystemJunkScanner
    public let appBundleAnalyzer: AppBundleAnalyzer
    public let duplicateDetector: DuplicateDetector
    public let processMonitorService: ProcessMonitorService
    public let startupItemsService: StartupItemsService
    public let maintenanceRunnerService: MaintenanceRunnerService
    public let securityPostureService: SecurityPostureService
    public let scanEngine: ScanEngine
    public let database: DatabaseManager
    private var activeStorageScanTask: Task<Void, Never>?

    public init(database: DatabaseManager? = nil) {
        let snapshotService = SystemSnapshotService()
        let permissionsManager = PermissionsManager()
        self.snapshotService = snapshotService
        self.permissionsManager = permissionsManager
        self.diagnosticService = SmartCareDiagnosticService()
        self.systemJunkScanner = SystemJunkScanner()
        self.appBundleAnalyzer = AppBundleAnalyzer()
        self.duplicateDetector = DuplicateDetector()
        self.processMonitorService = ProcessMonitorService()
        self.startupItemsService = StartupItemsService()
        self.maintenanceRunnerService = MaintenanceRunnerService()
        self.securityPostureService = SecurityPostureService()
        self.scanEngine = ScanEngine()
        let initialSnap = snapshotService.captureSnapshot()
        self.systemSnapshot = initialSnap
        self.telemetryHistory = [
            TelemetryHistoryPoint(
                cpuLoadPercentage: initialSnap.cpuLoadPercentage,
                usedMemoryGigabytes: Double(initialSnap.usedMemoryBytes) / 1_073_741_824.0
            )
        ]
        self.fullDiskAccessStatus = permissionsManager.checkFullDiskAccess()
        self.stagingQueue = StagingQueue()
        if let savedCode = UserDefaults.standard.string(forKey: "maccare.selected_language"),
           let savedLang = AppLanguage(rawValue: savedCode) {
            self.language = savedLang
        } else {
            self.language = AppLanguage.detectSystemDefault()
        }

        if let database {
            self.database = database
        } else {
            self.database = (try? DatabaseManager()) ?? (try! DatabaseManager(path: ":memory:"))
        }

        Task { @MainActor in
            await reloadPersistenceState()
        }
    }

    /// Traduit une chaîne selon la langue active du coordinateur.
    public func tr(
        fr: String,
        en: String,
        es: String? = nil,
        de: String? = nil,
        ja: String? = nil,
        zh: String? = nil
    ) -> String {
        L10n.text(language, fr: fr, en: en, es: es, de: de, ja: ja, zh: zh)
    }

    /// Recharge les règles d'exclusion, l'historique d'audit, les sauvegardes d'agents et les sessions de scan depuis SQLite.
    public func reloadPersistenceState() async {
        do {
            self.exclusionRules = try await database.fetchExclusionRules()
            self.recentAuditLogs = try await database.fetchAuditLogs(limit: 50)
            self.recentScanSessions = try await database.fetchRecentScanSessions(limit: 15)
            self.startupBackups = try await database.fetchStartupBackups()
            self.cumulativeBytesFreed = try await database.totalBytesFreed()
        } catch {
            self.statusBannerMessage = "Erreur SQLite : \(error.localizedDescription)"
        }
    }

    /// Rafraîchit les métriques matérielles APFS (`DiskSpaceService`), RAM Mach et CPU (`MachMetricsService`) et empile un point d'historique.
    public func refreshSystemMetrics() {
        let snap = snapshotService.captureSnapshot()
        self.systemSnapshot = snap
        self.fullDiskAccessStatus = permissionsManager.checkFullDiskAccess()

        let point = TelemetryHistoryPoint(
            cpuLoadPercentage: snap.cpuLoadPercentage,
            usedMemoryGigabytes: Double(snap.usedMemoryBytes) / 1_073_741_824.0
        )
        telemetryHistory.append(point)
        if telemetryHistory.count > 30 {
            telemetryHistory.removeFirst(telemetryHistory.count - 30)
        }
    }

    /// Construit une instance à jour du `SafetyEngine` tenant compte des processus actifs et des exclusions.
    public func makeSafetyEngine() -> SafetyEngine {
        let runningIDs = Set(
            NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier?.lowercased() }
        )
        return SafetyEngine(
            userExclusions: exclusionRules,
            runningBundleIdentifiers: runningIDs
        )
    }

    /// Effectue un diagnostic coordonné Smart Care non destructif, calcule l'indice de santé et persiste la session dans SQLite.
    public func performQuickInspection() async {
        isScanning = true
        defer { isScanning = false }

        refreshSystemMetrics()
        let engine = makeSafetyEngine()

        do {
            let report = try await diagnosticService.runDiagnostic(
                safetyEngine: engine,
                snapshot: systemSnapshot
            )
            self.candidates = report.candidates
            self.recommendations = report.recommendations
            self.healthScore = report.healthScore
            self.lastDiagnosticDurationMs = report.session.durationMilliseconds

            try? await database.insertScanSession(report.session)
            self.recentScanSessions = (try? await database.fetchRecentScanSessions(limit: 15)) ?? []
        } catch is CancellationError {
            statusBannerMessage = "Diagnostic annulé."
        } catch {
            statusBannerMessage = "Erreur lors du diagnostic : \(error.localizedDescription)"
        }
    }

    /// Prépare automatiquement tous les éléments qualifiés `.safe` dans le panier de préparation (`StagingQueue`).
    public func stageAllSafeCandidates() {
        for candidate in candidates where candidate.safetyLevel == .safe {
            var copy = candidate
            copy.isSelected = true
            stagingQueue.addOrUpdate(copy)
        }
    }

    /// Lance une analyse arborescente asynchrone (`ScanEngine`) sur le dossier choisi, avec support d'annulation immédiate.
    public func runStorageAnalysis(at directoryURL: URL, largeFileThresholdBytes: Int64 = 1_048_576) {
        activeStorageScanTask?.cancel()
        isAnalyzingStorage = true
        let engine = makeSafetyEngine()
        let scanner = scanEngine
        let db = database

        activeStorageScanTask = Task {
            let started = Date()
            defer { isAnalyzingStorage = false }
            do {
                let report = try await scanner.analyzeDirectory(
                    at: directoryURL,
                    safetyEngine: engine,
                    largeFileThresholdBytes: largeFileThresholdBytes
                )
                guard !Task.isCancelled else { return }
                self.storageScanReport = report

                let session = ScanSessionRecord(
                    startedAt: started,
                    completedAt: Date(),
                    module: AppModule.storageAnalyzer.title,
                    candidatesCount: report.largeFiles.count,
                    reclaimableBytes: report.largeFiles.filter { $0.safetyLevel != .protected }.reduce(0) { $0 + $1.allocatedBytes }
                )
                try? await db.insertScanSession(session)
                self.recentScanSessions = (try? await db.fetchRecentScanSessions(limit: 15)) ?? []
            } catch is CancellationError {
                self.statusBannerMessage = "Analyse du stockage annulée."
            } catch {
                self.statusBannerMessage = "Erreur Storage Analyzer : \(error.localizedDescription)"
            }
        }
    }

    /// Annule immédiatement l'analyse de stockage en cours.
    public func cancelStorageAnalysis() {
        activeStorageScanTask?.cancel()
        activeStorageScanTask = nil
        isAnalyzingStorage = false
    }

    /// Ajoute une règle d'exclusion dans SQLite et met à jour les candidats.
    public func addExclusionRule(pathOrPattern: String, ruleType: ExclusionRule.RuleType, note: String) async {
        let trimmed = pathOrPattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let rule = ExclusionRule(pathOrPattern: trimmed, ruleType: ruleType, note: note)
        do {
            try await database.upsertExclusionRule(rule)
            await reloadPersistenceState()
            await performQuickInspection()
        } catch {
            statusBannerMessage = error.localizedDescription
        }
    }

    /// Supprime une règle d'exclusion de SQLite.
    public func deleteExclusionRule(id: UUID) async {
        do {
            try await database.removeExclusionRule(id: id)
            await reloadPersistenceState()
            await performQuickInspection()
        } catch {
            statusBannerMessage = error.localizedDescription
        }
    }

    /// Exécute le plan de staging courant avec validation `SafetyEngine` et journalisation SQLite.
    public func executeStagedPlan() async {
        let engine = makeSafetyEngine()
        do {
            let report = try await stagingQueue.executeCurrentPlan(
                moduleName: selectedModule.title,
                safetyEngine: engine,
                database: database
            )
            statusBannerMessage = "Opération terminée : \(report.succeededCount) élément(s) déplacé(s) vers la Corbeille (\(MacCareFormatters.formatBytes(report.totalBytesFreed)))."
            await reloadPersistenceState()
            await performQuickInspection()
        } catch {
            statusBannerMessage = error.localizedDescription
        }
    }

    /// Exécute un scan dédié pour le module **02 — System Junk** via `SystemJunkScanner`.
    public func performSystemJunkScan() async {
        isScanning = true
        defer { isScanning = false }

        let engine = makeSafetyEngine()
        do {
            let report = try await systemJunkScanner.scan(safetyEngine: engine)
            self.systemJunkReport = report
            self.candidates = report.candidates
        } catch {
            statusBannerMessage = "Erreur System Junk : \(error.localizedDescription)"
        }
    }

    /// Restaure un élément depuis la Corbeille vers son chemin d'origine à partir d'une entrée du journal d'audit SQLite.
    public func restoreAuditEntry(_ entry: AuditLogEntry) async {
        do {
            _ = try await stagingQueue.restoreFromTrash(logEntry: entry, database: database)
            statusBannerMessage = "Élément restauré à son emplacement d'origine : \(entry.originalPath)"
            await reloadPersistenceState()
            await performQuickInspection()
        } catch {
            statusBannerMessage = error.localizedDescription
        }
    }

    /// Analyse les applications installées (`/Applications`, `~/Applications`) et détecte les restes orphelins (`~/Library`).
    public func performAppManagerAnalysis() async {
        isAnalyzingApps = true
        defer { isAnalyzingApps = false }

        let engine = makeSafetyEngine()
        do {
            let report = try await appBundleAnalyzer.analyzeApplications(safetyEngine: engine)
            self.appManagerReport = report
        } catch {
            statusBannerMessage = "Erreur App Manager : \(error.localizedDescription)"
        }
    }

    /// Ajoute une application et tous ses fichiers associés de `~/Library` au panier de préparation (`StagingQueue`).
    public func stageAppForUninstall(_ app: AnalyzedAppBundle) {
        let items = appBundleAnalyzer.buildUninstallCandidates(for: app)
        for item in items {
            stagingQueue.addOrUpdate(item)
        }
    }

    /// Exécute le pipeline de détection de doublons en 3 passes (`DuplicateDetector`) sur le dossier choisi.
    public func performDuplicateScan(in directoryURL: URL, autoSelectRedundant: Bool = false) async {
        isDetectingDuplicates = true
        defer { isDetectingDuplicates = false }

        let engine = makeSafetyEngine()
        do {
            let report = try await duplicateDetector.detectDuplicates(
                in: directoryURL,
                safetyEngine: engine,
                autoSelectRedundantCopies: autoSelectRedundant
            )
            self.duplicateScanReport = report
        } catch {
            statusBannerMessage = "Erreur Duplicate Finder : \(error.localizedDescription)"
        }
    }

    /// Bascule la sélection d'une copie dans un groupe de doublons en garantissant qu'au moins un original reste conservé.
    public func toggleDuplicateSelection(groupId: UUID, memberId: UUID) {
        guard let report = duplicateScanReport,
              let gIdx = report.groups.firstIndex(where: { $0.id == groupId }) else { return }

        var group = report.groups[gIdx]
        do {
            try group.toggleMemberSelection(memberId: memberId)
            var updatedGroups = report.groups
            updatedGroups[gIdx] = group
            self.duplicateScanReport = DuplicateScanReport(
                groups: updatedGroups,
                totalFilesInspected: report.totalFilesInspected,
                pass1SizeCandidatesCount: report.pass1SizeCandidatesCount,
                pass2PartialHashCandidatesCount: report.pass2PartialHashCandidatesCount,
                pass3ConfirmedDuplicatesCount: report.pass3ConfirmedDuplicatesCount,
                totalReclaimableBytes: report.totalReclaimableBytes,
                durationMilliseconds: report.durationMilliseconds
            )
        } catch {
            statusBannerMessage = error.localizedDescription
        }
    }

    /// Envoie toutes les copies cochées des groupes de doublons vers `StagingQueue` après vérification du verrou d'original.
    public func stageSelectedDuplicates() {
        guard let report = duplicateScanReport else { return }
        for group in report.groups {
            do {
                try group.validateKeeperInvariant()
                for member in group.members where member.isSelectedForRemoval && !member.isLockedOriginal {
                    let candidate = ScanCandidate(
                        path: member.path,
                        displayName: member.name,
                        category: .duplicateFiles,
                        sizeBytes: member.sizeBytes,
                        lastModified: member.lastModified,
                        safetyLevel: .conditional,
                        explanation: "Doublon SHA-256 confirmé (\(group.sha256Hex.prefix(12))). Un exemplaire original est conservé.",
                        potentialImpact: "Déplacement réversible de la copie redondante vers la Corbeille.",
                        isSelected: true
                    )
                    stagingQueue.addOrUpdate(candidate)
                }
            } catch {
                statusBannerMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Modules 06, 07, 08, 09 (Mission 07)

    /// Actualise la liste des processus actifs (`ProcessMonitorService`) et les compteurs Mach sans bloquer le thread principal.
    public func refreshPerformanceMonitor() {
        refreshSystemMetrics()
        let service = processMonitorService
        Task.detached(priority: .userInitiated) {
            let procs = service.listRunningProcesses()
            await MainActor.run {
                self.runningProcesses = procs
            }
        }
    }

    /// Demande la fermeture coopérative d'une application utilisateur non système.
    public func terminateRunningProcess(_ item: RunningProcessItem) {
        guard !item.isSystemOrProtected else {
            statusBannerMessage = "Le processus '\(item.name)' est protégé par macOS."
            return
        }
        let ok = processMonitorService.terminateUserApplication(pid: item.pid)
        statusBannerMessage = ok
            ? "Demande de fermeture envoyée à \(item.name) (PID \(item.pid))."
            : "Impossible de fermer \(item.name)."
        refreshPerformanceMonitor()
    }

    /// Actualise l'inventaire des `LaunchAgents` / `LaunchDaemons` et les sauvegardes SQLite hors du thread principal.
    public func refreshStartupItems() async {
        let service = startupItemsService
        let items = await Task.detached(priority: .userInitiated) {
            service.discoverStartupItems()
        }.value
        startupItems = items
        startupBackups = (try? await database.fetchStartupBackups()) ?? []
    }

    /// Désactive de manière réversible un `LaunchAgent` utilisateur avec sauvegarde dans SQLite.
    public func disableStartupItem(_ item: StartupLaunchItem) async {
        do {
            let record = try await startupItemsService.disableUserLaunchAgent(item, database: database)
            statusBannerMessage = "LaunchAgent '\(record.label)' désactivé et sauvegardé dans SQLite."
            await refreshStartupItems()
            await reloadPersistenceState()
        } catch {
            statusBannerMessage = error.localizedDescription
        }
    }

    /// Réactive un `LaunchAgent` précédemment désactivé depuis la sauvegarde SQLite.
    public func restoreStartupBackup(_ backup: StartupBackupRecord) async {
        do {
            try await startupItemsService.restoreUserLaunchAgent(backup, database: database)
            statusBannerMessage = "LaunchAgent '\(backup.label)' restauré à son emplacement d'origine."
            await refreshStartupItems()
            await reloadPersistenceState()
        } catch {
            statusBannerMessage = error.localizedDescription
        }
    }

    /// Exécute une tâche de maintenance macOS documentée et journalise sa sortie dans SQLite.
    public func executeMaintenanceOperation(_ spec: MaintenanceOperationSpec) async {
        isRunningMaintenance = true
        defer { isRunningMaintenance = false }

        let result = await maintenanceRunnerService.runOperation(spec, database: database)
        maintenanceResults[spec.id] = result
        statusBannerMessage = result.succeeded
            ? "Tâche « \(spec.title) » exécutée en \(String(format: "%.0f ms", result.durationMilliseconds))."
            : "Erreur lors de « \(spec.title) » (code \(result.exitCode))."
        await reloadPersistenceState()
    }

    /// Exécute l'audit défensif de posture de sécurité macOS (`SecurityPostureService`) hors du thread principal (`SecStaticCodeCheckValidity`).
    public func refreshSecurityPosture() {
        let startupService = startupItemsService
        let securityService = securityPostureService
        let currentItems = startupItems

        Task.detached(priority: .userInitiated) {
            let items = currentItems.isEmpty ? startupService.discoverStartupItems() : currentItems
            let report = securityService.evaluatePosture(startupItems: items)
            await MainActor.run {
                if self.startupItems.isEmpty {
                    self.startupItems = items
                }
                self.securityPostureReport = report
            }
        }
    }
}
