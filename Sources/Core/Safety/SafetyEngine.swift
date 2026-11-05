import Foundation

/// Résultat d'évaluation d'un chemin par le moteur de sécurité `SafetyEngine`.
public struct SafetyEvaluation: Sendable, Equatable {
    public let level: SafetyLevel
    public let reason: String
    public let impact: String

    public init(level: SafetyLevel, reason: String, impact: String) {
        self.level = level
        self.reason = reason
        self.impact = impact
    }
}

/// Erreurs bloquantes levées lors de la validation d'un `StagingPlan` ou d'un groupe de doublons.
public enum SafetyValidationError: Error, LocalizedError, Sendable, Equatable {
    case emptyPlan
    case protectedItemInPlan(path: String, reason: String)
    case allDuplicatesSelectedInGroup(sha256: String)

    public var errorDescription: String? {
        switch self {
        case .emptyPlan:
            return "Le panier de préparation est vide."
        case .protectedItemInPlan(let path, let reason):
            return "Opération refusée par SafetyEngine : l'élément '\(path)' est protégé (\(reason))."
        case .allDuplicatesSelectedInGroup(let sha256):
            return "Sécurité anti-perte de données : au moins un exemplaire original doit être conservé pour le groupe SHA-256 \(sha256.prefix(12))."
        }
    }
}

/// Moteur déterministe de sécurité et de règles d'exclusion de MacCare.
/// Garantit qu'aucun fichier SIP, système, trousseau, base TCC, dépôt Git ou intérieur d'application signée n'est modifiable.
public struct SafetyEngine: Sendable {
    /// Préfixes système macOS strictement verrouillés en dur.
    public static let hardProtectedPrefixes: [String] = [
        "/System",
        "/usr",
        "/bin",
        "/sbin",
        "/private/var/db",
        "/private/var/root",
        "/private/etc",
        "/Library/Apple",
        "/Library/Extensions",
        "/Library/SystemExtensions",
        "/dev"
    ]

    /// Sous-chemins sensibles dans le répertoire utilisateur ou système.
    public static let sensitivePathFragments: [String] = [
        "/Library/Keychains",
        "/Library/Application Support/com.apple.TCC",
        "/Library/Messages",
        "/Library/Mail",
        "/Library/Safari/Bookmarks.plist",
        "/Library/Safari/History.db",
        "/Library/Caches/CloudKit",
        "/.ssh/",
        "/.gnupg/",
        "/.git/",
        "/.svn/"
    ]

    public let userExclusions: [ExclusionRule]
    public let runningBundleIdentifiers: Set<String>

    public init(
        userExclusions: [ExclusionRule] = [],
        runningBundleIdentifiers: Set<String> = []
    ) {
        self.userExclusions = userExclusions
        self.runningBundleIdentifiers = Set(runningBundleIdentifiers.map { $0.lowercased() })
    }

    /// Évalue un chemin du système de fichiers et retourne son niveau de sécurité (`SafetyLevel`), sa justification et son impact.
    public func evaluate(path: String, category: ScanCategory) -> SafetyEvaluation {
        let normalized = Self.normalizePath(path)

        // 1. Chemins racines critiques
        if normalized.isEmpty || normalized == "/" || normalized == "/Users" || normalized == "/Applications" {
            return SafetyEvaluation(
                level: .protected,
                reason: "Répertoire racine système ou utilisateur inviolable.",
                impact: "Modification interdite."
            )
        }

        // 2. Préfixes système macOS (SIP & binaires OS)
        for prefix in Self.hardProtectedPrefixes {
            if normalized == prefix || normalized.hasPrefix(prefix + "/") {
                return SafetyEvaluation(
                    level: .protected,
                    reason: "Emplacement système macOS protégé (SIP / OS).",
                    impact: "Modification interdite pour préserver l'intégrité de macOS."
                )
            }
        }

        // 3. Fragments sensibles (Keychains, TCC.db, SSH, dépôts Git, Mail, Messages)
        for fragment in Self.sensitivePathFragments {
            let trimmedFragment = fragment.hasSuffix("/") ? String(fragment.dropLast()) : fragment
            if normalized.contains(fragment) || normalized.hasSuffix(trimmedFragment) {
                return SafetyEvaluation(
                    level: .protected,
                    reason: "Contient des données critiques de sécurité, de messagerie ou un dépôt de version (\(trimmedFragment)).",
                    impact: "Protégé contre toute suppression."
                )
            }
        }

        // 4. Interdiction d'altérer l'intérieur d'un bundle .app (préservation de _CodeSignature)
        if Self.isInsideAppBundle(normalized) {
            return SafetyEvaluation(
                level: .protected,
                reason: "Situé à l'intérieur d'un paquet .app : toute modification briserait la signature cryptographique.",
                impact: "Intégrité CodeSignature préservée."
            )
        }

        // 5. Règles d'exclusion personnalisées de l'utilisateur
        for rule in userExclusions {
            let pattern = Self.normalizePath(rule.pathOrPattern)
            guard !pattern.isEmpty else { continue }
            switch rule.ruleType {
            case .exactPath:
                if normalized == pattern || normalized.hasPrefix(pattern + "/") {
                    return SafetyEvaluation(
                        level: .protected,
                        reason: "Protégé par votre règle d'exclusion : \(rule.pathOrPattern).",
                        impact: "Aucune action autorisée."
                    )
                }
            case .globPattern, .bundleIdentifier:
                if normalized.localizedCaseInsensitiveContains(rule.pathOrPattern) {
                    return SafetyEvaluation(
                        level: .protected,
                        reason: "Exclu par le motif utilisateur : \(rule.pathOrPattern).",
                        impact: "Aucune action autorisée."
                    )
                }
            }
        }

        // 6. Protection des caches d'applications en cours d'exécution
        let lowerPath = normalized.lowercased()
        for bundleId in runningBundleIdentifiers where !bundleId.isEmpty {
            if lowerPath.contains("/\(bundleId)/") || lowerPath.hasSuffix("/\(bundleId)") {
                return SafetyEvaluation(
                    level: .protected,
                    reason: "L'application associée (\(bundleId)) est actuellement en cours d'exécution.",
                    impact: "Quittez l'application avant de nettoyer ses fichiers."
                )
            }
        }

        // 7. Classification selon la catégorie fonctionnelle
        switch category {
        case .userCaches, .systemAndUserLogs, .temporaryFiles:
            return SafetyEvaluation(
                level: .safe,
                reason: "Cache ou journal temporaire régénéré automatiquement.",
                impact: "Aucun impact sur vos données ou sessions actives."
            )
        case .xcodeDeveloperArtifacts, .packageManagerCaches:
            return SafetyEvaluation(
                level: .conditional,
                reason: "Artefact de compilation ou cache de paquets volumineux.",
                impact: "Prochain build Xcode ou installation de paquets plus lent(e)."
            )
        case .trashItems:
            return SafetyEvaluation(
                level: .conditional,
                reason: "Élément présent dans la Corbeille utilisateur.",
                impact: "Vérifiez le contenu avant vidage."
            )
        case .largeFiles, .duplicateFiles, .applicationBundles, .applicationLeftovers, .startupItems:
            return SafetyEvaluation(
                level: .conditional,
                reason: "Requiert une sélection manuelle et une confirmation explicite.",
                impact: "Déplacement réversible vers la Corbeille macOS."
            )
        }
    }

    /// Valide l'intégralité d'un `StagingPlan` avant toute exécution par `StagingQueue`.
    public func validate(plan: StagingPlan) throws {
        guard !plan.candidates.isEmpty else {
            throw SafetyValidationError.emptyPlan
        }

        for candidate in plan.candidates {
            if candidate.safetyLevel == .protected {
                throw SafetyValidationError.protectedItemInPlan(
                    path: candidate.path,
                    reason: candidate.explanation
                )
            }
            let recheck = evaluate(path: candidate.path, category: candidate.category)
            if recheck.level == .protected {
                throw SafetyValidationError.protectedItemInPlan(
                    path: candidate.path,
                    reason: recheck.reason
                )
            }
        }
    }

    private static func normalizePath(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        let standardized = (expanded as NSString).standardizingPath
        if standardized.count > 1 && standardized.hasSuffix("/") {
            return String(standardized.dropLast())
        }
        return standardized
    }

    private static func isInsideAppBundle(_ normalizedPath: String) -> Bool {
        let parts = normalizedPath.split(separator: "/").map(String.init)
        for (idx, part) in parts.enumerated() {
            if part.lowercased().hasSuffix(".app") && idx < parts.count - 1 {
                return true
            }
        }
        return false
    }
}
