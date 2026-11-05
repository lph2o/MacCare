import Foundation
import SQLite3

/// Erreurs liées à la couche de persistance SQLite3.
public enum DatabaseError: Error, LocalizedError, Sendable {
    case openFailed(message: String)
    case prepareFailed(message: String)
    case executionFailed(message: String)

    public var errorDescription: String? {
        switch self {
        case .openFailed(let message):
            return "Impossible d'ouvrir la base SQLite : \(message)"
        case .prepareFailed(let message):
            return "Erreur de préparation SQL : \(message)"
        case .executionFailed(let message):
            return "Erreur d'exécution SQL : \(message)"
        }
    }
}

/// Gestionnaire SQLite3 natif thread-safe (`actor`) en mode WAL.
/// Stocke l'historique des analyses, le journal d'audit des actions et les règles d'exclusion.
public actor DatabaseManager {
    private var db: OpaquePointer?
    public let databasePath: String

    private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    /// Initialise la base de données SQLite au chemin spécifié (ou dans Application Support par défaut).
    public init(path: String? = nil) throws {
        if let customPath = path {
            self.databasePath = customPath
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("MacCare", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.databasePath = dir.appendingPathComponent("maccare.sqlite").path
        }

        var pointer: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(self.databasePath, &pointer, flags, nil) != SQLITE_OK {
            let message = pointer.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Erreur inconnue"
            if let pointer { sqlite3_close(pointer) }
            throw DatabaseError.openFailed(message: message)
        }
        self.db = pointer

        try Self.executeRaw(db: pointer, sql: "PRAGMA journal_mode = WAL;")
        try Self.executeRaw(db: pointer, sql: "PRAGMA synchronous = NORMAL;")
        try Self.executeRaw(db: pointer, sql: "PRAGMA foreign_keys = ON;")
        try Self.createSchema(db: pointer)
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    // MARK: - Schema

    private static func createSchema(db: OpaquePointer?) throws {
        let schemaSQL = """
        CREATE TABLE IF NOT EXISTS scan_sessions (
            id TEXT PRIMARY KEY,
            started_at REAL NOT NULL,
            completed_at REAL,
            module TEXT NOT NULL,
            candidates_count INTEGER NOT NULL DEFAULT 0,
            reclaimable_bytes INTEGER NOT NULL DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS action_logs (
            id TEXT PRIMARY KEY,
            executed_at REAL NOT NULL,
            module TEXT NOT NULL,
            action_mode TEXT NOT NULL,
            original_path TEXT NOT NULL,
            destination_path TEXT,
            bytes_freed INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL,
            error_message TEXT
        );

        CREATE TABLE IF NOT EXISTS exclusion_rules (
            id TEXT PRIMARY KEY,
            path_or_pattern TEXT NOT NULL UNIQUE,
            rule_type TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            created_at REAL NOT NULL
        );

        CREATE TABLE IF NOT EXISTS startup_backups (
            id TEXT PRIMARY KEY,
            label TEXT NOT NULL,
            original_path TEXT NOT NULL,
            backup_path TEXT NOT NULL,
            disabled_at REAL NOT NULL
        );
        """
        try executeRaw(db: db, sql: schemaSQL)
    }

    private static func executeRaw(db: OpaquePointer?, sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errorMessage) != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? "Erreur SQL"
            sqlite3_free(errorMessage)
            throw DatabaseError.executionFailed(message: message)
        }
    }

    // MARK: - Exclusion Rules CRUD

    /// Ajoute ou remplace une règle d'exclusion utilisateur.
    public func upsertExclusionRule(_ rule: ExclusionRule) throws {
        let sql = """
        INSERT OR REPLACE INTO exclusion_rules (id, path_or_pattern, rule_type, note, created_at)
        VALUES (?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: lastErrorMessage())
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, rule.id.uuidString, -1, sqliteTransient)
        sqlite3_bind_text(stmt, 2, rule.pathOrPattern, -1, sqliteTransient)
        sqlite3_bind_text(stmt, 3, rule.ruleType.rawValue, -1, sqliteTransient)
        sqlite3_bind_text(stmt, 4, rule.note, -1, sqliteTransient)
        sqlite3_bind_double(stmt, 5, rule.createdAt.timeIntervalSince1970)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.executionFailed(message: lastErrorMessage())
        }
    }

    /// Supprime une règle d'exclusion par son identifiant.
    public func removeExclusionRule(id: UUID) throws {
        let sql = "DELETE FROM exclusion_rules WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: lastErrorMessage())
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, id.uuidString, -1, sqliteTransient)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.executionFailed(message: lastErrorMessage())
        }
    }

    /// Liste toutes les règles d'exclusion triées par date de création décroissante.
    public func fetchExclusionRules() throws -> [ExclusionRule] {
        let sql = "SELECT id, path_or_pattern, rule_type, note, created_at FROM exclusion_rules ORDER BY created_at DESC;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: lastErrorMessage())
        }
        defer { sqlite3_finalize(stmt) }

        var results: [ExclusionRule] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let idStr = String(cString: sqlite3_column_text(stmt, 0))
            let pattern = String(cString: sqlite3_column_text(stmt, 1))
            let typeStr = String(cString: sqlite3_column_text(stmt, 2))
            let note = String(cString: sqlite3_column_text(stmt, 3))
            let timestamp = sqlite3_column_double(stmt, 4)

            let rule = ExclusionRule(
                id: UUID(uuidString: idStr) ?? UUID(),
                pathOrPattern: pattern,
                ruleType: ExclusionRule.RuleType(rawValue: typeStr) ?? .exactPath,
                note: note,
                createdAt: Date(timeIntervalSince1970: timestamp)
            )
            results.append(rule)
        }
        return results
    }

    // MARK: - Action Logs CRUD

    /// Enregistre une entrée dans le journal d'audit des opérations.
    public func insertAuditLog(_ entry: AuditLogEntry) throws {
        let sql = """
        INSERT INTO action_logs (id, executed_at, module, action_mode, original_path, destination_path, bytes_freed, status, error_message)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: lastErrorMessage())
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, entry.id.uuidString, -1, sqliteTransient)
        sqlite3_bind_double(stmt, 2, entry.executedAt.timeIntervalSince1970)
        sqlite3_bind_text(stmt, 3, entry.module, -1, sqliteTransient)
        sqlite3_bind_text(stmt, 4, entry.actionMode.rawValue, -1, sqliteTransient)
        sqlite3_bind_text(stmt, 5, entry.originalPath, -1, sqliteTransient)

        if let dest = entry.destinationPath {
            sqlite3_bind_text(stmt, 6, dest, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(stmt, 6)
        }

        sqlite3_bind_int64(stmt, 7, entry.bytesFreed)
        sqlite3_bind_text(stmt, 8, entry.status, -1, sqliteTransient)

        if let err = entry.errorMessage {
            sqlite3_bind_text(stmt, 9, err, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(stmt, 9)
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.executionFailed(message: lastErrorMessage())
        }
    }

    /// Récupère les entrées récentes du journal d'audit.
    public func fetchAuditLogs(limit: Int = 100) throws -> [AuditLogEntry] {
        let sql = """
        SELECT id, executed_at, module, action_mode, original_path, destination_path, bytes_freed, status, error_message
        FROM action_logs
        ORDER BY executed_at DESC
        LIMIT ?;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: lastErrorMessage())
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int(stmt, 1, Int32(limit))

        var entries: [AuditLogEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let idStr = String(cString: sqlite3_column_text(stmt, 0))
            let executedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1))
            let module = String(cString: sqlite3_column_text(stmt, 2))
            let modeStr = String(cString: sqlite3_column_text(stmt, 3))
            let origPath = String(cString: sqlite3_column_text(stmt, 4))
            let destPath: String? = sqlite3_column_type(stmt, 5) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(stmt, 5))
                : nil
            let bytesFreed = sqlite3_column_int64(stmt, 6)
            let status = String(cString: sqlite3_column_text(stmt, 7))
            let errorMessage: String? = sqlite3_column_type(stmt, 8) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(stmt, 8))
                : nil

            entries.append(
                AuditLogEntry(
                    id: UUID(uuidString: idStr) ?? UUID(),
                    executedAt: executedAt,
                    module: module,
                    actionMode: FileActionMode(rawValue: modeStr) ?? .moveToTrash,
                    originalPath: origPath,
                    destinationPath: destPath,
                    bytesFreed: bytesFreed,
                    status: status,
                    errorMessage: errorMessage
                )
            )
        }
        return entries
    }

    /// Calcule le total cumulé d'octets libérés avec succès.
    public func totalBytesFreed() throws -> Int64 {
        let sql = "SELECT COALESCE(SUM(bytes_freed), 0) FROM action_logs WHERE status = 'SUCCESS';"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: lastErrorMessage())
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            return sqlite3_column_int64(stmt, 0)
        }
        return 0
    }

    // MARK: - Scan Sessions CRUD

    /// Enregistre une session de diagnostic ou de scan dans `scan_sessions`.
    public func insertScanSession(_ session: ScanSessionRecord) throws {
        let sql = """
        INSERT OR REPLACE INTO scan_sessions (id, started_at, completed_at, module, candidates_count, reclaimable_bytes)
        VALUES (?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: lastErrorMessage())
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, session.id.uuidString, -1, sqliteTransient)
        sqlite3_bind_double(stmt, 2, session.startedAt.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 3, session.completedAt.timeIntervalSince1970)
        sqlite3_bind_text(stmt, 4, session.module, -1, sqliteTransient)
        sqlite3_bind_int(stmt, 5, Int32(session.candidatesCount))
        sqlite3_bind_int64(stmt, 6, session.reclaimableBytes)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.executionFailed(message: lastErrorMessage())
        }
    }

    /// Récupère les sessions de diagnostic les plus récentes.
    public func fetchRecentScanSessions(limit: Int = 20) throws -> [ScanSessionRecord] {
        let sql = """
        SELECT id, started_at, completed_at, module, candidates_count, reclaimable_bytes
        FROM scan_sessions
        ORDER BY started_at DESC
        LIMIT ?;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: lastErrorMessage())
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int(stmt, 1, Int32(limit))

        var sessions: [ScanSessionRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let idStr = String(cString: sqlite3_column_text(stmt, 0))
            let startedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1))
            let completedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2))
            let module = String(cString: sqlite3_column_text(stmt, 3))
            let count = Int(sqlite3_column_int(stmt, 4))
            let reclaimable = sqlite3_column_int64(stmt, 5)

            sessions.append(
                ScanSessionRecord(
                    id: UUID(uuidString: idStr) ?? UUID(),
                    startedAt: startedAt,
                    completedAt: completedAt,
                    module: module,
                    candidatesCount: count,
                    reclaimableBytes: reclaimable
                )
            )
        }
        return sessions
    }

    // MARK: - Startup Backups CRUD

    /// Enregistre la sauvegarde d'un `LaunchAgent` désactivé dans la table `startup_backups`.
    public func insertStartupBackup(_ backup: StartupBackupRecord) throws {
        let sql = """
        INSERT OR REPLACE INTO startup_backups (id, label, original_path, backup_path, disabled_at)
        VALUES (?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: lastErrorMessage())
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, backup.id.uuidString, -1, sqliteTransient)
        sqlite3_bind_text(stmt, 2, backup.label, -1, sqliteTransient)
        sqlite3_bind_text(stmt, 3, backup.originalPath, -1, sqliteTransient)
        sqlite3_bind_text(stmt, 4, backup.backupPath, -1, sqliteTransient)
        sqlite3_bind_double(stmt, 5, backup.disabledAt.timeIntervalSince1970)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.executionFailed(message: lastErrorMessage())
        }
    }

    /// Supprime une entrée de sauvegarde `startup_backups` après restauration de l'agent.
    public func removeStartupBackup(id: UUID) throws {
        let sql = "DELETE FROM startup_backups WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: lastErrorMessage())
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, id.uuidString, -1, sqliteTransient)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.executionFailed(message: lastErrorMessage())
        }
    }

    /// Liste tous les `LaunchAgents` actuellement désactivés et sauvegardés dans SQLite.
    public func fetchStartupBackups() throws -> [StartupBackupRecord] {
        let sql = "SELECT id, label, original_path, backup_path, disabled_at FROM startup_backups ORDER BY disabled_at DESC;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: lastErrorMessage())
        }
        defer { sqlite3_finalize(stmt) }

        var list: [StartupBackupRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let idStr = String(cString: sqlite3_column_text(stmt, 0))
            let label = String(cString: sqlite3_column_text(stmt, 1))
            let origPath = String(cString: sqlite3_column_text(stmt, 2))
            let backupPath = String(cString: sqlite3_column_text(stmt, 3))
            let disabledAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))

            list.append(
                StartupBackupRecord(
                    id: UUID(uuidString: idStr) ?? UUID(),
                    label: label,
                    originalPath: origPath,
                    backupPath: backupPath,
                    disabledAt: disabledAt
                )
            )
        }
        return list
    }

    private func lastErrorMessage() -> String {
        guard let db else { return "Base SQLite fermée" }
        return String(cString: sqlite3_errmsg(db))
    }
}

