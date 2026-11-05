import AppKit
import SwiftUI

/// Module 04 — App Manager : Inventaire complet des applications installées (`.app` + architecture Mach-O + fichiers `~/Library` associés)
/// et détection des restes orphelins (*Leftovers*) d'applications désinstallées.
public struct AppManagerView: View {
    public enum AppTab: String, CaseIterable, Identifiable {
        case installedApps = "Applications Installées"
        case orphanedLeftovers = "Restes Orphelins (Leftovers)"

        public var id: String { rawValue }
    }

    @Environment(\.colorScheme) private var colorScheme
    @Bindable public var coordinator: NavigationCoordinator
    @State private var selectedTab: AppTab = .installedApps
    @State private var expandedAppIds: Set<UUID> = []

    public init(coordinator: NavigationCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ModuleHeaderView(
                module: .appManager,
                primaryActionTitle: coordinator.isAnalyzingApps ? "Analyse en cours…" : "Analyser les applications et résidus"
            ) {
                Task {
                    await coordinator.performAppManagerAnalysis()
                }
            }

            if let report = coordinator.appManagerReport {
                Picker("Vue", selection: $selectedTab) {
                    Text("Applications Installées (\(report.apps.count))").tag(AppTab.installedApps)
                    Text("Restes Orphelins (\(report.orphanedLeftovers.count))").tag(AppTab.orphanedLeftovers)
                }
                .pickerStyle(.segmented)

                switch selectedTab {
                case .installedApps:
                    installedAppsList(report.apps)
                case .orphanedLeftovers:
                    leftoversList(report.orphanedLeftovers)
                }
            } else {
                ModuleIntroHeroView(
                    module: .appManager,
                    isScanning: coordinator.isAnalyzingApps,
                    statusText: coordinator.isAnalyzingApps ? "Analyse des bundles .app et de ~/Library…" : "Prêt pour l'inspection"
                )
            }
        }
    }

    private func installedAppsList(_ apps: [AnalyzedAppBundle]) -> some View {
        VStack(spacing: 10) {
            ForEach(apps) { app in
                appCard(app)
            }
        }
    }

    private func appCard(_ app: AnalyzedAppBundle) -> some View {
        let isExpanded = expandedAppIds.contains(app.id)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundlePath))
                    .resizable()
                    .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(app.name)
                            .font(.headline)
                        Text("v\(app.version)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(app.architecture.rawValue)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(MacCareTheme.accentSecondary.opacity(0.15), in: Capsule())
                            .foregroundStyle(MacCareTheme.accentSecondary)
                        if app.isRunning {
                            Text("En cours d'exécution")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(MacCareTheme.statusProtected.opacity(0.16), in: Capsule())
                                .foregroundStyle(MacCareTheme.statusProtected)
                        }
                    }

                    Text("\(app.bundleIdentifier) • Bundle : \(MacCareFormatters.formatBytes(app.appBundleSizeBytes)) • Données ~/Library (\(app.associatedFiles.count)) : \(MacCareFormatters.formatBytes(app.associatedSizeBytes))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer()

                SafetyBadgeView(level: app.safetyLevel)

                Text(MacCareFormatters.formatBytes(app.totalFootprintBytes))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()

                if !app.associatedFiles.isEmpty {
                    Button(isExpanded ? "Masquer détails" : "Fichiers (\(app.associatedFiles.count))") {
                        if isExpanded {
                            expandedAppIds.remove(app.id)
                        } else {
                            expandedAppIds.insert(app.id)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if app.safetyLevel != .protected {
                    Button("Préparer désinstallation") {
                        coordinator.stageAppForUninstall(app)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MacCareTheme.accentPrimary)
                    .controlSize(.small)
                }
            }

            if isExpanded && !app.associatedFiles.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(app.associatedFiles) { assoc in
                        HStack {
                            Text(assoc.kindLabel)
                                .font(.caption2.weight(.semibold))
                                .frame(width: 140, alignment: .leading)
                            Text(assoc.path)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Text(MacCareFormatters.formatBytes(assoc.sizeBytes))
                                .font(.caption2)
                                .monospacedDigit()
                        }
                    }
                }
                .padding(.leading, 50)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MacCareTheme.cardBackground(for: colorScheme))
        )
    }

    private func leftoversList(_ leftovers: [OrphanedLeftoverItem]) -> some View {
        VStack(spacing: 10) {
            if leftovers.isEmpty {
                ContentUnavailableView(
                    "Aucun résidu orphelin détecté",
                    systemImage: "checkmark.seal.fill",
                    description: Text("Tous les dossiers inspectés dans ~/Library correspondent à des applications installées.")
                )
                .frame(height: 180)
            } else {
                ForEach(leftovers) { item in
                    HStack(spacing: 12) {
                        SafetyBadgeView(level: item.safetyLevel)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(item.displayName)
                                    .font(.subheadline.weight(.semibold))
                                Text(item.locationKind)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.14), in: Capsule())
                            }
                            Text(item.path)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(item.explanation)
                                .font(.caption2)
                                .foregroundStyle(MacCareTheme.textSecondary)
                        }
                        Spacer()
                        Text(MacCareFormatters.formatBytes(item.sizeBytes))
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                        Button("Ajouter au panier") {
                            let candidate = ScanCandidate(
                                path: item.path,
                                displayName: item.displayName,
                                category: .applicationLeftovers,
                                sizeBytes: item.sizeBytes,
                                safetyLevel: item.safetyLevel,
                                explanation: item.explanation,
                                potentialImpact: "Déplacement réversible du résidu orphelin vers la Corbeille.",
                                isSelected: true
                            )
                            coordinator.stagingQueue.addOrUpdate(candidate)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MacCareTheme.accentPrimary)
                        .controlSize(.small)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(MacCareTheme.cardBackground(for: colorScheme))
                    )
                }
            }
        }
    }
}
