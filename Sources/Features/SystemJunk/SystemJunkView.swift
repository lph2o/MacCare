import AppKit
import SwiftUI

/// Module 02 — System Junk :
/// - Scène d'introduction Hero
/// - Vue Maître-Détail à 2 colonnes avec sous-catégories à gauche et éléments à droite
/// - Garde `ActiveProcessGuard` et restauration directe depuis le journal SQLite.
public struct SystemJunkView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable public var coordinator: NavigationCoordinator
    @State private var selectedCategoryFilter: ScanCategory?
    @State private var showIntroHero: Bool = false

    public init(coordinator: NavigationCoordinator) {
        self.coordinator = coordinator
    }

    private var filteredCandidates: [ScanCandidate] {
        guard let filter = selectedCategoryFilter else {
            return coordinator.candidates
        }
        return coordinator.candidates.filter { $0.category == filter }
    }

    private var restorableLogs: [AuditLogEntry] {
        coordinator.recentAuditLogs.filter { entry in
            guard entry.status == "SUCCESS",
                  entry.actionMode == .moveToTrash,
                  let trashPath = entry.destinationPath else {
                return false
            }
            return FileManager.default.fileExists(atPath: trashPath)
        }
    }

    public var body: some View {
        let summary = AnalysisSummary(candidates: coordinator.candidates)

        VStack(alignment: .leading, spacing: 20) {
            ModuleHeaderView(
                module: .systemJunk,
                primaryActionTitle: coordinator.isScanning ? "Scan en cours…" : "Relancer l'analyse"
            ) {
                Task {
                    await coordinator.performSystemJunkScan()
                }
            }

            if showIntroHero || coordinator.candidates.isEmpty {
                ModuleIntroHeroView(
                    module: .systemJunk,
                    isScanning: coordinator.isScanning,
                    statusText: coordinator.isScanning ? "Inspection de ~/Library/Caches et Logs…" : "Prêt à nettoyer",
                    extraActionTitle: coordinator.candidates.isEmpty ? nil : "Examiner les résultats (\(coordinator.candidates.count))"
                ) {
                    showIntroHero = false
                }
            } else {
                summaryBanner(summary: summary)

                if !restorableLogs.isEmpty {
                    restorationCard
                }

                // Disposition Maître-Détail à 2 colonnes
                HStack(alignment: .top, spacing: 18) {
                    categoryMasterSidebar(summary: summary)
                        .frame(width: 265)

                    VStack(spacing: 10) {
                        ForEach(filteredCandidates) { candidate in
                            candidateCard(candidate)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Colonne gauche `DataManagerUI` (Catégories de nettoyage avec tailles agrégées)

    private func categoryMasterSidebar(summary: AnalysisSummary) -> some View {
        let palette = MacCareTheme.auroraPalette(for: .systemJunk)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Catégories de fichiers")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)

            categorySidebarRow(
                title: "Tous les fichiers inutiles",
                icon: "sparkles",
                count: coordinator.candidates.count,
                bytes: summary.totalReclaimableBytes,
                isSelected: selectedCategoryFilter == nil,
                accentColor: palette.primary
            ) {
                selectedCategoryFilter = nil
            }

            Divider().opacity(0.3)

            ForEach(ScanCategory.allCases) { category in
                let items = coordinator.candidates.filter { $0.category == category }
                if !items.isEmpty {
                    let bytes = items.reduce(Int64(0)) { $0 + $1.sizeBytes }
                    categorySidebarRow(
                        title: category.rawValue,
                        icon: iconForCategory(category),
                        count: items.count,
                        bytes: bytes,
                        isSelected: selectedCategoryFilter == category,
                        accentColor: palette.primary
                    ) {
                        selectedCategoryFilter = category
                    }
                }
            }

            Divider().opacity(0.3)

            Button {
                showIntroHero = true
            } label: {
                Label("Voir la présentation du module", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.top, 4)
        }
        .padding(14)
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

    private func categorySidebarRow(
        title: String,
        icon: String,
        count: Int,
        bytes: Int64,
        isSelected: Bool,
        accentColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : accentColor)
                    .frame(width: 26, height: 26)
                    .background(
                        isSelected ? accentColor : accentColor.opacity(0.15),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text("\(count) élément(s)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(MacCareFormatters.formatBytes(bytes))
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                isSelected ? accentColor.opacity(0.18) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private func iconForCategory(_ category: ScanCategory) -> String {
        switch category {
        case .userCaches: return "internaldrive.fill"
        case .systemAndUserLogs: return "doc.text.fill"
        case .temporaryFiles: return "clock.badge.xmark.fill"
        case .xcodeDeveloperArtifacts: return "hammer.fill"
        case .packageManagerCaches: return "shippingbox.fill"
        case .trashItems: return "trash.fill"
        case .largeFiles: return "externaldrive.fill"
        case .duplicateFiles: return "doc.on.doc.fill"
        case .applicationBundles: return "app.badge.checkmark.fill"
        case .applicationLeftovers: return "puzzlepiece.extension.fill"
        case .startupItems: return "power.circle.fill"
        }
    }

    // MARK: - Bandeau de synthèse & Restauration

    private func summaryBanner(summary: AnalysisSummary) -> some View {
        let palette = MacCareTheme.auroraPalette(for: .systemJunk)

        return HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Nettoyage terminé : \(MacCareFormatters.formatBytes(summary.totalReclaimableBytes)) détectés")
                    .font(.title3.weight(.bold))
                Text("Sûr (auto-sélectionnable) : \(MacCareFormatters.formatBytes(summary.safeBytes)) • Conditionnel : \(MacCareFormatters.formatBytes(summary.conditionalBytes)) • Protégé : \(MacCareFormatters.formatBytes(summary.protectedBytes))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            if summary.safeBytes > 0 {
                Button {
                    coordinator.stageAllSafeCandidates()
                } label: {
                    Label("Sélectionner tous les éléments Sûrs (\(MacCareFormatters.formatBytes(summary.safeBytes)))", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [palette.primary, palette.secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(MacCareTheme.cardBackground(for: colorScheme))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(palette.primary.opacity(0.32), lineWidth: 1)
        )
    }

    private var restorationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Éléments récemment mis à la Corbeille (Restauration en 1 clic via SQLite)", systemImage: "arrow.uturn.backward.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MacCareTheme.accentPrimary)

            ForEach(restorableLogs.prefix(5)) { entry in
                HStack {
                    Text(entry.originalPath)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                    Spacer()
                    Text(MacCareFormatters.formatBytes(entry.bytesFreed))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Button("Restaurer à l'emplacement d'origine") {
                        Task {
                            await coordinator.restoreAuditEntry(entry)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
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
                .strokeBorder(MacCareTheme.accentPrimary.opacity(0.35), lineWidth: 1)
        )
    }

    private func candidateCard(_ candidate: ScanCandidate) -> some View {
        let isStaged = coordinator.stagingQueue.items.contains { $0.path == candidate.path && $0.isSelected }

        return HStack(alignment: .top, spacing: 12) {
            if candidate.safetyLevel != .protected {
                Button {
                    var item = candidate
                    item.isSelected = !isStaged
                    coordinator.stagingQueue.addOrUpdate(item)
                } label: {
                    Image(systemName: isStaged ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isStaged ? MacCareTheme.accentSecondary : .secondary)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "lock.fill")
                    .font(.headline)
                    .foregroundStyle(MacCareTheme.statusProtected)
                    .frame(width: 22)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(candidate.displayName)
                        .font(.headline)
                    SafetyBadgeView(level: candidate.safetyLevel)
                    Text(candidate.category.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.14), in: Capsule())
                }

                Text(candidate.path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                Text("\(candidate.explanation) • Impact : \(candidate.potentialImpact)")
                    .font(.caption)
                    .foregroundStyle(MacCareTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text(MacCareFormatters.formatBytes(candidate.sizeBytes))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .monospacedDigit()

                HStack(spacing: 8) {
                    Button("Finder") {
                        NSWorkspace.shared.selectFile(candidate.path, inFileViewerRootedAtPath: "")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Ignorer") {
                        Task {
                            await coordinator.addExclusionRule(
                                pathOrPattern: candidate.path,
                                ruleType: .exactPath,
                                note: "Ignoré depuis System Junk"
                            )
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MacCareTheme.cardBackground(for: colorScheme))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isStaged ? MacCareTheme.accentSecondary.opacity(0.55) : MacCareTheme.cardBorder(for: colorScheme), lineWidth: 1)
        )
    }
}
