import AppKit
import Foundation

/// Erreurs levées par le garde pré-vol `ActiveProcessGuard` juste avant une opération sur fichier.
public enum PreFlightSecurityError: Error, LocalizedError, Sendable, Equatable {
    case symlinkPointsToProtectedArea(symlinkPath: String, resolvedPath: String)
    case belongsToRunningApplication(path: String, bundleIdentifier: String)
    case restorationSourceMissing(trashPath: String)
    case restorationTargetAlreadyExists(originalPath: String)

    public var errorDescription: String? {
        switch self {
        case let .symlinkPointsToProtectedArea(symlinkPath, resolvedPath):
            return "Sécurité anti-symlink : '\(symlinkPath)' pointe vers une zone protégée ('\(resolvedPath)')."
        case let .belongsToRunningApplication(path, bundleIdentifier):
            return "L'élément '\(path)' appartient à l'application ouverte '\(bundleIdentifier)'. Fermez-la avant de continuer."
        case let .restorationSourceMissing(trashPath):
            return "Impossible de restaurer : le fichier '\(trashPath)' n'est plus présent dans la Corbeille."
        case let .restorationTargetAlreadyExists(originalPath):
            return "Un fichier existe déjà à l'emplacement d'origine '\(originalPath)'."
        }
    }
}

/// Garde de sécurité pré-vol (`ActiveProcessGuard`) vérifiant les processus actifs et la résolution canonique des liens symboliques.
public struct ActiveProcessGuard: Sendable {
    public let activeBundleIdentifiers: Set<String>

    public init(activeBundleIdentifiers: Set<String>? = nil) {
        if let activeBundleIdentifiers {
            self.activeBundleIdentifiers = Set(activeBundleIdentifiers.map { $0.lowercased() })
        } else {
            let ids = NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier?.lowercased() }
            self.activeBundleIdentifiers = Set(ids)
        }
    }

    /// Vérifie qu'un chemin candidat ne appartient pas à une application ouverte et qu'aucun lien symbolique ne redirige vers une zone protégée.
    public func verifyPreFlight(candidate: ScanCandidate, safetyEngine: SafetyEngine) throws {
        let lowerPath = candidate.path.lowercased()

        // 1. Vérification des applications en cours d'exécution
        for bundleID in activeBundleIdentifiers where !bundleID.isEmpty {
            if lowerPath.contains("/\(bundleID)/") || lowerPath.hasSuffix("/\(bundleID)") {
                throw PreFlightSecurityError.belongsToRunningApplication(
                    path: candidate.path,
                    bundleIdentifier: bundleID
                )
            }
        }

        // 2. Vérification anti-symlink (résolution canonique de la cible)
        let url = URL(fileURLWithPath: candidate.path)
        let resolvedPath = url.resolvingSymlinksInPath().path
        let normalizedOriginal = (candidate.path as NSString).standardizingPath
        let normalizedResolved = (resolvedPath as NSString).standardizingPath

        // Ignore le firmlink standard macOS /var -> /private/var et /tmp -> /private/tmp
        let isStandardPrivateAlias = ("/private" + normalizedOriginal) == normalizedResolved
        if normalizedOriginal != normalizedResolved && !isStandardPrivateAlias {
            let targetEval = safetyEngine.evaluate(path: normalizedResolved, category: candidate.category)
            if targetEval.level == .protected {
                throw PreFlightSecurityError.symlinkPointsToProtectedArea(
                    symlinkPath: candidate.path,
                    resolvedPath: normalizedResolved
                )
            }
        }
    }
}

