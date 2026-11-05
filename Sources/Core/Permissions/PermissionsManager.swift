import AppKit
import Foundation

/// État des autorisations macOS TCC pertinentes pour MacCare.
public enum PermissionStatus: String, Sendable, Equatable {
    case granted = "Accordé"
    case restrictedOrDenied = "Accès limité"
    case notDetermined = "Non vérifié"
}

/// Gestionnaire des permissions macOS (Full Disk Access et sélection explicite via `NSOpenPanel`).
/// Respecte strictement TCC et SIP : aucune tentative de contournement.
public struct PermissionsManager: Sendable {
    public init() {}

    /// Vérifie de manière non intrusive si l'application dispose de l'Accès complet au disque (Full Disk Access)
    /// sans jamais déclencher de boîte de dialogue bloquante du démon système TCC (`tccd`).
    public func checkFullDiskAccess() -> PermissionStatus {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let probePath = "\(home)/Library/Safari"
        if access(probePath, R_OK) == 0 {
            return .granted
        }
        return .restrictedOrDenied
    }

    /// Ouvre directement le volet "Accès complet au disque" dans Réglages Système macOS.
    @MainActor
    public func openFullDiskAccessSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// Demande à l'utilisateur de choisir explicitement un dossier à analyser via `NSOpenPanel`.
    @MainActor
    public func requestDirectoryAccess(message: String = "Choisissez un dossier à analyser avec MacCare") -> URL? {
        let panel = NSOpenPanel()
        panel.message = message
        panel.prompt = "Autoriser l'analyse"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        return panel.runModal() == .OK ? panel.url : nil
    }
}

