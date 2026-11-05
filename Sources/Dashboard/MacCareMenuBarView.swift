import AppKit
import SwiftUI

/// Popover de barre des menus de MacCare :
/// - En-tête lumineux d'état de santé
/// - Tuiles de moniteurs matériels (Stockage APFS, RAM Mach, CPU, Protection)
/// - Accès direct aux modules et lancement du scan Smart Care.
public struct MacCareMenuBarView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable public var coordinator: NavigationCoordinator

    public init(coordinator: NavigationCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        let snap = coordinator.systemSnapshot
        let summary = AnalysisSummary(candidates: coordinator.candidates)
        let glowColor = MacCareTheme.healthGlowColor(for: coordinator.healthScore)

        VStack(alignment: .leading, spacing: 14) {
            // En-tête appareil + lueur de santé (`HeathStatus_glow_excellent`)
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(glowColor.opacity(0.22))
                        .frame(width: 40, height: 40)
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(glowColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("MacCare 5 Menu")
                            .font(.headline.weight(.bold))
                        Text(MacCareTheme.healthStatusLabel(for: coordinator.healthScore))
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(glowColor.opacity(0.18), in: Capsule())
                            .foregroundStyle(glowColor)
                    }
                    Text("Score : \(coordinator.healthScore)/100 • Uptime \(MacCareFormatters.formatUptime(snap.uptimeSeconds))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer()

                Button {
                    coordinator.refreshSystemMetrics()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Rafraîchir la télémétrie Mach et APFS")
            }

            // Grille 2x2 de cartes moniteurs matériels
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                menuMonitorTile(
                    title: snap.volumeName,
                    primary: MacCareFormatters.formatBytes(snap.availableDiskBytes),
                    subtitle: "Disponibles",
                    icon: "internaldrive.fill",
                    ratio: snap.diskUsageRatio,
                    tint: MacCareTheme.accentPrimary
                )

                menuMonitorTile(
                    title: "Mémoire RAM",
                    primary: MacCareFormatters.formatBytes(snap.usedMemoryBytes),
                    subtitle: "Pression : \(snap.memoryPressure.rawValue)",
                    icon: "memorychip.fill",
                    ratio: snap.memoryUsageRatio,
                    tint: MacCareTheme.accentPurple
                )

                menuMonitorTile(
                    title: "Processeur",
                    primary: String(format: "%.1f %%", snap.cpuLoadPercentage),
                    subtitle: "\(snap.processorCount) cœurs actifs",
                    icon: "cpu.fill",
                    ratio: snap.cpuLoadPercentage / 100.0,
                    tint: MacCareTheme.accentSecondary
                )

                menuMonitorTile(
                    title: "Protection",
                    primary: "Actif",
                    subtitle: "SIP & XProtect OK",
                    icon: "checkmark.shield.fill",
                    ratio: 1.0,
                    tint: MacCareTheme.statusSafe
                )
            }

            // Bandeau Smart Scan rapide (`storageRunSmartScanIcon`)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nettoyage intelligent")
                        .font(.caption.weight(.bold))
                    Text("\(MacCareFormatters.formatBytes(summary.safeBytes)) récupérables sans risque")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer()
                Button(coordinator.isScanning ? "Analyse…" : "Lancer Smart Scan") {
                    Task {
                        await coordinator.performQuickInspection()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(MacCareTheme.accentSecondary)
                .controlSize(.small)
                .disabled(coordinator.isScanning)
            }
            .padding(10)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Accès rapide aux modules
            HStack(spacing: 8) {
                quickModuleButton(.smartCare)
                quickModuleButton(.systemJunk)
                quickModuleButton(.storageAnalyzer)
                quickModuleButton(.performance)
            }

            Divider()

            HStack {
                Button("Ouvrir MacCare") {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.link)
                .font(.caption.weight(.semibold))

                Spacer()

                Button("Quitter") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.link)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 360)
        .background(MacCareTheme.primaryBackground(for: colorScheme))
    }

    private func menuMonitorTile(
        title: String,
        primary: String,
        subtitle: String,
        icon: String,
        ratio: Double,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(primary)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()

            ProgressView(value: min(1.0, max(0.0, ratio)))
                .tint(tint)

            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue("\(primary), \(subtitle)")
    }

    private func quickModuleButton(_ module: AppModule) -> some View {
        let palette = MacCareTheme.auroraPalette(for: module)
        return Button {
            coordinator.selectedModule = module
            NSApplication.shared.activate(ignoringOtherApps: true)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: module.systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.primary)
                Text(module.title)
                    .font(.system(size: 9, weight: .semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(palette.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
