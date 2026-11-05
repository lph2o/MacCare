import Foundation

/// Cible d'analyse configurée pour `SystemJunkScanner`.
public struct SystemJunkTarget: Sendable {
    public let path: String
    public let category: ScanCategory

    public init(path: String, category: ScanCategory) {
        self.path = path
        self.category = category
    }
}

/// Rapport détaillé produit par `SystemJunkScanner`.
public struct SystemJunkScanReport: Sendable, Equatable {
    public let candidates: [ScanCandidate]
    public let summary: AnalysisSummary
    public let protectedRunningAppCount: Int
    public let durationMilliseconds: Double

    public init(
        candidates: [ScanCandidate],
        summary: AnalysisSummary,
        protectedRunningAppCount: Int,
        durationMilliseconds: Double
    ) {
        self.candidates = candidates
        self.summary = summary
        self.protectedRunningAppCount = protectedRunningAppCount
        self.durationMilliseconds = durationMilliseconds
    }
}

/// Scanner asynchrone dédié au module **02 — System Junk**.
/// Couvre les 5 familles : Caches utilisateur (`.safe`), Journaux (`.safe`), Fichiers temporaires (`.safe`),
/// Artefacts Xcode & Gestionnaires de paquets (`.conditional`) et Corbeille (`.conditional`).
public struct SystemJunkScanner: Sendable {
    private let diskService = DiskSpaceService()

    public init() {}

    /// Cibles standards de nettoyage dans l'espace utilisateur macOS.
    public static func defaultTargets() -> [SystemJunkTarget] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            SystemJunkTarget(path: "\(home)/Library/Caches", category: .userCaches),
            SystemJunkTarget(path: "\(home)/Library/Logs", category: .systemAndUserLogs),
            SystemJunkTarget(path: "\(home)/Library/Developer/Xcode/DerivedData", category: .xcodeDeveloperArtifacts),
            SystemJunkTarget(path: "\(home)/Library/Developer/CoreSimulator/Caches", category: .xcodeDeveloperArtifacts),
            SystemJunkTarget(path: "\(home)/.npm/_cacache", category: .packageManagerCaches),
            SystemJunkTarget(path: "\(home)/.Trash", category: .trashItems)
        ]
    }

    /// Exécute l'analyse complète des cibles System Junk hors du thread principal (`Task.detached`) en qualifiant chaque élément via `SafetyEngine`.
    /// Les éléments `.safe` sont pré-sélectionnables ; les éléments `.conditional` et `.protected` restent décochés par défaut.
    public func scan(
        targets: [SystemJunkTarget]? = nil,
        safetyEngine: SafetyEngine,
        autoSelectSafeItems: Bool = true,
        maxItemsPerTarget: Int = 35
    ) async throws -> SystemJunkScanReport {
        try await Task.detached(priority: .userInitiated) {
            let startTime = CFAbsoluteTimeGetCurrent()
            let activeTargets = targets ?? Self.defaultTargets()
            let fm = FileManager.default

            var candidates: [ScanCandidate] = []
            var protectedRunningCount = 0

            for target in activeTargets {
                try Task.checkCancellation()
                guard let children = try? fm.contentsOfDirectory(atPath: target.path) else { continue }

                for child in children.prefix(maxItemsPerTarget) where !child.hasPrefix(".") {
                    try Task.checkCancellation()
                    let fullPath = "\(target.path)/\(child)"
                    let url = URL(fileURLWithPath: fullPath)
                    let size = diskService.allocatedSize(at: url, maxDirectoryEntries: 80)
                    guard size > 0 else { continue }

                    let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                    let eval = safetyEngine.evaluate(path: fullPath, category: target.category)

                    if eval.level == .protected && eval.reason.contains("en cours d'exécution") {
                        protectedRunningCount += 1
                    }

                    let shouldSelect = autoSelectSafeItems && (eval.level == .safe)
                    let candidate = ScanCandidate(
                        path: fullPath,
                        displayName: child,
                        category: target.category,
                        sizeBytes: size,
                        lastModified: modDate,
                        safetyLevel: eval.level,
                        explanation: eval.reason,
                        potentialImpact: eval.impact,
                        isSelected: shouldSelect
                    )
                    candidates.append(candidate)
                }
            }

            candidates.sort { $0.sizeBytes > $1.sizeBytes }
            let summary = AnalysisSummary(candidates: candidates)
            let elapsedMs = max(0.1, (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)

            return SystemJunkScanReport(
                candidates: candidates,
                summary: summary,
                protectedRunningAppCount: protectedRunningCount,
                durationMilliseconds: elapsedMs
            )
        }.value
    }
}

