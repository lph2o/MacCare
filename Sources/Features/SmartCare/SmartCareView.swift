import Charts
import SwiftUI

/// Module 01 — Smart Care :
/// - Scène Hero avec 3 piliers d'entretien intelligent
/// - Grille de 4 tuiles Bento de synthèse (Nettoyage, Protection, Performances, Stockage)
/// - Anneau lumineux d'état de santé + Graphiques `Swift Charts` et journal des sessions SQLite.
public struct SmartCareView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable public var coordinator: NavigationCoordinator
    @State private var showIntroHero: Bool = false

    public init(coordinator: NavigationCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        let snap = coordinator.systemSnapshot
        let summary = AnalysisSummary(candidates: coordinator.candidates)

        VStack(alignment: .leading, spacing: 22) {
            if showIntroHero || coordinator.candidates.isEmpty {
                ModuleIntroHeroView(
                    module: .smartCare,
                    isScanning: coordinator.isScanning,
                    statusText: coordinator.isScanning
                        ? coordinator.tr(fr: "Analyse intelligente en cours…", en: "Smart scan in progress…", es: "Análisis inteligente en curso…", de: "Intelligenter Scan läuft…", ja: "スマートスキャン中…", zh: "正在进行智能扫描…")
                        : coordinator.tr(fr: "Prêt pour l'analyse", en: "Ready to scan", es: "Listo para analizar", de: "Bereit zum Scannen", ja: "スキャン準備完了", zh: "准备就绪"),
                    extraActionTitle: coordinator.candidates.isEmpty
                        ? coordinator.tr(fr: "Lancer l'analyse Smart Care", en: "Run Smart Care Scan", es: "Iniciar análisis Smart Care", de: "Smart Care-Scan starten", ja: "スマートケアを開始", zh: "开始智能扫描")
                        : coordinator.tr(fr: "Voir le tableau de bord des résultats", en: "View Results Dashboard", es: "Ver panel de resultados", de: "Ergebnisse anzeigen", ja: "結果ダッシュボードを表示", zh: "查看结果面板")
                ) {
                    if coordinator.candidates.isEmpty {
                        Task { await coordinator.performQuickInspection() }
                    } else {
                        showIntroHero = false
                    }
                }
            } else {
                smartCareDeviceHeroBanner(snap: snap, summary: summary)
            }

            // Les 4 grandes tuiles de résultats Smart Care (Bento Grid)
            smartCareFourTilesBentoGrid(snap: snap, summary: summary)

            StorageBarView(snapshot: snap)
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(MacCareTheme.cardBackground(for: colorScheme))
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(MacCareTheme.cardBorder(for: colorScheme), lineWidth: 1)
                )

            HStack(alignment: .top, spacing: 18) {
                machTelemetryChartCard(snap: snap)
                categoryChartCard(summary: summary)
            }

            HStack(alignment: .top, spacing: 18) {
                recommendationsCard
                topCandidatesCard
            }

            recentSessionsCard
        }
    }

    // MARK: - Bandeau Hero Appareil & Score de Santé (`AssistantModule` / `DeviceGlow_*`)

    private func smartCareDeviceHeroBanner(snap: SystemSnapshot, summary: AnalysisSummary) -> some View {
        let glowColor = MacCareTheme.healthGlowColor(for: coordinator.healthScore)
        let palette = MacCareTheme.auroraPalette(for: .smartCare)

        return HStack(spacing: 24) {
            // Anneau lumineux HealthScore + silhouette Mac
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [glowColor.opacity(0.38), Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 62
                        )
                    )
                    .frame(width: 112, height: 112)

                Circle()
                    .stroke(glowColor.opacity(0.20), lineWidth: 9)
                    .frame(width: 88, height: 88)

                Circle()
                    .trim(from: 0, to: CGFloat(coordinator.healthScore) / 100.0)
                    .stroke(
                        AngularGradient(
                            colors: [palette.primary, glowColor, palette.secondary],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 88, height: 88)

                VStack(spacing: 1) {
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(glowColor)
                    Text("\(coordinator.healthScore)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(MacCareTheme.healthStatusLabel(for: coordinator.healthScore))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(glowColor)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text("Bienvenue dans Smart Care")
                        .font(.system(size: 24, weight: .bold, design: .rounded))

                    Text("État : \(MacCareTheme.healthStatusLabel(for: coordinator.healthScore))")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(glowColor.opacity(0.18), in: Capsule())
                        .foregroundStyle(glowColor)

                    Button("Présentation") {
                        showIntroHero = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }

                Text("Volume \(snap.volumeName) (\(snap.fileSystemType)) • \(coordinator.candidates.count) élément(s) qualifié(s) en \(String(format: "%.0f ms", coordinator.lastDiagnosticDurationMs)) • \(MacCareFormatters.formatBytes(summary.totalReclaimableBytes)) détectés.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 14) {
                    Label("Nettoyage sûr : \(MacCareFormatters.formatBytes(summary.safeBytes))", systemImage: "checkmark.shield.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MacCareTheme.statusSafe)
                    Label("Pression RAM : \(snap.memoryPressure.rawValue)", systemImage: "memorychip")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MacCareTheme.accentPrimary)
                    Label("Uptime : \(MacCareFormatters.formatUptime(snap.uptimeSeconds))", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if summary.safeBytes > 0 {
                Button {
                    coordinator.stageAllSafeCandidates()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.title3.weight(.bold))
                        Text("Préparer le soin sûr")
                            .font(.caption.weight(.bold))
                        Text(MacCareFormatters.formatBytes(summary.safeBytes))
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [palette.primary, palette.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .shadow(color: palette.primary.opacity(0.45), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(MacCareTheme.cardBackground(for: colorScheme))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(glowColor.opacity(0.32), lineWidth: 1.2)
        )
    }

    // MARK: - Les 4 Tuiles Bento de Résultats Smart Care

    private func smartCareFourTilesBentoGrid(snap: SystemSnapshot, summary: AnalysisSummary) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 16)], spacing: 16) {
            smartCareBentoTile(
                title: coordinator.tr(fr: "Nettoyage Système", en: "System Cleanup", es: "Limpieza del Sistema", de: "Systembereinigung", ja: "システムクリーンアップ", zh: "系统清理"),
                badge: coordinator.tr(fr: "Sûr & Conditionnel", en: "Safe & Conditional", es: "Seguro y Condicional", de: "Sicher & Bedingt", ja: "安全・条件付き", zh: "安全与条件项"),
                value: MacCareFormatters.formatBytes(summary.safeBytes),
                subtitle: coordinator.tr(fr: "Caches et journaux prêts à nettoyer", en: "Caches & logs ready to clean", es: "Cachés y registros listos", de: "Caches & Protokolle bereit", ja: "キャッシュとログを整理可能", zh: "可清理的缓存与日志"),
                icon: "trash.circle.fill",
                palette: MacCareTheme.auroraPalette(for: .systemJunk),
                actionLabel: coordinator.tr(fr: "Examiner", en: "Review", es: "Revisar", de: "Prüfen", ja: "確認", zh: "查看")
            ) {
                coordinator.selectedModule = .systemJunk
            }

            smartCareBentoTile(
                title: coordinator.tr(fr: "Protection & Intégrité", en: "Protection & Integrity", es: "Protección e Integridad", de: "Schutz & Integrität", ja: "保護と整合性", zh: "安全与完整性"),
                badge: "SIP & SecStaticCode",
                value: coordinator.tr(fr: "Protégé", en: "Protected", es: "Protegido", de: "Geschützt", ja: "保護済み", zh: "已受保护"),
                subtitle: coordinator.tr(fr: "SIP, Gatekeeper & XProtect vérifiés", en: "SIP, Gatekeeper & XProtect verified", es: "SIP, Gatekeeper y XProtect verificados", de: "SIP, Gatekeeper & XProtect geprüft", ja: "SIP・Gatekeeper検証済み", zh: "SIP、Gatekeeper 与 XProtect 已验证"),
                icon: "checkmark.shield.fill",
                palette: MacCareTheme.auroraPalette(for: .protection),
                actionLabel: coordinator.tr(fr: "Vérifier", en: "Audit", es: "Verificar", de: "Prüfen", ja: "監査", zh: "核查")
            ) {
                coordinator.selectedModule = .protection
            }

            smartCareBentoTile(
                title: coordinator.tr(fr: "Performances & RAM", en: "Performance & RAM", es: "Rendimiento y RAM", de: "Leistung & RAM", ja: "パフォーマンスとRAM", zh: "性能与内存"),
                badge: "Mach \(snap.memoryPressure.rawValue)",
                value: String(format: "CPU %.1f %%", snap.cpuLoadPercentage),
                subtitle: "Active : \(MacCareFormatters.formatBytes(snap.activeMemoryBytes))",
                icon: "gauge.with.dots.needle.67percent",
                palette: MacCareTheme.auroraPalette(for: .performance),
                actionLabel: coordinator.tr(fr: "Moniteur", en: "Monitor", es: "Monitor", de: "Monitor", ja: "モニター", zh: "监控")
            ) {
                coordinator.selectedModule = .performance
            }

            smartCareBentoTile(
                title: coordinator.tr(fr: "Stockage & Doublons", en: "Storage & Duplicates", es: "Espacio y Duplicados", de: "Speicher & Duplikate", ja: "ストレージと重複", zh: "存储与重复文件"),
                badge: "Space Lens",
                value: MacCareFormatters.formatBytes(snap.availableDiskBytes),
                subtitle: "\(coordinator.tr(fr: "Libres sur", en: "Free of", es: "Libres de", de: "Frei von", ja: "空き /", zh: "可用 / 共")) \(MacCareFormatters.formatBytes(snap.totalDiskBytes))",
                icon: "circle.hexagongrid.fill",
                palette: MacCareTheme.auroraPalette(for: .storageAnalyzer),
                actionLabel: coordinator.tr(fr: "Explorer", en: "Explore", es: "Explorar", de: "Erkunden", ja: "探索", zh: "探索")
            ) {
                coordinator.selectedModule = .storageAnalyzer
            }
        }
    }

    private func smartCareBentoTile(
        title: String,
        badge: String,
        value: String,
        subtitle: String,
        icon: String,
        palette: (primary: Color, secondary: Color),
        actionLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [palette.primary, palette.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Spacer()

                Text(badge)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(palette.primary.opacity(0.16), in: Capsule())
                    .foregroundStyle(palette.primary)
            }

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()

            HStack {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button(actionLabel, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(MacCareTheme.cardBackground(for: colorScheme))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(MacCareTheme.cardBorder(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Graphique Swift Charts : Télémétrie Mémoire Mach

    private struct MemorySlice: Identifiable {
        var id: String { label }
        let label: String
        let megabytes: Double
    }

    private func machTelemetryChartCard(snap: SystemSnapshot) -> some View {
        let slices: [MemorySlice] = [
            MemorySlice(label: "Active", megabytes: Double(snap.activeMemoryBytes) / 1_048_576.0),
            MemorySlice(label: "Résidente (Wired)", megabytes: Double(snap.wiredMemoryBytes) / 1_048_576.0),
            MemorySlice(label: "Compressée", megabytes: Double(snap.compressedMemoryBytes) / 1_048_576.0),
            MemorySlice(label: "Inactive", megabytes: Double(snap.inactiveMemoryBytes) / 1_048_576.0),
            MemorySlice(label: "Libre", megabytes: Double(snap.freeMemoryBytes) / 1_048_576.0)
        ]

        return VStack(alignment: .leading, spacing: 12) {
            Text("Distribution Mémoire Noyau Mach (`host_statistics64`)")
                .font(.headline)

            Chart(slices) { slice in
                BarMark(
                    x: .value("Mo", slice.megabytes),
                    y: .value("Segment", slice.label)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [MacCareTheme.accentPurple, MacCareTheme.accentPrimary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }
            .chartXAxisLabel("Mégaoctets (Mo)")
            .frame(height: 170)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(MacCareTheme.cardBackground(for: colorScheme))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(MacCareTheme.cardBorder(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Graphique Swift Charts : Répartition par catégorie

    private func categoryChartCard(summary: AnalysisSummary) -> some View {
        let nonZeroCategories = ScanCategory.allCases.filter { (summary.bytesByCategory[$0] ?? 0) > 0 }
        return VStack(alignment: .leading, spacing: 12) {
            Text("Répartition par catégorie d'analyse")
                .font(.headline)

            if nonZeroCategories.isEmpty {
                ContentUnavailableView(
                    "Aucun élément analysé",
                    systemImage: "magnifyingglass",
                    description: Text("Cliquez sur Analyser en bas au centre pour cartographier votre Mac.")
                )
                .frame(height: 170)
            } else {
                Chart(nonZeroCategories) { category in
                    let bytes = summary.bytesByCategory[category] ?? 0
                    BarMark(
                        x: .value("Mo", Double(bytes) / 1_048_576.0),
                        y: .value("Catégorie", category.rawValue)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [MacCareTheme.accentSecondary, MacCareTheme.accentPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                }
                .chartXAxisLabel("Mégaoctets (Mo)")
                .frame(height: 170)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(MacCareTheme.cardBackground(for: colorScheme))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(MacCareTheme.cardBorder(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Recommandations Smart Care

    private var recommendationsCard: some View {
        let recs = coordinator.recommendations
        return VStack(alignment: .leading, spacing: 12) {
            Text("Recommandations de l'Assistant")
                .font(.headline)

            if recs.isEmpty {
                Text("Aucune action requise : votre système est propre.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recs) { rec in
                    HStack(alignment: .top, spacing: 10) {
                        SafetyBadgeView(level: rec.safetyLevel)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(rec.title)
                                .font(.subheadline.weight(.semibold))
                            Text(rec.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Examiner") {
                            coordinator.selectedModule = rec.targetModule
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(MacCareTheme.cardBackground(for: colorScheme))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(MacCareTheme.cardBorder(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Principaux candidats détectés

    private var topCandidatesCard: some View {
        let topFive = Array(coordinator.candidates.prefix(5))
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Principaux éléments inspectés")
                    .font(.headline)
                Spacer()
                Button("Examiner les détails →") {
                    coordinator.selectedModule = .systemJunk
                }
                .buttonStyle(.link)
                .font(.caption.weight(.semibold))
            }

            ForEach(topFive) { candidate in
                HStack(spacing: 10) {
                    SafetyBadgeView(level: candidate.safetyLevel)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(candidate.displayName)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        Text(candidate.path)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(MacCareFormatters.formatBytes(candidate.sizeBytes))
                        .font(.caption.weight(.bold))
                        .monospacedDigit()

                    if candidate.safetyLevel != .protected {
                        Button("Sélectionner") {
                            var item = candidate
                            item.isSelected = true
                            coordinator.stagingQueue.addOrUpdate(item)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 3)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(MacCareTheme.cardBackground(for: colorScheme))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(MacCareTheme.cardBorder(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Historique SQLite des sessions d'analyse

    private var recentSessionsCard: some View {
        let sessions = Array(coordinator.recentScanSessions.prefix(5))
        return VStack(alignment: .leading, spacing: 10) {
            Text("Historique des analyses récentes (SQLite `scan_sessions`)")
                .font(.headline)

            if sessions.isEmpty {
                Text("Aucune session enregistrée.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sessions) { session in
                    HStack {
                        Label(session.module, systemImage: "clock.arrow.circlepath")
                            .font(.caption.weight(.semibold))
                        Text("• \(session.candidatesCount) éléments")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Récupérable : \(MacCareFormatters.formatBytes(session.reclaimableBytes))")
                            .font(.caption.weight(.medium))
                            .monospacedDigit()
                        Text(String(format: "%.0f ms", session.durationMilliseconds))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 65, alignment: .trailing)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(MacCareTheme.cardBackground(for: colorScheme))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(MacCareTheme.cardBorder(for: colorScheme), lineWidth: 1)
        )
    }
}
