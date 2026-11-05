import SwiftUI

/// Fenêtre de Réglages macOS (`⌘,`) permettant d'inspecter la base SQLite, le journal d'audit, la restauration et les permissions.
public struct SettingsView: View {
    @Bindable public var coordinator: NavigationCoordinator

    public init(coordinator: NavigationCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("Général & Sécurité", systemImage: "shield.checkered")
                }

            auditLogTab
                .tabItem {
                    Label("Journal d'audit SQLite & Restauration", systemImage: "list.clipboard")
                }
        }
        .padding(20)
        .frame(width: 720, height: 450)
    }

    private var generalTab: some View {
        Form {
            Section("Politique d'action par défaut") {
                Picker("Mode de nettoyage", selection: $coordinator.stagingQueue.preferredMode) {
                    Text("Déplacer vers la Corbeille macOS (Recommandé)").tag(FileActionMode.moveToTrash)
                    Text("Suppression directe (Requiert confirmation)").tag(FileActionMode.permanentDelete)
                }
                Toggle("Afficher le moniteur MacCare dans la barre des menus macOS", isOn: $coordinator.showMenuBarExtra)
                Text("Conformément à la charte MacCare, aucune action n'est exécutée sans validation par SafetyEngine, ActiveProcessGuard et confirmation explicite.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Permissions macOS (TCC)") {
                HStack {
                    Text("Accès complet au disque :")
                    Spacer()
                    Text(coordinator.fullDiskAccessStatus.rawValue)
                        .fontWeight(.semibold)
                    Button("Ouvrir Réglages Système…") {
                        coordinator.permissionsManager.openFullDiskAccessSettings()
                    }
                }
            }
        }
    }

    private var auditLogTab: some View {
        let logs = coordinator.recentAuditLogs
        return VStack(alignment: .leading, spacing: 10) {
            Text("Historique des opérations enregistrées dans SQLite (`action_logs`)")
                .font(.headline)

            if logs.isEmpty {
                ContentUnavailableView(
                    "Aucune opération exécutée",
                    systemImage: "checkmark.seal",
                    description: Text("Les opérations de nettoyage confirmées apparaîtront ici avec possibilité de restauration depuis la Corbeille.")
                )
            } else {
                List {
                    ForEach(logs) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(entry.module)
                                        .font(.caption.weight(.bold))
                                    Text(entry.status)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(entry.status == "FAILED" ? MacCareTheme.statusProtected : MacCareTheme.statusSafe)
                                    Text(MacCareFormatters.formatBytes(entry.bytesFreed))
                                        .font(.caption)
                                        .monospacedDigit()
                                }
                                Text(entry.originalPath)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let trashPath = entry.destinationPath,
                               entry.status == "SUCCESS",
                               FileManager.default.fileExists(atPath: trashPath) {
                                Button("Restaurer") {
                                    Task {
                                        await coordinator.restoreAuditEntry(entry)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }
        }
    }
}
