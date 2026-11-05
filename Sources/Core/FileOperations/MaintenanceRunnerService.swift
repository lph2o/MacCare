import Foundation

/// Définition d'une opération de maintenance macOS documentée et transparente.
public struct MaintenanceOperationSpec: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let executablePath: String
    public let arguments: [String]
    public let explanation: String
    public let impactDescription: String
    public let safetyLevel: SafetyLevel

    public init(
        id: String,
        title: String,
        executablePath: String,
        arguments: [String],
        explanation: String,
        impactDescription: String,
        safetyLevel: SafetyLevel
    ) {
        self.id = id
        self.title = title
        self.executablePath = executablePath
        self.arguments = arguments
        self.explanation = explanation
        self.impactDescription = impactDescription
        self.safetyLevel = safetyLevel
    }

    /// Ligne de commande exacte affichée à l'utilisateur avant toute exécution.
    public var commandLinePreview: String {
        ([executablePath] + arguments).joined(separator: " ")
    }
}

/// Résultat d'exécution d'une tâche de maintenance macOS.
public struct MaintenanceExecutionResult: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let operationId: String
    public let commandLine: String
    public let exitCode: Int32
    public let outputText: String
    public let durationMilliseconds: Double
    public let executedAt: Date

    public var succeeded: Bool {
        exitCode == 0
    }

    public init(
        id: UUID = UUID(),
        operationId: String,
        commandLine: String,
        exitCode: Int32,
        outputText: String,
        durationMilliseconds: Double,
        executedAt: Date = Date()
    ) {
        self.id = id
        self.operationId = operationId
        self.commandLine = commandLine
        self.exitCode = exitCode
        self.outputText = outputText
        self.durationMilliseconds = durationMilliseconds
        self.executedAt = executedAt
    }
}

/// Service d'exécution transparente et journalisée des opérations de maintenance macOS.
/// Toutes les opérations affichent la ligne de commande exacte avant exécution et journalisent leur sortie dans SQLite.
public struct MaintenanceRunnerService: Sendable {
    public typealias CommandExecutor = @Sendable (_ executable: String, _ arguments: [String]) throws -> (exitCode: Int32, output: String)

    private let executor: CommandExecutor

    public init(executor: CommandExecutor? = nil) {
        self.executor = executor ?? Self.defaultProcessExecutor
    }

    /// Catalogue officiel des opérations de maintenance macOS de MacCare.
    public static let catalog: [MaintenanceOperationSpec] = [
        MaintenanceOperationSpec(
            id: "quicklook_cache_reset",
            title: "Réinitialiser le cache de miniatures Quick Look",
            executablePath: "/usr/bin/qlmanage",
            arguments: ["-r", "cache"],
            explanation: "Purge le serveur de miniatures Quick Look lorsque des aperçus d'icônes sont figés ou obsolètes.",
            impactDescription: "Aucun fichier utilisateur affecté ; les miniatures sont régénérées à la volée.",
            safetyLevel: .safe
        ),
        MaintenanceOperationSpec(
            id: "dns_cache_flush",
            title: "Vider le cache de résolution DNS utilisateur",
            executablePath: "/usr/bin/dscacheutil",
            arguments: ["-flushcache"],
            explanation: "Vide le cache d'annuaire et de résolution DNS locale en cas d'adresse IP obsolète.",
            impactDescription: "Aucune coupure réseau active.",
            safetyLevel: .safe
        ),
        MaintenanceOperationSpec(
            id: "spotlight_status_check",
            title: "Vérifier l'état de l'indexation Spotlight du volume principal",
            executablePath: "/usr/bin/mdutil",
            arguments: ["-s", "/"],
            explanation: "Interroge en lecture seule l'état d'activation de l'indexation Spotlight sur Macintosh HD.",
            impactDescription: "Opération purement informative (lecture seule).",
            safetyLevel: .safe
        ),
        MaintenanceOperationSpec(
            id: "timemachine_local_snapshots",
            title: "Inventorier les instantanés locaux Time Machine (APFS)",
            executablePath: "/usr/bin/tmutil",
            arguments: ["listlocalsnapshots", "/"],
            explanation: "Liste les snapshots APFS locaux créés par Time Machine qui occupent de l'espace purgeable.",
            impactDescription: "Opération en lecture seule.",
            safetyLevel: .conditional
        ),
        MaintenanceOperationSpec(
            id: "apfs_root_volume_info",
            title: "Inspecter l'état SMART et les métadonnées du conteneur APFS",
            executablePath: "/usr/sbin/diskutil",
            arguments: ["info", "/"],
            explanation: "Affiche les propriétés du volume racine APFS, le chiffrement et le statut matériel.",
            impactDescription: "Opération en lecture seule.",
            safetyLevel: .safe
        )
    ]

    /// Exécute une opération de maintenance documentée et enregistre son résultat dans `DatabaseManager`.
    public func runOperation(
        _ spec: MaintenanceOperationSpec,
        database: DatabaseManager
    ) async -> MaintenanceExecutionResult {
        let start = CFAbsoluteTimeGetCurrent()
        let cmdLine = spec.commandLinePreview

        let code: Int32
        let output: String

        do {
            let res = try executor(spec.executablePath, spec.arguments)
            code = res.exitCode
            output = res.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Commande exécutée avec succès (code 0)."
                : res.output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            code = -1
            output = "Erreur d'exécution : \(error.localizedDescription)"
        }

        let elapsedMs = max(0.1, (CFAbsoluteTimeGetCurrent() - start) * 1000.0)
        let result = MaintenanceExecutionResult(
            operationId: spec.id,
            commandLine: cmdLine,
            exitCode: code,
            outputText: output,
            durationMilliseconds: elapsedMs
        )

        let logEntry = AuditLogEntry(
            module: AppModule.maintenance.title,
            actionMode: .moveToTrash,
            originalPath: cmdLine,
            destinationPath: String(output.prefix(240)),
            bytesFreed: 0,
            status: code == 0 ? "MAINTENANCE_OK" : "MAINTENANCE_ERROR",
            errorMessage: code == 0 ? nil : output
        )
        try? await database.insertAuditLog(logEntry)

        return result
    }

    @Sendable
    private static func defaultProcessExecutor(executable: String, arguments: [String]) throws -> (exitCode: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let text = String(data: data, encoding: .utf8) ?? ""
        return (exitCode: process.terminationStatus, output: text)
    }
}

