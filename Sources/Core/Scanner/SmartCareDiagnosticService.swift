import Foundation

/// Enregistrement d'une session d'analyse persisté dans la table SQLite `scan_sessions`.
public struct ScanSessionRecord: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let completedAt: Date
    public let module: String
    public let candidatesCount: Int
    public let reclaimableBytes: Int64

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        completedAt: Date = Date(),
        module: String,
        candidatesCount: Int,
        reclaimableBytes: Int64
    ) {
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.module = module
        self.candidatesCount = candidatesCount
        self.reclaimableBytes = reclaimableBytes
    }

    public var durationMilliseconds: Double {
        max(0.1, completedAt.timeIntervalSince(startedAt) * 1000.0)
    }
}

/// Recommandation transparente générée par le diagnostic Smart Care.
public struct SmartCareRecommendation: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let title: String
    public let detail: String
    public let safetyLevel: SafetyLevel
    public let reclaimableBytes: Int64
    public let targetModule: AppModule

    public init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        safetyLevel: SafetyLevel,
        reclaimableBytes: Int64,
        targetModule: AppModule
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.safetyLevel = safetyLevel
        self.reclaimableBytes = reclaimableBytes
        self.targetModule = targetModule
    }
}

/// Bilan complet produit par `SmartCareDiagnosticService`.
public struct SmartCareDiagnosticReport: Sendable, Equatable {
    public let session: ScanSessionRecord
    public let healthScore: Int
    public let candidates: [ScanCandidate]
    public let recommendations: [SmartCareRecommendation]
    public let summary: AnalysisSummary
}

/// Cible d'exploration configurable pour le diagnostic Smart Care.
public struct DiagnosticTarget: Sendable {
    public let path: String
    public let category: ScanCategory

    public init(path: String, category: ScanCategory) {
        self.path = path
        self.category = category
    }
}

/// Service de diagnostic coordonné pour le module **01 — Smart Care**.
/// Supporte l'annulation coopérative (`Task.checkCancellation()`), calcule la taille physique APFS allouée,
/// qualifie chaque élément via `SafetyEngine` et produit un score de santé explicable (0 à 100).
public struct SmartCareDiagnosticService: Sendable {
    private let diskService = DiskSpaceService()

    public init() {}

    /// Cibles par défaut dans l'espace utilisateur macOS (sans `~/` protégé par TCC pour éviter toute boîte de dialogue bloquante au démarrage).
    public static func defaultUserTargets() -> [DiagnosticTarget] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            DiagnosticTarget(path: "\(home)/Library/Caches", category: .userCaches),
            DiagnosticTarget(path: "\(home)/Library/Logs", category: .systemAndUserLogs),
            DiagnosticTarget(path: "\(home)/Library/Developer/Xcode/DerivedData", category: .xcodeDeveloperArtifacts)
        ]
    }

    /// Exécute un diagnostic rapide et non destructif sur les cibles spécifiées hors du thread principal (`@concurrent` / `Task.detached`).
    public func runDiagnostic(
        targets: [DiagnosticTarget]? = nil,
        safetyEngine: SafetyEngine,
        snapshot: SystemSnapshot,
        maxItemsPerTarget: Int = 20
    ) async throws -> SmartCareDiagnosticReport {
        try await Task.detached(priority: .userInitiated) {
            let startedAt = Date()
            let activeTargets = targets ?? Self.defaultUserTargets()
            let fm = FileManager.default

            var discovered: [ScanCandidate] = []

            for target in activeTargets {
                try Task.checkCancellation()
                guard let children = try? fm.contentsOfDirectory(atPath: target.path) else { continue }

                for child in children.prefix(maxItemsPerTarget) where !child.hasPrefix(".") {
                    try Task.checkCancellation()
                    let fullPath = "\(target.path)/\(child)"
                    let url = URL(fileURLWithPath: fullPath)
                    let size = diskService.allocatedSize(at: url, maxDirectoryEntries: 60)
                    guard size > 0 else { continue }

                    let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                    let evaluation = safetyEngine.evaluate(path: fullPath, category: target.category)

                    let candidate = ScanCandidate(
                        path: fullPath,
                        displayName: child,
                        category: target.category,
                        sizeBytes: size,
                        lastModified: modDate,
                        safetyLevel: evaluation.level,
                        explanation: evaluation.reason,
                        potentialImpact: evaluation.impact,
                        isSelected: false
                    )
                    discovered.append(candidate)
                }
            }

            discovered.sort { $0.sizeBytes > $1.sizeBytes }
            let summary = AnalysisSummary(candidates: discovered)
            let score = Self.computeHealthScore(snapshot: snapshot, summary: summary)
            let recommendations = Self.buildRecommendations(snapshot: snapshot, summary: summary)

            let session = ScanSessionRecord(
                startedAt: startedAt,
                completedAt: Date(),
                module: AppModule.smartCare.title,
                candidatesCount: discovered.count,
                reclaimableBytes: summary.totalReclaimableBytes
            )

            return SmartCareDiagnosticReport(
                session: session,
                healthScore: score,
                candidates: discovered,
                recommendations: recommendations,
                summary: summary
            )
        }.value
    }

    /// Calcule un indice de santé transparent sur 100 à partir de l'espace libre APFS, de la pression RAM et du volume de caches.
    public static func computeHealthScore(snapshot: SystemSnapshot, summary: AnalysisSummary) -> Int {
        var score = 100

        // Pénalité si le disque dépasse 80 % ou 90 % d'occupation
        if snapshot.diskUsageRatio > 0.90 {
            score -= 25
        } else if snapshot.diskUsageRatio > 0.80 {
            score -= 12
        }

        // Pénalité selon la pression mémoire Mach
        switch snapshot.memoryPressure {
        case .normal:
            break
        case .warning:
            score -= 10
        case .critical:
            score -= 22
        }

        // Pénalité progressive selon le volume de caches récupérables (> 500 Mo ou > 2 Go)
        let reclaimableMB = Double(summary.totalReclaimableBytes) / 1_048_576.0
        if reclaimableMB > 2_048 {
            score -= 15
        } else if reclaimableMB > 256 {
            score -= 7
        } else if reclaimableMB > 10 {
            score -= 3
        }

        return min(100, max(20, score))
    }

    private static func buildRecommendations(
        snapshot: SystemSnapshot,
        summary: AnalysisSummary
    ) -> [SmartCareRecommendation] {
        var list: [SmartCareRecommendation] = []

        if summary.safeBytes > 0 {
            list.append(
                SmartCareRecommendation(
                    title: "Nettoyer les caches et journaux régénérables",
                    detail: "\(MacCareFormatters.formatBytes(summary.safeBytes)) de fichiers temporaires et caches utilisateur peuvent être déplacés vers la Corbeille sans perte de session.",
                    safetyLevel: .safe,
                    reclaimableBytes: summary.safeBytes,
                    targetModule: .systemJunk
                )
            )
        }

        if summary.conditionalBytes > 0 {
            list.append(
                SmartCareRecommendation(
                    title: "Vérifier les artefacts de développement et la Corbeille",
                    detail: "\(MacCareFormatters.formatBytes(summary.conditionalBytes)) d'éléments conditionnels (DerivedData Xcode, Corbeille) sont disponibles pour examen manuel.",
                    safetyLevel: .conditional,
                    reclaimableBytes: summary.conditionalBytes,
                    targetModule: .systemJunk
                )
            )
        }

        if snapshot.purgeableDiskBytes > 100 * 1_048_576 {
            list.append(
                SmartCareRecommendation(
                    title: "Inspecter l'espace purgeable APFS et les snapshots locaux",
                    detail: "macOS gère actuellement \(MacCareFormatters.formatBytes(snapshot.purgeableDiskBytes)) d'espace purgeable APFS.",
                    safetyLevel: .conditional,
                    reclaimableBytes: snapshot.purgeableDiskBytes,
                    targetModule: .storageAnalyzer
                )
            )
        }

        if snapshot.memoryPressure != .normal {
            list.append(
                SmartCareRecommendation(
                    title: "Surveiller la pression mémoire Mach (\(snapshot.memoryPressure.rawValue))",
                    detail: "Consultez le module Performance pour identifier les applications consommant le plus de mémoire active.",
                    safetyLevel: .conditional,
                    reclaimableBytes: 0,
                    targetModule: .performance
                )
            )
        }

        return list
    }
}

