import SwiftUI

/// En-tête supérieur de télémétrie MacCare :
/// Pilules vitrées pour le stockage APFS, la mémoire Mach, la charge CPU, l'état Full Disk Access et le bouton Assistant / Santé.
public struct DashboardSummaryBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable public var coordinator: NavigationCoordinator

    public init(coordinator: NavigationCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        let snap = coordinator.systemSnapshot
        let healthColor = MacCareTheme.healthGlowColor(for: coordinator.healthScore)

        HStack(spacing: 10) {
            // Pilule Stockage APFS
            telemetryPill(
                icon: "internaldrive.fill",
                iconColor: MacCareTheme.accentPrimary,
                title: snap.volumeName,
                value: "\(MacCareFormatters.formatBytes(snap.availableDiskBytes)) \(coordinator.tr(fr: "libres", en: "free", es: "libres", de: "frei", ja: "空き", zh: "可用"))"
            )

            // Pilule Mémoire Mach
            telemetryPill(
                icon: "memorychip.fill",
                iconColor: MacCareTheme.accentPurple,
                title: "RAM (\(snap.memoryPressure.rawValue))",
                value: "\(MacCareFormatters.formatBytes(snap.usedMemoryBytes)) / \(MacCareFormatters.formatBytes(snap.physicalMemoryBytes))"
            )

            // Pilule Charge CPU
            telemetryPill(
                icon: "cpu.fill",
                iconColor: MacCareTheme.accentSecondary,
                title: "CPU (\(snap.processorCount) \(coordinator.tr(fr: "cœurs", en: "cores", es: "núcleos", de: "Kerne", ja: "コア", zh: "核心")))",
                value: String(format: "%.1f %%", snap.cpuLoadPercentage)
            )

            Spacer()

            // Sélecteur de langue international (6 langues) en 1 clic
            Menu {
                ForEach(AppLanguage.allCases) { lang in
                    Button {
                        coordinator.language = lang
                    } label: {
                        HStack {
                            Text("\(lang.flagEmoji) \(lang.displayName)")
                            if coordinator.language == lang {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "globe")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MacCareTheme.accentPrimary)
                    Text(coordinator.language.shortBadge)
                        .font(.caption.weight(.bold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(MacCareTheme.cardBackground(for: colorScheme), in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(MacCareTheme.cardBorder(for: colorScheme), lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Language / Langue / Idioma / Sprache / 言語 / 语言")

            // Pilule Full Disk Access
            HStack(spacing: 7) {
                Circle()
                    .fill(coordinator.fullDiskAccessStatus == .granted ? MacCareTheme.statusSafe : MacCareTheme.statusConditional)
                    .frame(width: 8, height: 8)
                Text(
                    coordinator.fullDiskAccessStatus == .granted
                        ? coordinator.tr(fr: "Accès complet actif", en: "Full Disk Access ON", es: "Acceso total activo", de: "Festplattenvollzugriff AN", ja: "フルディスクアクセス有効", zh: "完全磁盘访问已开启")
                        : coordinator.tr(fr: "Accès disque limité", en: "Limited Disk Access", es: "Acceso a disco limitado", de: "Eingeschränkter Zugriff", ja: "ディスクアクセス制限", zh: "磁盘访问受限")
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

                if coordinator.fullDiskAccessStatus != .granted {
                    Button(coordinator.tr(fr: "Autoriser…", en: "Grant…", es: "Autorizar…", de: "Erlauben…", ja: "許可…", zh: "授权…")) {
                        coordinator.permissionsManager.openFullDiskAccessSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(MacCareTheme.cardBackground(for: colorScheme), in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(MacCareTheme.cardBorder(for: colorScheme), lineWidth: 1)
            )

            // Bouton Assistant Santé (coin supérieur droit)
            Button {
                coordinator.selectedModule = .smartCare
                Task {
                    await coordinator.performQuickInspection()
                }
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(healthColor)
                        .frame(width: 9, height: 9)
                        .shadow(color: healthColor.opacity(0.8), radius: 5)
                    Text("\(coordinator.tr(fr: "Santé", en: "Health", es: "Salud", de: "Zustand", ja: "ヘルス", zh: "健康度")) • \(coordinator.healthScore)/100")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(healthColor)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(
                    healthColor.opacity(0.14),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .strokeBorder(healthColor.opacity(0.42), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(coordinator.isScanning)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.4)
        }
    }

    private func telemetryPill(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(iconColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(MacCareTheme.cardBackground(for: colorScheme), in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(MacCareTheme.cardBorder(for: colorScheme), lineWidth: 1)
        )
    }
}
