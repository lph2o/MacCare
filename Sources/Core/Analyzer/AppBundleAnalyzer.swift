import Darwin
import Foundation

/// Architecture binaire détectée par inspection de l'en-tête Mach-O.
public enum BinaryArchitecture: String, Codable, Sendable, Equatable {
    case universal = "Universel (arm64 + x86_64)"
    case appleSilicon = "Apple Silicon (arm64)"
    case intel64 = "Intel (x86_64)"
    case unknown = "Standard"
}

/// Fichier ou dossier de `~/Library` rattaché à une application installée.
public struct AssociatedAppFile: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let path: String
    public let kindLabel: String
    public let sizeBytes: Int64
    public let safetyLevel: SafetyLevel

    public init(
        id: UUID = UUID(),
        path: String,
        kindLabel: String,
        sizeBytes: Int64,
        safetyLevel: SafetyLevel
    ) {
        self.id = id
        self.path = path
        self.kindLabel = kindLabel
        self.sizeBytes = sizeBytes
        self.safetyLevel = safetyLevel
    }
}

/// Enregistrement complet d'une application analysée par `AppBundleAnalyzer`.
public struct AnalyzedAppBundle: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let bundleIdentifier: String
    public let version: String
    public let bundlePath: String
    public let architecture: BinaryArchitecture
    public let isRunning: Bool
    public let isAppleSystemApp: Bool
    public let appBundleSizeBytes: Int64
    public let associatedFiles: [AssociatedAppFile]
    public let safetyLevel: SafetyLevel
    public let safetyReason: String

    public init(
        id: UUID = UUID(),
        name: String,
        bundleIdentifier: String,
        version: String,
        bundlePath: String,
        architecture: BinaryArchitecture,
        isRunning: Bool,
        isAppleSystemApp: Bool,
        appBundleSizeBytes: Int64,
        associatedFiles: [AssociatedAppFile],
        safetyLevel: SafetyLevel,
        safetyReason: String
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.bundlePath = bundlePath
        self.architecture = architecture
        self.isRunning = isRunning
        self.isAppleSystemApp = isAppleSystemApp
        self.appBundleSizeBytes = appBundleSizeBytes
        self.associatedFiles = associatedFiles
        self.safetyLevel = safetyLevel
        self.safetyReason = safetyReason
    }

    public var associatedSizeBytes: Int64 {
        associatedFiles.reduce(0) { $0 + $1.sizeBytes }
    }

    public var totalFootprintBytes: Int64 {
        appBundleSizeBytes + associatedSizeBytes
    }
}

/// Résidu orphelin identifié dans `~/Library` appartenant à une application qui n'est plus installée.
public struct OrphanedLeftoverItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let path: String
    public let displayName: String
    public let locationKind: String
    public let sizeBytes: Int64
    public let safetyLevel: SafetyLevel
    public let explanation: String

    public init(
        id: UUID = UUID(),
        path: String,
        displayName: String,
        locationKind: String,
        sizeBytes: Int64,
        safetyLevel: SafetyLevel,
        explanation: String
    ) {
        self.id = id
        self.path = path
        self.displayName = displayName
        self.locationKind = locationKind
        self.sizeBytes = sizeBytes
        self.safetyLevel = safetyLevel
        self.explanation = explanation
    }
}

/// Rapport produit par `AppBundleAnalyzer`.
public struct AppManagerReport: Sendable, Equatable {
    public let apps: [AnalyzedAppBundle]
    public let orphanedLeftovers: [OrphanedLeftoverItem]
    public let durationMilliseconds: Double
}

/// Analyseur natif des paquets `.app`, de leurs binaires Mach-O, de leurs fichiers associés dans `~/Library`
/// et des restes orphelins (*Leftovers*).
public struct AppBundleAnalyzer: Sendable {
    private let diskService = DiskSpaceService()

    public init() {}

    /// Analyse les répertoires d'applications et le dossier `Library` utilisateur fourni hors du thread principal (`Task.detached`).
    public func analyzeApplications(
        applicationDirectories: [URL]? = nil,
        userLibraryURL: URL? = nil,
        safetyEngine: SafetyEngine
    ) async throws -> AppManagerReport {
        try await Task.detached(priority: .userInitiated) {
            let startTime = CFAbsoluteTimeGetCurrent()
            let fm = FileManager.default
            let homeURL = fm.homeDirectoryForCurrentUser

            let appDirs = applicationDirectories ?? [
                URL(fileURLWithPath: "/Applications"),
                homeURL.appendingPathComponent("Applications")
            ]
            let libraryURL = userLibraryURL ?? homeURL.appendingPathComponent("Library")

            var analyzedApps: [AnalyzedAppBundle] = []
            var installedBundleIDs: Set<String> = []
            var installedAppNames: Set<String> = []

            for dirURL in appDirs {
                try Task.checkCancellation()
                guard let items = try? fm.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
                    continue
                }

                for appURL in items.prefix(45) where appURL.pathExtension.lowercased() == "app" {
                    try Task.checkCancellation()
                    let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
                    let plistDict = NSDictionary(contentsOf: infoPlistURL) as? [String: Any]

                    let rawName = (plistDict?["CFBundleDisplayName"] as? String)
                        ?? (plistDict?["CFBundleName"] as? String)
                        ?? appURL.deletingPathExtension().lastPathComponent
                    let bundleID = (plistDict?["CFBundleIdentifier"] as? String) ?? "unknown.\(rawName.lowercased())"
                    let version = (plistDict?["CFBundleShortVersionString"] as? String)
                        ?? (plistDict?["CFBundleVersion"] as? String)
                        ?? "1.0"
                    let execName = (plistDict?["CFBundleExecutable"] as? String) ?? appURL.deletingPathExtension().lastPathComponent
                    let execURL = appURL.appendingPathComponent("Contents/MacOS/\(execName)")

                    installedBundleIDs.insert(bundleID.lowercased())
                    installedAppNames.insert(rawName.lowercased())

                    let arch = Self.detectMachOArchitecture(at: execURL)
                    let isAppleApp = appURL.path.hasPrefix("/System/") || bundleID.lowercased().hasPrefix("com.apple.")
                    let isRunning = safetyEngine.runningBundleIdentifiers.contains(bundleID.lowercased())

                    let appSize = diskService.allocatedSize(at: appURL, maxDirectoryEntries: 150)
                    let associated = Self.findAssociatedFiles(
                        bundleID: bundleID,
                        appName: rawName,
                        libraryURL: libraryURL,
                        diskService: diskService,
                        safetyEngine: safetyEngine
                    )

                    let safetyLevel: SafetyLevel
                    let safetyReason: String
                    if isAppleApp {
                        safetyLevel = .protected
                        safetyReason = "Application système Apple protégée par macOS (SIP)."
                    } else if isRunning {
                        safetyLevel = .protected
                        safetyReason = "Application actuellement en cours d'exécution. Quittez-la avant toute désinstallation."
                    } else {
                        let eval = safetyEngine.evaluate(path: appURL.path, category: .applicationBundles)
                        safetyLevel = eval.level
                        safetyReason = eval.reason
                    }

                    analyzedApps.append(
                        AnalyzedAppBundle(
                            name: rawName,
                            bundleIdentifier: bundleID,
                            version: version,
                            bundlePath: appURL.path,
                            architecture: arch,
                            isRunning: isRunning,
                            isAppleSystemApp: isAppleApp,
                            appBundleSizeBytes: appSize,
                            associatedFiles: associated,
                            safetyLevel: safetyLevel,
                            safetyReason: safetyReason
                        )
                    )
                }
            }

            analyzedApps.sort { $0.totalFootprintBytes > $1.totalFootprintBytes }

            let leftovers = Self.findOrphanedLeftovers(
                installedBundleIDs: installedBundleIDs,
                installedAppNames: installedAppNames,
                libraryURL: libraryURL,
                diskService: diskService,
                safetyEngine: safetyEngine
            )

            let elapsedMs = max(0.1, (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)
            return AppManagerReport(
                apps: analyzedApps,
                orphanedLeftovers: leftovers,
                durationMilliseconds: elapsedMs
            )
        }.value
    }

    /// Convertit une application et ses fichiers associés en candidats pour `StagingQueue`,
    /// en refusant toute application `.protected` (Apple ou en cours d'exécution).
    public func buildUninstallCandidates(for app: AnalyzedAppBundle) -> [ScanCandidate] {
        guard app.safetyLevel != .protected else { return [] }

        var list: [ScanCandidate] = [
            ScanCandidate(
                path: app.bundlePath,
                displayName: "\(app.name).app",
                category: .applicationBundles,
                sizeBytes: app.appBundleSizeBytes,
                safetyLevel: app.safetyLevel,
                explanation: "Paquet d'application principal (\(app.bundleIdentifier) v\(app.version)).",
                potentialImpact: "Déplacement réversible de l'application vers la Corbeille.",
                isSelected: true
            )
        ]

        for assoc in app.associatedFiles where assoc.safetyLevel != .protected {
            list.append(
                ScanCandidate(
                    path: assoc.path,
                    displayName: "\(app.name) — \(assoc.kindLabel)",
                    category: .applicationLeftovers,
                    sizeBytes: assoc.sizeBytes,
                    safetyLevel: assoc.safetyLevel,
                    explanation: "Données associées (\(assoc.kindLabel)) de \(app.name).",
                    potentialImpact: "Déplacement réversible vers la Corbeille.",
                    isSelected: true
                )
            )
        }
        return list
    }

    // MARK: - Inspection d'en-tête Mach-O

    public static func detectMachOArchitecture(at executableURL: URL) -> BinaryArchitecture {
        guard let handle = try? FileHandle(forReadingFrom: executableURL) else { return .unknown }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 8), data.count >= 4 else { return .unknown }

        let magic = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        switch magic {
        case 0xCAFEBABE, 0xBEBAFECA, 0xCAFEBABF, 0xBFBAFECA:
            return .universal
        case 0xFEEDFACF, 0xCFFAEDFE:
            if data.count >= 8 {
                let cputype = data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self) }
                // CPU_TYPE_ARM64 = 0x0100000C (16777228)
                if cputype == 0x0100000C || cputype == 0x0C000001 {
                    return .appleSilicon
                }
                return .intel64
            }
            return .intel64
        default:
            return .unknown
        }
    }

    // MARK: - Corrélation des fichiers associés dans ~/Library

    private static func findAssociatedFiles(
        bundleID: String,
        appName: String,
        libraryURL: URL,
        diskService: DiskSpaceService,
        safetyEngine: SafetyEngine
    ) -> [AssociatedAppFile] {
        let probes: [(subdir: String, targetName: String, label: String)] = [
            ("Caches", bundleID, "Caches"),
            ("Application Support", bundleID, "Application Support"),
            ("Application Support", appName, "Application Support"),
            ("Preferences", "\(bundleID).plist", "Préférences"),
            ("Saved Application State", "\(bundleID).savedState", "État de session sauvegardé"),
            ("Containers", bundleID, "Conteneur Sandbox"),
            ("HTTPStorages", bundleID, "Stockage HTTP"),
            ("Logs", bundleID, "Journaux"),
            ("Logs", appName, "Journaux")
        ]

        var found: [AssociatedAppFile] = []
        var seenPaths: Set<String> = []
        let fm = FileManager.default

        for probe in probes {
            let candidateURL = libraryURL
                .appendingPathComponent(probe.subdir, isDirectory: true)
                .appendingPathComponent(probe.targetName)
            let path = candidateURL.path
            guard !seenPaths.contains(path), fm.fileExists(atPath: path) else { continue }
            seenPaths.insert(path)

            let size = diskService.allocatedSize(at: candidateURL, maxDirectoryEntries: 100)
            guard size > 0 else { continue }

            let eval = safetyEngine.evaluate(path: path, category: .applicationLeftovers)
            found.append(
                AssociatedAppFile(
                    path: path,
                    kindLabel: probe.label,
                    sizeBytes: size,
                    safetyLevel: eval.level
                )
            )
        }
        return found
    }

    // MARK: - Détection des restes orphelins (Leftovers)

    private static func findOrphanedLeftovers(
        installedBundleIDs: Set<String>,
        installedAppNames: Set<String>,
        libraryURL: URL,
        diskService: DiskSpaceService,
        safetyEngine: SafetyEngine
    ) -> [OrphanedLeftoverItem] {
        let scannedSubdirs: [(folder: String, label: String)] = [
            ("Caches", "Cache orphelin"),
            ("Saved Application State", "État sauvegardé orphelin"),
            ("Application Support", "Support applicatif orphelin")
        ]

        var leftovers: [OrphanedLeftoverItem] = []
        let fm = FileManager.default

        for sub in scannedSubdirs {
            let dirURL = libraryURL.appendingPathComponent(sub.folder, isDirectory: true)
            guard let entries = try? fm.contentsOfDirectory(atPath: dirURL.path) else { continue }

            for entry in entries.prefix(40) where !entry.hasPrefix(".") {
                let lower = entry.lowercased()
                let normalizedBundleKey = lower.replacingOccurrences(of: ".savedstate", with: "")

                // Ne cible que les identifiants reverse-DNS explicites hors Apple
                let parts = normalizedBundleKey.split(separator: ".")
                guard parts.count >= 3 else { continue }
                guard !normalizedBundleKey.hasPrefix("com.apple.") && !normalizedBundleKey.hasPrefix("org.swift.") else {
                    continue
                }

                // Si aucune application installée ne possède ce bundleID ni ce nom de composant final
                let lastToken = String(parts.last ?? "")
                if installedBundleIDs.contains(normalizedBundleKey) || installedAppNames.contains(lastToken) {
                    continue
                }

                let fullURL = dirURL.appendingPathComponent(entry)
                let size = diskService.allocatedSize(at: fullURL, maxDirectoryEntries: 80)
                guard size > 0 else { continue }

                let eval = safetyEngine.evaluate(path: fullURL.path, category: .applicationLeftovers)
                guard eval.level != .protected else { continue }

                leftovers.append(
                    OrphanedLeftoverItem(
                        path: fullURL.path,
                        displayName: entry,
                        locationKind: sub.label,
                        sizeBytes: size,
                        safetyLevel: .conditional,
                        explanation: "Aucune application installée ne correspond à '\(normalizedBundleKey)'."
                    )
                )
            }
        }

        leftovers.sort { $0.sizeBytes > $1.sizeBytes }
        return leftovers
    }
}

