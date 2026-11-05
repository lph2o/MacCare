import AppKit
import SwiftUI

/// Délégué AppKit configurant proprement la politique d'activation une fois la boucle d'événements `NSApplication` démarrée.
public final class MacCareAppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let iconImage = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = iconImage
        }
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
            NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
        }
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

/// Point d'entrée principal de l'application native MacCare.
/// Inclut la fenêtre principale (`MainSplitView`) et les Réglages (`SettingsView`).
@main
public struct MacCareApp: App {
    @NSApplicationDelegateAdaptor(MacCareAppDelegate.self) private var appDelegate
    @State private var coordinator = NavigationCoordinator()

    public init() {}

    public var body: some Scene {
        WindowGroup("MacCare") {
            MainSplitView(coordinator: coordinator)
                .preferredColorScheme(.dark)
        }
        .commands {
            CommandMenu("Modules") {
                ForEach(AppModule.allCases) { module in
                    Button(module.title) {
                        coordinator.selectedModule = module
                    }
                    .keyboardShortcut(module.shortcutKey, modifiers: [.command])
                }

                Divider()

                Button("Relancer l'inspection rapide") {
                    Task {
                        await coordinator.performQuickInspection()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }

        Settings {
            SettingsView(coordinator: coordinator)
        }
    }
}
