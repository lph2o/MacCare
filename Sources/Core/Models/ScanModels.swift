import Foundation

/// Niveau de classification de sécurité attribué par `SafetyEngine` à chaque élément inspecté.
public enum SafetyLevel: String, Codable, CaseIterable, Sendable, Comparable {
    /// Élément régénérable automatiquement sans perte de données ni déconnexion.
    case safe = "SAFE"
    /// Élément volumineux ou utile au débogage ; jamais coché par défaut, requiert une confirmation explicite.
    case conditional = "CONDITIONAL"
    /// Élément critique système, SIP, TCC, trousseau, dépôt Git ou intérieur de bundle `.app` signé. Verrouillé.
    case protected = "PROTECTED"

    public var badgeTitle: String {
        switch self {
        case .safe: return "Sûr"
        case .conditional: return "Conditionnel"
        case .protected: return "Protégé"
        }
    }

    public var defaultExplanation: String {
        switch self {
        case .safe:
            return "Cache ou fichier temporaire régénéré automatiquement par macOS ou l'application."
        case .conditional:
            return "Peut être nettoyé mais entraîne un recalcul ou la perte d'historique de diagnostic."
        case .protected:
            return "Protégé par SafetyEngine : fichier système, données personnelles critiques ou signature d'application."
        }
    }

    private var sortOrder: Int {
        switch self {
        case .safe: return 0
        case .conditional: return 1
        case .protected: return 2
        }
    }

    public static func < (lhs: SafetyLevel, rhs: SafetyLevel) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

/// Catégories fonctionnelles d'analyse de MacCare.
public enum ScanCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case userCaches = "Caches Utilisateur"
    case systemAndUserLogs = "Journaux & Diagnostics"
    case temporaryFiles = "Fichiers Temporaires"
    case xcodeDeveloperArtifacts = "Artefacts Xcode & Dev"
    case packageManagerCaches = "Caches Gestionnaires de Paquets"
    case trashItems = "Corbeille"
    case largeFiles = "Fichiers Volumineux"
    case duplicateFiles = "Doublons"
    case applicationBundles = "Applications"
    case applicationLeftovers = "Résidus d'Applications"
    case startupItems = "Éléments de Démarrage"

    public var id: String { rawValue }
}

/// Élément candidat détecté par le moteur d'analyse et qualifié par `SafetyEngine`.
public struct ScanCandidate: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let path: String
    public let displayName: String
    public let category: ScanCategory
    public let sizeBytes: Int64
    public let lastModified: Date?
    public let safetyLevel: SafetyLevel
    public let explanation: String
    public let potentialImpact: String
    public var isSelected: Bool

    public init(
        id: UUID = UUID(),
        path: String,
        displayName: String,
        category: ScanCategory,
        sizeBytes: Int64,
        lastModified: Date? = nil,
        safetyLevel: SafetyLevel,
        explanation: String,
        potentialImpact: String,
        isSelected: Bool = false
    ) {
        self.id = id
        self.path = path
        self.displayName = displayName
        self.category = category
        self.sizeBytes = max(0, sizeBytes)
        self.lastModified = lastModified
        self.safetyLevel = safetyLevel
        self.explanation = explanation
        self.potentialImpact = potentialImpact
        // Un élément protégé ou conditionnel n'est jamais pré-sélectionné par défaut sans action valide
        self.isSelected = safetyLevel == .protected ? false : isSelected
    }
}

/// Mode d'exécution d'une opération de nettoyage ou de restauration.
public enum FileActionMode: String, Codable, Hashable, Sendable {
    case moveToTrash = "MOVE_TO_TRASH"
    case quarantineFolder = "QUARANTINE_FOLDER"
    case permanentDelete = "PERMANENT_DELETE"
    case restoreFromTrash = "RESTORE_FROM_TRASH"
}

/// Plan d'action immuable soumis à `SafetyEngine.validate(plan:)` avant exécution.
public struct StagingPlan: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let createdAt: Date
    public let candidates: [ScanCandidate]
    public let actionMode: FileActionMode

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        candidates: [ScanCandidate],
        actionMode: FileActionMode = .moveToTrash
    ) {
        self.id = id
        self.createdAt = createdAt
        self.candidates = candidates
        self.actionMode = actionMode
    }

    public var totalBytes: Int64 {
        candidates.reduce(0) { $0 + $1.sizeBytes }
    }
}

/// Entrée du journal d'audit persistée dans la table SQLite `action_logs`.
public struct AuditLogEntry: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let executedAt: Date
    public let module: String
    public let actionMode: FileActionMode
    public let originalPath: String
    public let destinationPath: String?
    public let bytesFreed: Int64
    public let status: String
    public let errorMessage: String?

    public init(
        id: UUID = UUID(),
        executedAt: Date = Date(),
        module: String,
        actionMode: FileActionMode,
        originalPath: String,
        destinationPath: String? = nil,
        bytesFreed: Int64,
        status: String,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.executedAt = executedAt
        self.module = module
        self.actionMode = actionMode
        self.originalPath = originalPath
        self.destinationPath = destinationPath
        self.bytesFreed = bytesFreed
        self.status = status
        self.errorMessage = errorMessage
    }
}

/// Règle d'exclusion configurée par l'utilisateur et stockée dans SQLite `exclusion_rules`.
public struct ExclusionRule: Identifiable, Codable, Hashable, Sendable {
    public enum RuleType: String, Codable, CaseIterable, Sendable {
        case exactPath = "EXACT_PATH"
        case globPattern = "GLOB_PATTERN"
        case bundleIdentifier = "BUNDLE_ID"
    }

    public let id: UUID
    public let pathOrPattern: String
    public let ruleType: RuleType
    public let note: String
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        pathOrPattern: String,
        ruleType: RuleType = .exactPath,
        note: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.pathOrPattern = pathOrPattern
        self.ruleType = ruleType
        self.note = note
        self.createdAt = createdAt
    }
}
