import AppKit
import SwiftUI

/// Module 07 — Startup Manager : Inspection des `LaunchAgents` / `LaunchDaemons`, détection des plists brisés
/// (exécutable cible manquant) et désactivation/restauration réversible sauvegardée dans SQLite (`startup_backups`).
public struct StartupManagerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable public var coordinator: NavigationCoordinator

    public init(coordinator: NavigationCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ModuleHeaderView(
                module: .startupManager,
                primaryActionTitle: "Actualiser les agents de démarrage"
            ) {
                Task {
                    await coordinator.refreshStartupItems()
                }
            }

            if !coordinator.startupBackups.isEmpty {
                disabledBackupsSection
            }

            activeItemsSection
        }
        .onAppear {
            if coordinator.startupItems.isEmpty {
                Task {
                    await coordinator.refreshStartupItems()
                }
            }
        }
    }

    private var disabledBackupsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("LaunchAgents désactivés par MacCare (Restaurables depuis SQLite)", systemImage: "arrow.uturn.backward.circle.fill")
                .font(.headline)
                .foregroundStyle(MacCareTheme.accentPrimary)

            ForEach(coordinator.startupBackups) { backup in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(backup.label)
                            .font(.subheadline.weight(.semibold))
                        Text("Origine : \(backup.originalPath)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Réactiver à l'emplacement d'origine") {
                        Task {
                            await coordinator.restoreStartupBackup(backup)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MacCareTheme.accentPrimary)
                    .controlSize(.small)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(MacCareTheme.cardBackground(for: colorScheme))
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(MacCareTheme.accentPrimary.opacity(0.35), lineWidth: 1)
        )
    }

    private var activeItemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            let brokenCount = coordinator.startupItems.filter(\.isBrokenExecutable).count
            Text("Agents et démons détectés (\(coordinator.startupItems.count)) • Plists orphelins/brisés : \(brokenCount)")
                .font(.headline)

            ForEach(coordinator.startupItems) { item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: item.isBrokenExecutable ? "exclamationmark.triangle.fill" : "power.circle.fill")
                        .foregroundStyle(item.isBrokenExecutable ? MacCareTheme.statusConditional : MacCareTheme.accentPrimary)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(item.label)
                                .font(.subheadline.weight(.bold))
                            Text(item.scope.rawValue)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.14), in: Capsule())
                            if item.runAtLoad {
                                Text("RunAtLoad")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(MacCareTheme.accentSecondary)
                            }
                            if item.isBrokenExecutable {
                                Text("Exécutable manquant")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(MacCareTheme.statusConditional.opacity(0.18), in: Capsule())
                                    .foregroundStyle(MacCareTheme.statusConditional)
                            }
                        }

                        Text("Plist : \(item.plistPath)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)

                        if let exec = item.executablePath {
                            Text("Binaire cible : \(exec)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        Text(item.statusExplanation)
                            .font(.caption)
                            .foregroundStyle(MacCareTheme.textSecondary)
                    }

                    Spacer()

                    SafetyBadgeView(level: item.safetyLevel)

                    Button("Finder") {
                        NSWorkspace.shared.selectFile(item.plistPath, inFileViewerRootedAtPath: "")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    if item.safetyLevel != .protected && item.scope == .userLaunchAgent {
                        Button("Désactiver (Réversible)") {
                            Task {
                                await coordinator.disableStartupItem(item)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MacCareTheme.accentPrimary)
                        .controlSize(.small)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(MacCareTheme.cardBackground(for: colorScheme))
                )
            }
        }
    }
}
