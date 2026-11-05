import AppKit
import Charts
import SwiftUI

/// Module 06 — Performance : Courbes temps réel CPU/RAM (`Swift Charts`), détail de la mémoire Mach,
/// inventaire des processus actifs (`proc_pid_rusage`) et fermeture coopérative des applications utilisateur.
public struct PerformanceView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable public var coordinator: NavigationCoordinator

    public init(coordinator: NavigationCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        let snap = coordinator.systemSnapshot
        VStack(alignment: .leading, spacing: 18) {
            ModuleHeaderView(
                module: .performance,
                primaryActionTitle: "Rafraîchir la télémétrie & processus"
            ) {
                coordinator.refreshPerformanceMonitor()
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 14)], spacing: 14) {
                MetricCardView(
                    title: "Charge CPU (\(snap.processorCount) cœurs)",
                    primaryValue: String(format: "%.1f %%", snap.cpuLoadPercentage),
                    subtitle: "User \(String(format: "%.0f%%", snap.cpuUserPercentage)) • Système \(String(format: "%.0f%%", snap.cpuSystemPercentage))",
                    systemImage: "cpu.fill",
                    accentColor: MacCareTheme.accentSecondary,
                    progress: snap.cpuLoadPercentage / 100.0
                )
                MetricCardView(
                    title: "Mémoire Active",
                    primaryValue: MacCareFormatters.formatBytes(snap.activeMemoryBytes),
                    subtitle: "Pression : \(snap.memoryPressure.rawValue)",
                    systemImage: "bolt.horizontal.fill",
                    accentColor: MacCareTheme.accentPrimary,
                    progress: snap.memoryUsageRatio
                )
                MetricCardView(
                    title: "Mémoire Résidente (Wired)",
                    primaryValue: MacCareFormatters.formatBytes(snap.wiredMemoryBytes),
                    subtitle: "Verrouillée par le noyau XNU",
                    systemImage: "lock.fill",
                    accentColor: MacCareTheme.statusConditional
                )
                MetricCardView(
                    title: "Mémoire Compressée & Libre",
                    primaryValue: MacCareFormatters.formatBytes(snap.compressedMemoryBytes),
                    subtitle: "Libre : \(MacCareFormatters.formatBytes(snap.freeMemoryBytes))",
                    systemImage: "arrow.down.right.and.arrow.up.left",
                    accentColor: MacCareTheme.statusSafe
                )
            }

            telemetryHistoryChartsSection

            transparencyBanner

            runningProcessesSection
        }
        .onAppear {
            coordinator.refreshPerformanceMonitor()
        }
    }

    private var telemetryHistoryChartsSection: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Historique Charge CPU (%)")
                    .font(.headline)
                Chart(coordinator.telemetryHistory) { sample in
                    LineMark(
                        x: .value("Instant", sample.timestamp),
                        y: .value("CPU %", sample.cpuLoadPercentage)
                    )
                    .foregroundStyle(MacCareTheme.accentSecondary)
                    AreaMark(
                        x: .value("Instant", sample.timestamp),
                        y: .value("CPU %", sample.cpuLoadPercentage)
                    )
                    .foregroundStyle(MacCareTheme.accentSecondary.opacity(0.18))
                }
                .chartYScale(domain: 0 ... 100)
                .frame(height: 140)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(MacCareTheme.cardBackground(for: colorScheme))
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("Historique Mémoire Utilisée (Go)")
                    .font(.headline)
                Chart(coordinator.telemetryHistory) { sample in
                    LineMark(
                        x: .value("Instant", sample.timestamp),
                        y: .value("Go", sample.usedMemoryGigabytes)
                    )
                    .foregroundStyle(MacCareTheme.accentPrimary)
                    AreaMark(
                        x: .value("Instant", sample.timestamp),
                        y: .value("Go", sample.usedMemoryGigabytes)
                    )
                    .foregroundStyle(MacCareTheme.accentPrimary.opacity(0.18))
                }
                .frame(height: 140)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(MacCareTheme.cardBackground(for: colorScheme))
            )
        }
    }

    private var transparencyBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Principe de transparence : Zéro fausse optimisation de la RAM", systemImage: "info.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MacCareTheme.accentPrimary)
            Text("Forcer la purge de la mémoire sous macOS détruit les caches fichiers du noyau XNU et ralentit le Mac (page-ins). Pour libérer réellement de la mémoire, fermez ci-dessous les applications utilisateur inutilisées.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MacCareTheme.cardBackground(for: colorScheme))
        )
    }

    private var runningProcessesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Applications et processus actifs (\(coordinator.runningProcesses.count)) — triés par empreinte physique `proc_pid_rusage`")
                .font(.headline)

            ForEach(coordinator.runningProcesses.prefix(25)) { proc in
                HStack(spacing: 12) {
                    if let path = proc.bundlePath {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                            .resizable()
                            .frame(width: 28, height: 28)
                    } else {
                        Image(systemName: "gearshape.fill")
                            .frame(width: 28, height: 28)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(proc.name)
                                .font(.subheadline.weight(.semibold))
                            Text("PID \(proc.pid)")
                                .font(.caption2)
                                .monospacedDigit()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.14), in: Capsule())
                        }
                        Text(proc.bundleIdentifier)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    SafetyBadgeView(level: proc.safetyLevel)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(proc.physicalFootprintBytes > 0 ? MacCareFormatters.formatBytes(proc.physicalFootprintBytes) : "Protégé noyau")
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                        Text(String(format: "CPU : %.1f s", proc.cpuTimeSeconds))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 110, alignment: .trailing)

                    if !proc.isSystemOrProtected {
                        Button("Quitter l'app") {
                            coordinator.terminateRunningProcess(proc)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(MacCareTheme.cardBackground(for: colorScheme))
                )
            }
        }
    }
}
