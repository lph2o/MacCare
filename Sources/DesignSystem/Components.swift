import AppKit
import SwiftUI

/// Fond atmosphérique Aurora radial dynamique s'adaptant au module actif et au score de santé.
public struct AuroraCanvasBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    public let module: AppModule
    public let healthScore: Int

    public init(module: AppModule, healthScore: Int = 95) {
        self.module = module
        self.healthScore = healthScore
    }

    public var body: some View {
        let palette = MacCareTheme.auroraPalette(for: module)
        let glowColor = MacCareTheme.healthGlowColor(for: healthScore)

        ZStack {
            MacCareTheme.primaryBackground(for: colorScheme)

            // Halo supérieur gauche lié au module actif
            RadialGradient(
                colors: [
                    palette.primary.opacity(colorScheme == .dark ? 0.28 : 0.14),
                    palette.secondary.opacity(colorScheme == .dark ? 0.10 : 0.05),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 30,
                endRadius: 560
            )

            // Halo central/droit inspiré de `DeviceGlow_*` / `BackgroundGlowColor_*`
            RadialGradient(
                colors: [
                    palette.secondary.opacity(colorScheme == .dark ? 0.22 : 0.10),
                    glowColor.opacity(colorScheme == .dark ? 0.08 : 0.04),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 520
            )

            // Halo inférieur centré sous l'UbiquitousButton (`auroraBottomLimiter`)
            RadialGradient(
                colors: [
                    palette.primary.opacity(colorScheme == .dark ? 0.24 : 0.12),
                    Color.clear
                ],
                center: .bottom,
                startRadius: 10,
                endRadius: 380
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.45), value: module)
    }
}

/// Scène d'introduction monumentale du module :
/// Affiche les 3 piliers fonctionnels à gauche et l'orbe 3D lumineux du module à droite.
public struct ModuleIntroHeroView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.macCareLanguage) private var language
    public let module: AppModule
    public let isScanning: Bool
    public let statusText: String?
    public let extraActionTitle: String?
    public let onExtraAction: (() -> Void)?

    public init(
        module: AppModule,
        isScanning: Bool = false,
        statusText: String? = nil,
        extraActionTitle: String? = nil,
        onExtraAction: (() -> Void)? = nil
    ) {
        self.module = module
        self.isScanning = isScanning
        self.statusText = statusText
        self.extraActionTitle = extraActionTitle
        self.onExtraAction = onExtraAction
    }

    public var body: some View {
        let palette = MacCareTheme.auroraPalette(for: module)

        HStack(alignment: .center, spacing: 44) {
            // Colonne gauche : Titre monumental, sous-titre et 3 piliers avec icônes
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(module.phaseBadge.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(palette.primary)

                    Text(module.localizedTitle(in: language))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(module.localizedSubtitle(in: language))
                        .font(.title3.weight(.regular))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 18) {
                    ForEach(module.introFeatures) { pillar in
                        HStack(alignment: .top, spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [palette.primary.opacity(0.24), palette.secondary.opacity(0.14)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(palette.primary.opacity(0.35), lineWidth: 1)
                                    )

                                Image(systemName: pillar.icon)
                                    .font(.system(size: 19, weight: .semibold))
                                    .foregroundStyle(palette.primary)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(pillar.title)
                                    .font(.headline.weight(.semibold))
                                Text(pillar.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                if let extraActionTitle, let onExtraAction {
                    Button(action: onExtraAction) {
                        Label(extraActionTitle, systemImage: "folder.badge.gearshape")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: 520, alignment: .leading)

            Spacer(minLength: 20)

            // Colonne droite : Orbe 3D multicouche avec anneaux lumineux Aurora
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                palette.primary.opacity(0.42),
                                palette.secondary.opacity(0.18),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 170
                        )
                    )
                    .frame(width: 330, height: 330)
                    .blur(radius: 18)

                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: [palette.primary, palette.secondary, palette.primary.opacity(0.3), palette.primary],
                            center: .center
                        ),
                        lineWidth: isScanning ? 5 : 2.5
                    )
                    .frame(width: 230, height: 230)
                    .opacity(0.75)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.primary.opacity(0.32),
                                palette.secondary.opacity(0.22)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 190, height: 190)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.28), lineWidth: 1.5)
                    )
                    .shadow(color: palette.primary.opacity(0.38), radius: 28, x: 0, y: 14)

                VStack(spacing: 12) {
                    Image(systemName: module.systemImage)
                        .font(.system(size: 66, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, palette.secondary.opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: palette.primary.opacity(0.6), radius: 14)

                    if let statusText {
                        Text(statusText)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.35), in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(width: 330, height: 330)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(MacCareTheme.cardBackground(for: colorScheme))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(MacCareTheme.cardBorder(for: colorScheme), lineWidth: 1)
        )
    }
}

/// Le Bouton Central Ubiquitaire de MacCare,
/// positionné en bas au centre de la fenêtre avec halo Aurora et anneau de progression.
public struct UbiquitousActionOrbButton: View {
    public let title: String
    public let subtitle: String?
    public let systemImage: String
    public let module: AppModule
    public let isBusy: Bool
    public let action: () -> Void

    public init(
        title: String,
        subtitle: String? = nil,
        systemImage: String = "play.fill",
        module: AppModule,
        isBusy: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.module = module
        self.isBusy = isBusy
        self.action = action
    }

    public var body: some View {
        let palette = MacCareTheme.auroraPalette(for: module)

        Button(action: action) {
            ZStack {
                // Halo externe Aurora (`auroraRadialLimiter`)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                palette.primary.opacity(0.55),
                                palette.secondary.opacity(0.25),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 18,
                            endRadius: 68
                        )
                    )
                    .frame(width: 124, height: 124)

                // Anneau externe lumineux
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: [palette.primary, palette.secondary, .white.opacity(0.75), palette.primary],
                            center: .center
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 92, height: 92)

                // Disque principal du bouton
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [palette.primary, palette.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 82, height: 82)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1.2)
                    )
                    .shadow(color: palette.primary.opacity(0.5), radius: 16, x: 0, y: 8)

                VStack(spacing: 3) {
                    if isBusy {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: systemImage)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    Text(title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.88))
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 6)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(subtitle != nil ? "\(title), \(subtitle!)" : title)
    }
}

/// Badge visuel indiquant le niveau de sécurité (`Sûr`, `Conditionnel`, `Protégé`).
public struct SafetyBadgeView: View {
    public let level: SafetyLevel

    public init(level: SafetyLevel) {
        self.level = level
    }

    public var body: some View {
        let badgeColor = MacCareTheme.color(for: level)
        HStack(spacing: 5) {
            Image(systemName: MacCareTheme.icon(for: level))
                .font(.caption2.weight(.semibold))
            Text(level.badgeTitle)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .foregroundStyle(badgeColor)
        .background(badgeColor.opacity(0.16), in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(badgeColor.opacity(0.38), lineWidth: 1)
        )
        .help(level.defaultExplanation)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Niveau de sécurité : \(level.badgeTitle)")
        .accessibilityHint(level.defaultExplanation)
    }
}

/// Carte Bento vitrée (`MetricCardView`) pour les tuiles de synthèse de MacCare.
public struct MetricCardView: View {
    @Environment(\.colorScheme) private var colorScheme

    public let title: String
    public let primaryValue: String
    public let subtitle: String
    public let systemImage: String
    public let accentColor: Color
    public let progress: Double?

    public init(
        title: String,
        primaryValue: String,
        subtitle: String,
        systemImage: String,
        accentColor: Color = MacCareTheme.accentPrimary,
        progress: Double? = nil
    ) {
        self.title = title
        self.primaryValue = primaryValue
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.accentColor = accentColor
        self.progress = progress
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(accentColor.opacity(0.18))
                        .frame(width: 30, height: 30)
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accentColor)
                }

                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
            }

            Text(primaryValue)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()

            if let progress {
                GeometryReader { geo in
                    let clamped = min(1.0, max(0.0, progress))
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.10))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [accentColor, accentColor.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(6, geo.size.width * clamped))
                    }
                }
                .frame(height: 6)
            }

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MacCareTheme.cardBackground(for: colorScheme))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(MacCareTheme.cardBorder(for: colorScheme), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue("\(primaryValue), \(subtitle)")
    }
}

/// Barre segmentée d'occupation du disque APFS (Utilisé, Purgeable APFS, Libre) avec dégradés lumineux Aurora.
public struct StorageBarView: View {
    public let snapshot: SystemSnapshot

    public init(snapshot: SystemSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "internaldrive.fill")
                        .foregroundStyle(MacCareTheme.accentPrimary)
                    Text(snapshot.volumeName)
                        .font(.subheadline.weight(.bold))
                    Text(snapshot.fileSystemType)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(MacCareTheme.accentPrimary.opacity(0.16), in: Capsule())
                        .foregroundStyle(MacCareTheme.accentPrimary)
                }
                Spacer()
                Text("\(MacCareFormatters.formatBytes(snapshot.availableDiskBytes)) disponibles sur \(MacCareFormatters.formatBytes(snapshot.totalDiskBytes))")
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                let total = max(1.0, Double(snapshot.totalDiskBytes))
                let usedWidth = CGFloat(Double(snapshot.usedDiskBytes) / total) * geo.size.width
                let purgeableWidth = CGFloat(Double(snapshot.purgeableDiskBytes) / total) * geo.size.width

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.12))
                    HStack(spacing: 3) {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [MacCareTheme.accentPurple, MacCareTheme.accentPrimary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(8, usedWidth))
                        if purgeableWidth > 4 {
                            Capsule()
                                .fill(MacCareTheme.statusConditional)
                                .frame(width: purgeableWidth)
                        }
                    }
                }
            }
            .frame(height: 12)

            HStack(spacing: 18) {
                legendDot(color: MacCareTheme.accentPrimary, label: "Utilisé : \(MacCareFormatters.formatBytes(snapshot.usedDiskBytes))")
                legendDot(color: MacCareTheme.statusConditional, label: "Purgeable APFS : \(MacCareFormatters.formatBytes(snapshot.purgeableDiskBytes))")
                legendDot(color: MacCareTheme.statusSafe, label: "Disponible : \(MacCareFormatters.formatBytes(snapshot.availableDiskBytes))")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .monospacedDigit()
        }
    }
}

/// En-tête standardisé de module avec badge Aurora et action primaire.
public struct ModuleHeaderView: View {
    @Environment(\.macCareLanguage) private var language
    public let module: AppModule
    public let primaryActionTitle: String?
    public let onPrimaryAction: (() -> Void)?

    public init(
        module: AppModule,
        primaryActionTitle: String? = nil,
        onPrimaryAction: (() -> Void)? = nil
    ) {
        self.module = module
        self.primaryActionTitle = primaryActionTitle
        self.onPrimaryAction = onPrimaryAction
    }

    public var body: some View {
        let palette = MacCareTheme.auroraPalette(for: module)

        HStack(alignment: .center, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [palette.primary, palette.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .shadow(color: palette.primary.opacity(0.35), radius: 10, x: 0, y: 4)

                Image(systemName: module.systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 10) {
                    Text(module.localizedTitle(in: language))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(module.phaseBadge)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(palette.primary.opacity(0.18), in: Capsule())
                        .foregroundStyle(palette.primary)
                }
                Text(module.localizedSubtitle(in: language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let primaryActionTitle, let onPrimaryAction {
                Button(action: onPrimaryAction) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text(primaryActionTitle)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(
                            colors: [palette.primary, palette.secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                    .shadow(color: palette.primary.opacity(0.35), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Pied de page flottant & Bouton Central de préparation du nettoyage.
public struct StagingDrawerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable public var coordinator: NavigationCoordinator
    @State private var isShowingConfirmation = false

    public init(coordinator: NavigationCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        let queue = coordinator.stagingQueue
        let palette = MacCareTheme.auroraPalette(for: coordinator.selectedModule)

        if !queue.items.isEmpty {
            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(palette.primary.opacity(0.20))
                        .frame(width: 42, height: 42)
                    Image(systemName: "tray.full.fill")
                        .font(.title3)
                        .foregroundStyle(palette.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(coordinator.tr(fr: "Sélection prête :", en: "Ready to clean:", es: "Selección lista:", de: "Auswahl bereit:", ja: "選択済み:", zh: "已选项目:")) \(queue.selectedItems.count) (\(MacCareFormatters.formatBytes(queue.selectedBytes)))")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                    Text(coordinator.tr(fr: "Mode sécurisé : Déplacement réversible vers la Corbeille macOS + Journal SQLite", en: "Safe Mode: Reversible move to macOS Trash + SQLite Audit Log", es: "Modo seguro: Movimiento reversible a la Papelera + SQLite", de: "Sicherer Modus: In den macOS-Papierkorb + SQLite-Protokoll", ja: "安全モード：macOSゴミ箱へ移動＋SQLite監査ログ", zh: "安全模式：可逆移至 macOS 废纸篓 + SQLite 审计日志"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if queue.requiresExplicitConfirmation {
                    SafetyBadgeView(level: .conditional)
                } else {
                    SafetyBadgeView(level: .safe)
                }

                Spacer()

                Button(coordinator.tr(fr: "Vider la sélection", en: "Clear", es: "Vaciar", de: "Leeren", ja: "クリア", zh: "清空")) {
                    queue.clear()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button(coordinator.tr(fr: "Examiner le détail…", en: "Review Details…", es: "Revisar detalles…", de: "Details prüfen…", ja: "詳細を確認…", zh: "查看详情…")) {
                    isShowingConfirmation = true
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                UbiquitousActionOrbButton(
                    title: coordinator.tr(fr: "Nettoyer", en: "Clean", es: "Limpiar", de: "Bereinigen", ja: "クリーン", zh: "清理"),
                    subtitle: MacCareFormatters.formatBytes(queue.selectedBytes),
                    systemImage: "sparkles",
                    module: coordinator.selectedModule,
                    isBusy: coordinator.isScanning
                ) {
                    isShowingConfirmation = true
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) {
                Divider()
            }
            .sheet(isPresented: $isShowingConfirmation) {
                StagingConfirmationModalView(
                    coordinator: coordinator,
                    isPresented: $isShowingConfirmation
                )
            }
        }
    }
}

/// Fenêtre modale de confirmation de nettoyage haute sécurité de MacCare.
/// Affiche l'orbe lumineux du module, le bilan par niveau de sécurité (`.safe` vs `.conditional`),
/// les garanties de réversibilité (Corbeille macOS + Audit SQLite + Garde anti-symlink),
/// et la liste interactive filtrable des éléments avec accès direct au Finder.
public struct StagingConfirmationModalView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable public var coordinator: NavigationCoordinator
    @Binding public var isPresented: Bool
    @State private var searchQuery: String = ""
    @State private var filterLevel: SafetyLevel? = nil
    @State private var isExecuting: Bool = false

    public init(coordinator: NavigationCoordinator, isPresented: Binding<Bool>) {
        self.coordinator = coordinator
        self._isPresented = isPresented
    }

    public var body: some View {
        let queue = coordinator.stagingQueue
        let palette = MacCareTheme.auroraPalette(for: coordinator.selectedModule)
        let safeSelected = queue.selectedItems.filter { $0.safetyLevel == .safe }
        let conditionalSelected = queue.selectedItems.filter { $0.safetyLevel == .conditional }
        let safeBytes = safeSelected.reduce(Int64(0)) { $0 + $1.sizeBytes }
        let conditionalBytes = conditionalSelected.reduce(Int64(0)) { $0 + $1.sizeBytes }

        ZStack {
            AuroraCanvasBackground(
                module: coordinator.selectedModule,
                healthScore: coordinator.healthScore
            )

            VStack(spacing: 0) {
                // 1. En-tête Hero avec Orbe 3D et volume total à libérer
                headerSection(
                    queue: queue,
                    palette: palette
                )

                Divider().opacity(0.35)

                // 2. Cartes de synthèse de sécurité + Bandeau d'alerte conditionnelle
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        summarySecurityTile(
                            title: coordinator.tr(fr: "Nettoyage Sûr", en: "Safe Cleanup", es: "Limpieza Segura", de: "Sichere Bereinigung", ja: "安全なクリーンアップ", zh: "安全清理"),
                            count: safeSelected.count,
                            bytes: safeBytes,
                            icon: "checkmark.shield.fill",
                            tint: MacCareTheme.statusSafe,
                            subtitle: coordinator.tr(fr: "Caches et fichiers régénérables", en: "Regenerable caches & logs", es: "Cachés y registros regenerables", de: "Regenerierbare Caches & Logs", ja: "再生成可能なキャッシュとログ", zh: "可自动重建的缓存与日志"),
                            isActiveFilter: filterLevel == .safe
                        ) {
                            filterLevel = (filterLevel == .safe) ? nil : .safe
                        }

                        summarySecurityTile(
                            title: coordinator.tr(fr: "À Vérifier (Conditionnel)", en: "Review (Conditional)", es: "A Revisar (Condicional)", de: "Prüfen (Bedingt)", ja: "要確認（条件付き）", zh: "需确认（条件性）"),
                            count: conditionalSelected.count,
                            bytes: conditionalBytes,
                            icon: "exclamationmark.triangle.fill",
                            tint: MacCareTheme.statusConditional,
                            subtitle: coordinator.tr(fr: "Artefacts dev, téléchargements ou résidus", en: "Build artifacts, downloads or leftovers", es: "Artefactos dev, descargas o residuos", de: "Build-Artefakte oder Überreste", ja: "開発キャッシュや残存ファイル", zh: "开发构建产物、下载或残留"),
                            isActiveFilter: filterLevel == .conditional
                        ) {
                            filterLevel = (filterLevel == .conditional) ? nil : .conditional
                        }

                        reversibilityGuaranteeTile(palette: palette)
                    }

                    if !conditionalSelected.isEmpty {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.shield.fill")
                                .font(.title3)
                                .foregroundStyle(MacCareTheme.statusConditional)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(coordinator.tr(fr: "Attention :", en: "Notice:", es: "Atención:", de: "Hinweis:", ja: "注意:", zh: "注意：")) \(conditionalSelected.count) (\(MacCareFormatters.formatBytes(conditionalBytes)))")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(MacCareTheme.statusConditional)
                                Text(coordinator.tr(fr: "Ces fichiers peuvent nécessiter une recompilation (ex. Xcode DerivedData) ou contenir des archives téléchargées.", en: "These items may require rebuilding (e.g. Xcode DerivedData) or contain downloaded archives.", es: "Estos archivos pueden requerir recompilación o contener archivos descargados.", de: "Diese Dateien erfordern ggf. eine Neukompilierung (z. B. DerivedData).", ja: "これらのファイルは再ビルドが必要になる場合があります（Xcode DerivedDataなど）。", zh: "这些文件可能需要重新编译（如 Xcode DerivedData）或包含下载归档。"))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button(coordinator.tr(fr: "Décocher les conditionnels", en: "Uncheck Conditional", es: "Desmarcar condicionales", de: "Bedingte abwählen", ja: "条件付きを解除", zh: "取消勾选条件项")) {
                                queue.deselectConditionalItems()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(MacCareTheme.statusConditional.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(MacCareTheme.statusConditional.opacity(0.38), lineWidth: 1)
                        )
                    }

                    // Barre de filtre et sélection rapide
                    HStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField(coordinator.tr(fr: "Filtrer les fichiers par nom, chemin ou catégorie…", en: "Filter files by name, path, or category…", es: "Filtrar archivos por nombre o ruta…", de: "Dateien nach Name oder Pfad filtern…", ja: "名前、パス、カテゴリでフィルタ…", zh: "按名称、路径或类别筛选文件…"), text: $searchQuery)
                                .textFieldStyle(.plain)
                                .font(.caption)
                            if !searchQuery.isEmpty {
                                Button {
                                    searchQuery = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(MacCareTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(MacCareTheme.cardBorder(for: colorScheme), lineWidth: 1)
                        )

                        if filterLevel != nil {
                            Button("\(coordinator.tr(fr: "Afficher tout", en: "Show All", es: "Mostrar todo", de: "Alle anzeigen", ja: "すべて表示", zh: "显示全部")) (\(queue.items.count))") {
                                filterLevel = nil
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        Button(coordinator.tr(fr: "Tout cocher", en: "Select All", es: "Seleccionar todo", de: "Alle auswählen", ja: "すべて選択", zh: "全选")) {
                            queue.selectAllItems()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // 3. Liste interactive des éléments du panier
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredItems(from: queue.items)) { item in
                            stagedItemRow(item: item, queue: queue)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider().opacity(0.35)

                // 4. Pied de page d'action avec bouton lumineux Aurora
                footerActionSection(queue: queue, palette: palette)
            }
        }
        .frame(width: 780, height: 610)
        .preferredColorScheme(.dark)
    }

    private func filteredItems(from items: [ScanCandidate]) -> [ScanCandidate] {
        items.filter { item in
            if let filterLevel, item.safetyLevel != filterLevel {
                return false
            }
            guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
                return true
            }
            let q = searchQuery.lowercased()
            return item.displayName.lowercased().contains(q)
                || item.path.lowercased().contains(q)
                || item.category.rawValue.lowercased().contains(q)
        }
    }

    private func headerSection(
        queue: StagingQueue,
        palette: (primary: Color, secondary: Color)
    ) -> some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [palette.primary.opacity(0.45), palette.secondary.opacity(0.18), .clear],
                            center: .center,
                            startRadius: 6,
                            endRadius: 42
                        )
                    )
                    .frame(width: 76, height: 76)

                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: [palette.primary, palette.secondary, .white.opacity(0.7), palette.primary],
                            center: .center
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: 60, height: 60)

                Image(systemName: "trash.slash.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: palette.primary.opacity(0.6), radius: 8)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(coordinator.tr(fr: "Confirmer le nettoyage sécurisé", en: "Confirm Safe Cleanup", es: "Confirmar limpieza segura", de: "Sichere Bereinigung bestätigen", ja: "安全なクリーンアップの確認", zh: "确认安全清理"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text(coordinator.selectedModule.localizedTitle(in: coordinator.language))
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(palette.primary.opacity(0.20), in: Capsule())
                        .foregroundStyle(palette.primary)
                }

                Text(coordinator.tr(fr: "Vérifiez les éléments sélectionnés avant leur déplacement réversible vers la Corbeille macOS.", en: "Review selected items before moving them reversibly to the macOS Trash.", es: "Revisa los elementos seleccionados antes de moverlos a la Papelera de macOS.", de: "Überprüfen Sie die ausgewählten Elemente vor dem Verschieben in den Papierkorb.", ja: "macOSのゴミ箱へ移動する前に選択項目を確認してください。", zh: "在移至 macOS 废纸篓前请核对所选项目。"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(MacCareFormatters.formatBytes(queue.selectedBytes))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, palette.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("\(queue.selectedItems.count) / \(queue.items.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(.ultraThinMaterial)
    }

    private func summarySecurityTile(
        title: String,
        count: Int,
        bytes: Int64,
        icon: String,
        tint: Color,
        subtitle: String,
        isActiveFilter: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(tint)
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(count)")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(tint.opacity(0.18), in: Capsule())
                        .foregroundStyle(tint)
                }

                Text(MacCareFormatters.formatBytes(bytes))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isActiveFilter ? tint.opacity(0.16) : MacCareTheme.cardBackground(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isActiveFilter ? tint : MacCareTheme.cardBorder(for: colorScheme), lineWidth: isActiveFilter ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func reversibilityGuaranteeTile(palette: (primary: Color, secondary: Color)) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .foregroundStyle(palette.secondary)
                Text("Filet de sécurité actif")
                    .font(.caption.weight(.bold))
                Spacer()
                Text("SQLite WAL")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(palette.secondary.opacity(0.18), in: Capsule())
                    .foregroundStyle(palette.secondary)
            }

            Text("100 % Réversible")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(palette.secondary)

            Text("Corbeille macOS + Garde anti-symlink")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(MacCareTheme.cardBackground(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(MacCareTheme.cardBorder(for: colorScheme), lineWidth: 1)
        )
    }

    private func stagedItemRow(item: ScanCandidate, queue: StagingQueue) -> some View {
        HStack(spacing: 12) {
            Toggle(
                "",
                isOn: Binding(
                    get: { item.isSelected },
                    set: { _ in queue.toggleSelection(for: item.id) }
                )
            )
            .toggleStyle(.checkbox)
            .labelsHidden()

            SafetyBadgeView(level: item.safetyLevel)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.displayName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(item.category.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.08), in: Capsule())
                        .foregroundStyle(.secondary)
                }

                Text(item.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text("\(item.explanation) • Impact : \(item.potentialImpact)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            Text(MacCareFormatters.formatBytes(item.sizeBytes))
                .font(.subheadline.weight(.bold))
                .monospacedDigit()

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
            } label: {
                Image(systemName: "folder")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .help("Révéler dans le Finder")

            Button {
                queue.remove(candidateId: item.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Retirer du panier")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(item.isSelected ? MacCareTheme.cardBackground(for: colorScheme) : Color.white.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    item.safetyLevel == .conditional && item.isSelected
                        ? MacCareTheme.statusConditional.opacity(0.35)
                        : MacCareTheme.cardBorder(for: colorScheme),
                    lineWidth: 1
                )
        )
        .opacity(item.isSelected ? 1.0 : 0.55)
    }

    private func footerActionSection(
        queue: StagingQueue,
        palette: (primary: Color, secondary: Color)
    ) -> some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(MacCareTheme.statusSafe)
                Text(coordinator.tr(fr: "Restauration en 1 clic disponible à tout moment dans System Junk et Réglages.", en: "1-click restore available anytime in System Junk and Settings.", es: "Restauración en 1 clic disponible en todo momento.", de: "1-Klick-Wiederherstellung jederzeit verfügbar.", ja: "いつでも1クリックで元の場所へ復元可能です。", zh: "随时可在系统垃圾或设置中一键还原。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(coordinator.tr(fr: "Annuler", en: "Cancel", es: "Cancelar", de: "Abbrechen", ja: "キャンセル", zh: "取消")) {
                isPresented = false
            }
            .keyboardShortcut(.cancelAction)
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button {
                guard !isExecuting, !queue.selectedItems.isEmpty else { return }
                isExecuting = true
                Task {
                    await coordinator.executeStagedPlan()
                    isExecuting = false
                    isPresented = false
                }
            } label: {
                HStack(spacing: 8) {
                    if isExecuting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(
                        queue.selectedItems.isEmpty
                            ? coordinator.tr(fr: "Aucun élément sélectionné", en: "No items selected", es: "Ningún elemento seleccionado", de: "Keine Auswahl", ja: "項目が未選択です", zh: "未选择项目")
                            : "\(coordinator.tr(fr: "Déplacer vers la Corbeille", en: "Move to Trash", es: "Mover a la Papelera", de: "In den Papierkorb", ja: "ゴミ箱へ移動", zh: "移至废纸篓")) (\(MacCareFormatters.formatBytes(queue.selectedBytes)))"
                    )
                    .fontWeight(.bold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: queue.selectedItems.isEmpty
                            ? [Color.gray.opacity(0.4), Color.gray.opacity(0.3)]
                            : [palette.primary, palette.secondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .shadow(color: queue.selectedItems.isEmpty ? .clear : palette.primary.opacity(0.45), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(queue.selectedItems.isEmpty || isExecuting)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
    }
}
