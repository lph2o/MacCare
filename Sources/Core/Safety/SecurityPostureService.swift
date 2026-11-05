import Darwin
import Foundation
import Security

/// Statut de vérification de signature cryptographique `SecStaticCode` (`Security.framework`).
public enum CodeSignatureStatus: String, Codable, Sendable, Equatable {
    case validSigned = "Signature Valide"
    case adHocOrUnsigned = "Non signé / Ad-hoc"
    case invalidOrTampered = "Signature Invalide"
    case targetMissing = "Binaire Introuvable"
}

/// Résultat d'audit de signature d'un exécutable ou bundle macOS.
public struct CodeSignatureAuditItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let label: String
    public let targetPath: String
    public let status: CodeSignatureStatus
    public let signingIdentifier: String?
    public let teamIdentifier: String?
    public let safetyLevel: SafetyLevel

    public init(
        id: UUID = UUID(),
        label: String,
        targetPath: String,
        status: CodeSignatureStatus,
        signingIdentifier: String? = nil,
        teamIdentifier: String? = nil,
        safetyLevel: SafetyLevel
    ) {
        self.id = id
        self.label = label
        self.targetPath = targetPath
        self.status = status
        self.signingIdentifier = signingIdentifier
        self.teamIdentifier = teamIdentifier
        self.safetyLevel = safetyLevel
    }
}

/// Fichier portant l'attribut étendu de quarantaine macOS (`com.apple.quarantine`).
public struct QuarantinedFileItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let path: String
    public let name: String
    public let agentName: String
    public let rawQuarantineValue: String
    public let sizeBytes: Int64
    public let safetyLevel: SafetyLevel

    public init(
        id: UUID = UUID(),
        path: String,
        name: String,
        agentName: String,
        rawQuarantineValue: String,
        sizeBytes: Int64,
        safetyLevel: SafetyLevel = .conditional
    ) {
        self.id = id
        self.path = path
        self.name = name
        self.agentName = agentName
        self.rawQuarantineValue = rawQuarantineValue
        self.sizeBytes = sizeBytes
        self.safetyLevel = safetyLevel
    }
}

/// Synthèse de la posture de sécurité macOS produite par `SecurityPostureService`.
public struct SecurityPostureReport: Sendable, Equatable {
    public let sipRootReadOnlyVerified: Bool
    public let xprotectBundlePresent: Bool
    public let gatekeeperDatabasePresent: Bool
    public let auditedStartupSignatures: [CodeSignatureAuditItem]
    public let quarantinedFiles: [QuarantinedFileItem]
    public let durationMilliseconds: Double
}

/// Service défensif d'audit de sécurité macOS (Module **09 — Protection**).
/// Utilise `Security.framework` (`SecStaticCode`) pour vérifier les signatures cryptographiques
/// et l'appel POSIX `getxattr` pour inspecter l'attribut `com.apple.quarantine` en lecture seule.
public struct SecurityPostureService: Sendable {
    public static let quarantineAttributeName = "com.apple.quarantine"

    public init() {}

    /// Exécute un audit complet de la posture de sécurité, des signatures d'agents de lancement et des fichiers en quarantaine.
    public func evaluatePosture(
        startupItems: [StartupLaunchItem]? = nil,
        quarantineScanDirectory: URL? = nil
    ) -> SecurityPostureReport {
        let start = CFAbsoluteTimeGetCurrent()
        let fm = FileManager.default

        // 1. Vérification non intrusive de l'état SIP (Volume racine /System protégé en lecture seule)
        let sipVerified = fm.fileExists(atPath: "/System/Library/Sandbox/rootless.conf")
            && !fm.isWritableFile(atPath: "/System/Library")

        // 2. Présence des composants XProtect et Gatekeeper de macOS
        let xprotectPresent = fm.fileExists(atPath: "/Library/Apple/System/Library/CoreServices/XProtect.bundle")
            || fm.fileExists(atPath: "/System/Library/CoreServices/XProtect.bundle")
        let gatekeeperPresent = fm.fileExists(atPath: "/private/var/db/SystemPolicy")
            || fm.fileExists(atPath: "/var/db/SystemPolicy-prefs.plist")
            || fm.fileExists(atPath: "/usr/sbin/spctl")

        // 3. Audit SecStaticCode des exécutables des LaunchAgents
        let itemsToAudit = startupItems ?? StartupItemsService().discoverStartupItems()
        var auditedSignatures: [CodeSignatureAuditItem] = []

        for item in itemsToAudit.prefix(25) {
            if let execPath = item.executablePath {
                let audit = Self.verifyCodeSignature(atPath: execPath, label: item.label)
                auditedSignatures.append(audit)
            } else {
                auditedSignatures.append(
                    CodeSignatureAuditItem(
                        label: item.label,
                        targetPath: item.plistPath,
                        status: .targetMissing,
                        safetyLevel: .conditional
                    )
                )
            }
        }

        // 4. Inspection des fichiers portant l'attribut com.apple.quarantine (ex: ~/Downloads)
        let scanDir = quarantineScanDirectory ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        let quarantined = Self.scanQuarantinedFiles(in: scanDir, maxFiles: 60)

        let elapsedMs = max(0.1, (CFAbsoluteTimeGetCurrent() - start) * 1000.0)
        return SecurityPostureReport(
            sipRootReadOnlyVerified: sipVerified,
            xprotectBundlePresent: xprotectPresent,
            gatekeeperDatabasePresent: gatekeeperPresent,
            auditedStartupSignatures: auditedSignatures,
            quarantinedFiles: quarantined,
            durationMilliseconds: elapsedMs
        )
    }

    // MARK: - Vérification cryptographique SecStaticCode (Security.framework)

    public static func verifyCodeSignature(atPath path: String, label: String? = nil) -> CodeSignatureAuditItem {
        let expanded = (path as NSString).expandingTildeInPath
        let displayLabel = label ?? (expanded as NSString).lastPathComponent

        guard FileManager.default.fileExists(atPath: expanded) else {
            return CodeSignatureAuditItem(
                label: displayLabel,
                targetPath: expanded,
                status: .targetMissing,
                safetyLevel: .conditional
            )
        }

        let url = URL(fileURLWithPath: expanded) as CFURL
        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(url, SecCSFlags(), &staticCode)

        guard createStatus == errSecSuccess, let code = staticCode else {
            return CodeSignatureAuditItem(
                label: displayLabel,
                targetPath: expanded,
                status: .adHocOrUnsigned,
                safetyLevel: .conditional
            )
        }

        let validityStatus = SecStaticCodeCheckValidity(code, SecCSFlags(), nil)
        var infoCF: CFDictionary?
        _ = SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &infoCF)
        let info = infoCF as? [String: Any]
        let signingID = info?[kSecCodeInfoIdentifier as String] as? String
        let teamID = info?[kSecCodeInfoTeamIdentifier as String] as? String

        if validityStatus == errSecSuccess {
            return CodeSignatureAuditItem(
                label: displayLabel,
                targetPath: expanded,
                status: .validSigned,
                signingIdentifier: signingID,
                teamIdentifier: teamID,
                safetyLevel: .safe
            )
        } else if validityStatus == errSecCSUnsigned {
            return CodeSignatureAuditItem(
                label: displayLabel,
                targetPath: expanded,
                status: .adHocOrUnsigned,
                signingIdentifier: signingID,
                teamIdentifier: teamID,
                safetyLevel: .conditional
            )
        } else {
            return CodeSignatureAuditItem(
                label: displayLabel,
                targetPath: expanded,
                status: .invalidOrTampered,
                signingIdentifier: signingID,
                teamIdentifier: teamID,
                safetyLevel: .conditional
            )
        }
    }

    // MARK: - Lecture POSIX getxattr pour com.apple.quarantine

    /// Lit la valeur de l'attribut étendu `com.apple.quarantine` sur un fichier s'il est présent.
    public static func readQuarantineAttribute(atPath path: String) -> (agentName: String, rawValue: String)? {
        let size = getxattr(path, quarantineAttributeName, nil, 0, 0, XATTR_NOFOLLOW)
        guard size > 0 && size < 4096 else { return nil }

        var buffer = [CChar](repeating: 0, count: size + 1)
        let readBytes = getxattr(path, quarantineAttributeName, &buffer, size, 0, XATTR_NOFOLLOW)
        guard readBytes > 0 else { return nil }

        let rawString = String(cString: buffer).trimmingCharacters(in: .controlCharacters)
        // Format standard macOS : "flags;timestamp;agentName;UUID"
        let parts = rawString.split(separator: ";", omittingEmptySubsequences: false).map(String.init)
        let agent = (parts.count >= 3 && !parts[2].isEmpty) ? parts[2] : "Navigateur / Téléchargement externe"
        return (agentName: agent, rawValue: rawString)
    }

    /// Recherche les fichiers portant l'attribut `com.apple.quarantine` dans un dossier donné.
    public static func scanQuarantinedFiles(in directoryURL: URL, maxFiles: Int = 60) -> [QuarantinedFileItem] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.fileSizeKey, .totalFileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var found: [QuarantinedFileItem] = []
        for url in entries.prefix(maxFiles) {
            let path = url.path
            if let qInfo = readQuarantineAttribute(atPath: path) {
                let vals = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey])
                let size = Int64(vals?.totalFileAllocatedSize ?? vals?.fileSize ?? 0)
                found.append(
                    QuarantinedFileItem(
                        path: path,
                        name: url.lastPathComponent,
                        agentName: qInfo.agentName,
                        rawQuarantineValue: qInfo.rawValue,
                        sizeBytes: size
                    )
                )
            }
        }
        return found
    }
}

