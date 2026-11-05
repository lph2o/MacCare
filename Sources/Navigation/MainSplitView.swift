import SwiftUI

/// Vue principale de l'application MacCare :
/// - Barre latérale translucide avec icônes colorées et badges d'état
/// - Fond atmosphérique Aurora radial dynamique par module (`AuroraCanvasBackground`)
/// - En-tête Assistant & Stockage (`DashboardSummaryBar`)
/// - Bouton central ubiquitaire flottant en bas au centre (`UbiquitousActionOrbButton`)
/// - Pied de page de nettoyage (`StagingDrawerView`).
public struct MainSplitView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable public var coordinator: NavigationCoordinator

    public init(coordinator: NavigationCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 240, ideal: 255, max: 290)
        } detail: {
            ZStack(alignment: .bottom) {
                AuroraCanvasBackground(
                    module: coordinator.selectedModule,
                    healthScore: coordinator.healthScore
                )

                VStack(spacing: 0) {
                    DashboardSummaryBar(coordinator: coordinator)

                    if let banner = coordinator.statusBannerMessage {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(MacCareTheme.accentPrimary)
                            Text(banner)
                                .font(.caption.weight(.medium))
                            Spacer()
                            Button("Fermer") {
                                coordinator.statusBannerMessage = nil
                            }
                            .buttonStyle(.plain)
                            .font(.caption.weight(.bold))
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 8)
                        .background(MacCareTheme.accentPrimary.opacity(0.14))
                    }

                    ScrollView {
                        moduleDetailView
                            .padding(.horizontal, 26)
                            .padding(.top, 22)
                            .padding(.bottom, 130)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Zone inférieure : soit le tiroir de nettoyage si le panier contient des éléments,
                // soit le Bouton Central Ubiquitaire (`UbiquitousButtonUI`) flottant en bas au centre.
                if !coordinator.stagingQueue.items.isEmpty {
                    StagingDrawerView(coordinator: coordinator)
                } else {
                    ubiquitousFloatingActionBar
                        .padding(.bottom, 18)
                }
            }
        }
        .frame(minWidth: 1120, minHeight: 740)
    }

    // MARK: - Barre latérale de navigation

    private var sidebarContent: some View {
        List(selection: $coordinator.selectedModule) {
            Section {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        MacCareTheme.accentSecondary,
                                        MacCareTheme.accentPurple,
                                        MacCareTheme.accentPrimary
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 38, height: 38)
                            .shadow(color: MacCareTheme.accentSecondary.opacity(0.45), radius: 8, x: 0, y: 4)

                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("MacCare")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Text("Open Source Edition")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Modules") {
                ForEach(AppModule.allCases) { module in
                    let isSelected = coordinator.selectedModule == module
                    let palette = MacCareTheme.auroraPalette(for: module)

                    NavigationLink(value: module) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        isSelected
                                            ? LinearGradient(
                                                colors: [palette.primary, palette.secondary],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                            : LinearGradient(
                                                colors: [Color.secondary.opacity(0.14), Color.secondary.opacity(0.08)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                    )
                                    .frame(width: 28, height: 28)

                                Image(systemName: module.systemImage)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(isSelected ? .white : palette.primary)
                            }

                            Text(module.title)
                                .font(.system(size: 13.5, weight: isSelected ? .semibold : .regular))

                            Spacer()

                            sidebarStatusBadge(for: module)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Statistiques & Sécurité") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(MacCareTheme.statusSafe)
                        Text("Espace libéré cumulé")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    Text(MacCareFormatters.formatBytes(coordinator.cumulativeBytesFreed))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    Text("\(coordinator.exclusionRules.count) exclusion(s) active(s) • \(coordinator.recentScanSessions.count) session(s)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private func sidebarStatusBadge(for module: AppModule) -> some View {
        switch module {
        case .smartCare:
            if coordinator.isScanning {
                ProgressView().controlSize(.mini)
            } else if !coordinator.candidates.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(MacCareTheme.statusSafe)
            } else {
                Text("⌘1").font(.caption2).foregroundStyle(.tertiary)
            }
        case .systemJunk:
            if coordinator.systemJunkReport != nil {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(MacCareTheme.statusSafe)
            } else {
                Text("⌘2").font(.caption2).foregroundStyle(.tertiary)
            }
        case .storageAnalyzer:
            if coordinator.isAnalyzingStorage {
                ProgressView().controlSize(.mini)
            } else if coordinator.storageScanReport != nil {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(MacCareTheme.statusSafe)
            } else {
                Text("⌘3").font(.caption2).foregroundStyle(.tertiary)
            }
        case .appManager:
            if coordinator.isAnalyzingApps {
                ProgressView().controlSize(.mini)
            } else if coordinator.appManagerReport != nil {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(MacCareTheme.statusSafe)
            } else {
                Text("⌘4").font(.caption2).foregroundStyle(.tertiary)
            }
        case .duplicateFinder:
            if coordinator.isDetectingDuplicates {
                ProgressView().controlSize(.mini)
            } else if coordinator.duplicateScanReport != nil {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(MacCareTheme.statusSafe)
            } else {
                Text("⌘5").font(.caption2).foregroundStyle(.tertiary)
            }
        default:
            Text("⌘\(module.indexNumber)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
    }

    // MARK: - Bouton Central Ubiquitaire Flottant (`UbiquitousButtonUI`)

    private var ubiquitousFloatingActionBar: some View {
        let mod = coordinator.selectedModule
        let isBusy = coordinator.isScanning
            || coordinator.isAnalyzingStorage
            || coordinator.isAnalyzingApps
            || coordinator.isDetectingDuplicates
            || coordinator.isRunningMaintenance

        return UbiquitousActionOrbButton(
            title: isBusy ? "Stop" : mod.primaryActionLabel,
            subtitle: ubiquitousSubtitle(for: mod),
            systemImage: isBusy ? "stop.fill" : "sparkles",
            module: mod,
            isBusy: isBusy
        ) {
            triggerUbiquitousAction(for: mod, isBusy: isBusy)
        }
    }

    private func ubiquitousSubtitle(for module: AppModule) -> String? {
        switch module {
        case .smartCare, .systemJunk:
            let summary = AnalysisSummary(candidates: coordinator.candidates)
            return summary.safeBytes > 0 ? MacCareFormatters.formatBytes(summary.safeBytes) : nil
        case .storageAnalyzer:
            if let report = coordinator.storageScanReport {
                return MacCareFormatters.formatBytes(report.rootNode.allocatedBytes)
            }
            return nil
        case .appManager:
            if let report = coordinator.appManagerReport {
                return "\(report.apps.count) apps"
            }
            return nil
        case .duplicateFinder:
            if let report = coordinator.duplicateScanReport, report.totalReclaimableBytes > 0 {
                return MacCareFormatters.formatBytes(report.totalReclaimableBytes)
            }
            return nil
        default:
            return nil
        }
    }

    private func triggerUbiquitousAction(for module: AppModule, isBusy: Bool) {
        if isBusy {
            coordinator.cancelStorageAnalysis()
            return
        }
        switch module {
        case .smartCare:
            Task { await coordinator.performQuickInspection() }
        case .systemJunk:
            Task { await coordinator.performSystemJunkScan() }
        case .storageAnalyzer:
            coordinator.runStorageAnalysis(at: FileManager.default.homeDirectoryForCurrentUser)
        case .appManager:
            Task { await coordinator.performAppManagerAnalysis() }
        case .duplicateFinder:
            let downloads = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
            Task { await coordinator.performDuplicateScan(in: downloads, autoSelectRedundant: true) }
        case .performance:
            coordinator.refreshPerformanceMonitor()
        case .startupManager:
            Task { await coordinator.refreshStartupItems() }
        case .maintenance:
            if let firstSafe = MaintenanceRunnerService.catalog.first {
                Task { await coordinator.executeMaintenanceOperation(firstSafe) }
            }
        case .protection:
            coordinator.refreshSecurityPosture()
        }
    }

    // MARK: - Contenu du module sélectionné

    @ViewBuilder
    private var moduleDetailView: some View {
        switch coordinator.selectedModule {
        case .smartCare:
            SmartCareView(coordinator: coordinator)
        case .systemJunk:
            SystemJunkView(coordinator: coordinator)
        case .storageAnalyzer:
            StorageAnalyzerView(coordinator: coordinator)
        case .appManager:
            AppManagerView(coordinator: coordinator)
        case .duplicateFinder:
            DuplicateFinderView(coordinator: coordinator)
        case .performance:
            PerformanceView(coordinator: coordinator)
        case .startupManager:
            StartupManagerView(coordinator: coordinator)
        case .maintenance:
            MaintenanceView(coordinator: coordinator)
        case .protection:
            ProtectionView(coordinator: coordinator)
        }
    }
}
