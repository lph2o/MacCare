import Foundation

/// Portée d'exécution d'un élément de démarrage macOS.
public enum StartupItemScope: String, Codable, Sendable, Equatable {
    case userLaunchAgent = "LaunchAgent Utilisateur"
    case systemLaunchAgent = "LaunchAgent Système"
    case systemLaunchDaemon = "LaunchDaemon Système"
}

/// Élément de démarrage (`LaunchAgent` / `LaunchDaemon`) inspecté par `StartupItemsService`.
public struct StartupLaunchItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let label: String
    public let plistPath: String
    public let scope: StartupItemScope
    public let executablePath: String?
    public let runAtLoad: Bool
    public let keepAlive: Bool
    public let isBrokenExecutable: Bool
    public let isAppleProtected: Bool
    public let safetyLevel: SafetyLevel
    public let statusExplanation: String

    public init(
        id: UUID = UUID(),
        label: String,
        plistPath: String,
        scope: StartupItemScope,
        executablePath: String?,
        runAtLoad: Bool,
        keepAlive: Bool,
        isBrokenExecutable: Bool,
        isAppleProtected: Bool,
        safetyLevel: SafetyLevel,
        statusExplanation: String
    ) {
        self.id = id
        self.label = label
        self.plistPath = plistPath
        self.scope = scope
        self.executablePath = executablePath
        self.runAtLoad = runAtLoad
        self.keepAlive = keepAlive
        self.isBrokenExecutable = isBrokenExecutable
        self.isAppleProtected = isAppleProtected
        self.safetyLevel = safetyLevel
        self.statusExplanation = statusExplanation
    }
}

/// Enregistrement de sauvegarde d'un `LaunchAgent` désactivé de manière réversible (table SQLite `startup_backups`).
public struct StartupBackupRecord: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let label: String
    public let originalPath: String
    public let backupPath: String
    public let disabledAt: Date

    public init(
        id: UUID = UUID(),
        label: String,
        originalPath: String,
        backupPath: String,
        disabledAt: Date = Date()
    ) {
        self.id = id
        self.label = label
        self.originalPath = originalPath
        self.backupPath = backupPath
        self.disabledAt = disabledAt
    }
}

/// Erreurs liées à la gestion réversible des `LaunchAgents`.
public enum StartupManagerError: Error, LocalizedError, Sendable, Equatable {
    case itemIsProtected(label: String)
    case plistNotFound(path: String)
    case backupFileNotFound(path: String)

    public var errorDescription: String? {
        switch self {
        case .itemIsProtected(let label):
            return "L'agent '\(label)' est protégé et ne peut pas être désactivé."
        case .plistNotFound(let path):
            return "Fichier plist introuvable : '\(path)'."
        case .backupFileNotFound(let path):
            return "Sauvegarde plist introuvable : '\(path)'."
        }
    }
}

/// Service d'inspection et de gestion réversible des `LaunchAgents` et `LaunchDaemons`.
/// Détecte les plists endommagés/orphelins (dont l'exécutable cible n'existe plus) et sauvegarde chaque désactivation dans SQLite.
public struct StartupItemsService: Sendable {
    public init() {}

    /// Analyse les répertoires de démarrage fournis (ou les répertoires macOS standards par défaut).
    public func discoverStartupItems(
        directories: [(url: URL, scope: StartupItemScope)]? = nil
    ) -> [StartupLaunchItem] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        let activeDirs: [(url: URL, scope: StartupItemScope)] = directories ?? [
            (home.appendingPathComponent("Library/LaunchAgents"), .userLaunchAgent),
            (URL(fileURLWithPath: "/Library/LaunchAgents"), .systemLaunchAgent),
            (URL(fileURLWithPath: "/Library/LaunchDaemons"), .systemLaunchDaemon)
        ]

        var items: [StartupLaunchItem] = []

        for entry in activeDirs {
            guard let files = try? fm.contentsOfDirectory(
                at: entry.url,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for fileURL in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            where fileURL.pathExtension.lowercased() == "plist" {
                if let parsed = Self.inspectPlist(at: fileURL, scope: entry.scope) {
                    items.append(parsed)
                }
            }
        }
        return items
    }

    /// Inspecte un fichier `.plist` de `LaunchAgent` / `LaunchDaemon`, extrait son `Label` et vérifie l'existence de son exécutable cible.
    public static func inspectPlist(at plistURL: URL, scope: StartupItemScope) -> StartupLaunchItem? {
        let dict = NSDictionary(contentsOf: plistURL) as? [String: Any]
        let fallbackLabel = plistURL.deletingPathExtension().lastPathComponent
        let label = (dict?["Label"] as? String) ?? fallbackLabel
        let runAtLoad = (dict?["RunAtLoad"] as? Bool) ?? false
        let keepAlive = (dict?["KeepAlive"] as? Bool) ?? (dict?["KeepAlive"] != nil)

        var executablePath: String?
        if let prog = dict?["Program"] as? String, !prog.isEmpty {
            executablePath = prog
        } else if let args = dict?["ProgramArguments"] as? [String], let first = args.first, !first.isEmpty {
            executablePath = first
        }

        let isBroken: Bool
        if let exec = executablePath {
            let expanded = (exec as NSString).expandingTildeInPath
            // Considère un chemin absolu comme brisé si le binaire cible n'existe plus sur le disque
            if expanded.hasPrefix("/") {
                isBroken = !FileManager.default.fileExists(atPath: expanded)
            } else {
                isBroken = false
            }
        } else {
            isBroken = true
        }

        let isApple = label.lowercased().hasPrefix("com.apple.") || plistURL.path.hasPrefix("/System/")
        let isSystemScope = (scope != .userLaunchAgent)

        let safetyLevel: SafetyLevel
        let explanation: String

        if isApple || isSystemScope {
            safetyLevel = .protected
            explanation = isBroken
                ? "Service système global dont la cible est absente (lecture seule dans l'espace utilisateur)."
                : "Service global ou composant Apple protégé."
        } else if isBroken {
            safetyLevel = .conditional
            explanation = "Agent orphelin : l'exécutable cible '\(executablePath ?? "inconnu")' est introuvable sur le disque."
        } else {
            safetyLevel = .conditional
            explanation = "LaunchAgent utilisateur actif. Peut être désactivé de manière réversible avec sauvegarde SQLite."
        }

        return StartupLaunchItem(
            label: label,
            plistPath: plistURL.path,
            scope: scope,
            executablePath: executablePath,
            runAtLoad: runAtLoad,
            keepAlive: keepAlive,
            isBrokenExecutable: isBroken,
            isAppleProtected: isApple,
            safetyLevel: safetyLevel,
            statusExplanation: explanation
        )
    }

    /// Désactive de manière réversible un `LaunchAgent` utilisateur en déplaçant son `.plist` dans un répertoire de sauvegarde
    /// et en enregistrant l'opération dans `DatabaseManager` (`startup_backups` + `action_logs`).
    public func disableUserLaunchAgent(
        _ item: StartupLaunchItem,
        backupDirectory: URL? = nil,
        database: DatabaseManager
    ) async throws -> StartupBackupRecord {
        guard item.safetyLevel != .protected && item.scope == .userLaunchAgent else {
            throw StartupManagerError.itemIsProtected(label: item.label)
        }

        let fm = FileManager.default
        guard fm.fileExists(atPath: item.plistPath) else {
            throw StartupManagerError.plistNotFound(path: item.plistPath)
        }

        let targetBackupDir: URL
        if let backupDirectory {
            targetBackupDir = backupDirectory
        } else {
            let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            targetBackupDir = appSupport.appendingPathComponent("MacCare/DisabledLaunchAgents", isDirectory: true)
        }

        try fm.createDirectory(at: targetBackupDir, withIntermediateDirectories: true)
        let sourceURL = URL(fileURLWithPath: item.plistPath)
        let backupURL = targetBackupDir.appendingPathComponent("\(UUID().uuidString)-\(sourceURL.lastPathComponent)")

        try fm.moveItem(at: sourceURL, to: backupURL)

        let record = StartupBackupRecord(
            label: item.label,
            originalPath: item.plistPath,
            backupPath: backupURL.path
        )
        try await database.insertStartupBackup(record)

        let audit = AuditLogEntry(
            module: AppModule.startupManager.title,
            actionMode: .quarantineFolder,
            originalPath: item.plistPath,
            destinationPath: backupURL.path,
            bytesFreed: 0,
            status: "DISABLED_STARTUP_AGENT"
        )
        try await database.insertAuditLog(audit)

        return record
    }

    /// Réactive un `LaunchAgent` précédemment désactivé en restaurant son fichier `.plist` à son emplacement d'origine.
    public func restoreUserLaunchAgent(
        _ backup: StartupBackupRecord,
        database: DatabaseManager
    ) async throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: backup.backupPath) else {
            throw StartupManagerError.backupFileNotFound(path: backup.backupPath)
        }

        let backupURL = URL(fileURLWithPath: backup.backupPath)
        let originalURL = URL(fileURLWithPath: backup.originalPath)
        try fm.createDirectory(at: originalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.moveItem(at: backupURL, to: originalURL)

        try await database.removeStartupBackup(id: backup.id)

        let audit = AuditLogEntry(
            module: AppModule.startupManager.title,
            actionMode: .restoreFromTrash,
            originalPath: backup.originalPath,
            destinationPath: backup.backupPath,
            bytesFreed: 0,
            status: "RESTORED_STARTUP_AGENT"
        )
        try await database.insertAuditLog(audit)
    }
}

