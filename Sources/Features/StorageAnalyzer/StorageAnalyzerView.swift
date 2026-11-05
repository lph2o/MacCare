import AppKit
import Charts
import SwiftUI

/// Module 03 — Storage Analyzer : Cartographie hiérarchique interactive (`StorageNode` + `Swift Charts`)
/// et explorateur des Fichiers Volumineux & Anciens (`LargeFileItem`) avec filtres par taille, ancienneté et `UTType`.
public struct StorageAnalyzerView: View {
    public enum AnalyzerTab: String, CaseIterable, Identifiable {
        case folderMap = "Cartographie des Dossiers"
        case largeAndOldFiles = "Fichiers Volumineux & Anciens"

        public var id: String { rawValue }
    }

    public enum SizeFilterOption: Int64, CaseIterable, Identifiable {
        case over1MB = 1_048_576
        case over50MB = 52_428_800
        case over250MB = 262_144_000
        case over1GB = 1_073_741_824

        public var id: Int64 { rawValue }

        public var label: String {
            switch self {
            case .over1MB: return "> 1 Mo"
            case .over50MB: return "> 50 Mo"
            case .over250MB: return "> 250 Mo"
            case .over1GB: return "> 1 Go"
            }
        }
    }

    public enum AgeFilterOption: Int, CaseIterable, Identifiable {
        case all = 0
        case over30Days = 30
        case over90Days = 90
        case over365Days = 365

        public var id: Int { rawValue }

        public var label: String {
            switch self {
            case .all: return "Toutes dates"
            case .over30Days: return "> 30 jours"
            case .over90Days: return "> 90 jours"
            case .over365Days: return "> 1 an"
            }
        }
    }

    @Environment(\.colorScheme) private var colorScheme
    @Bindable public var coordinator: NavigationCoordinator

    @State private var selectedTab: AnalyzerTab = .folderMap
    @State private var targetDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
    @State private var navigationStack: [StorageNode] = []
    @State private var sizeFilter: SizeFilterOption = .over1MB
    @State private var ageFilter: AgeFilterOption = .all
    @State private var kindFilter: StorageFileKind?

    public init(coordinator: NavigationCoordinator) {
        self.coordinator = coordinator
    }

    private var currentNode: StorageNode? {
        navigationStack.last ?? coordinator.storageScanReport?.rootNode
    }

    private var filteredLargeFiles: [LargeFileItem] {
        guard let report = coordinator.storageScanReport else { return [] }
        let now = Date()
        return report.largeFiles.filter { item in
            guard item.allocatedBytes >= sizeFilter.rawValue else { return false }
            if ageFilter.rawValue > 0 && item.ageInDays(referenceDate: now) < ageFilter.rawValue {
                return false
            }
            if let kindFilter, item.kind != kindFilter {
                return false
            }
            return true
        }
    }

    public var body: some View {
        let snap = coordinator.systemSnapshot
        VStack(alignment: .leading, spacing: 18) {
            headerSection

            StorageBarView(snapshot: snap)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(MacCareTheme.cardBackground(for: colorScheme))
                )

            Picker("Mode d'affichage", selection: $selectedTab) {
                ForEach(AnalyzerTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            if let report = coordinator.storageScanReport {
                scanStatsStrip(report: report)
                switch selectedTab {
                case .folderMap:
                    folderMapSection(report: report)
                case .largeAndOldFiles:
                    largeFilesSection
                }
            } else {
                emptyScanCard
            }
        }
    }

    // MARK: - En-tête et contrôles de scan / annulation

    private var headerSection: some View {
        HStack(spacing: 12) {
            ModuleHeaderView(module: .storageAnalyzer)

            if coordinator.isAnalyzingStorage {
                ProgressView()
                    .controlSize(.small)
                Button("Annuler le scan") {
                    coordinator.cancelStorageAnalysis()
                }
                .buttonStyle(.bordered)
                .tint(MacCareTheme.statusProtected)
            } else {
                Button("Choisir un dossier…") {
                    if let chosen = coordinator.permissionsManager.requestDirectoryAccess() {
                        targetDirectoryURL = chosen
                        navigationStack.removeAll()
                        coordinator.runStorageAnalysis(at: chosen)
                    }
                }
                .buttonStyle(.bordered)

                Button {
                    navigationStack.removeAll()
                    coordinator.runStorageAnalysis(at: targetDirectoryURL)
                } label: {
                    Label("Analyser maintenant", systemImage: "magnifyingglass")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(MacCareTheme.accentPrimary)
            }
        }
    }

    private func scanStatsStrip(report: StorageScanReport) -> some View {
        HStack(spacing: 18) {
            Label("Racine : \(report.rootNode.path)", systemImage: "folder.fill")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Spacer()
            Text("\(report.scannedFilesCount) fichiers • Taille physique APFS : \(MacCareFormatters.formatBytes(report.rootNode.allocatedBytes))")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            if report.skippedCloudPlaceholdersCount > 0 {
                Text("\(report.skippedCloudPlaceholdersCount) fichier(s) iCloud non téléchargé(s) ignoré(s)")
                    .font(.caption2)
                    .foregroundStyle(MacCareTheme.accentSecondary)
            }
            Text(String(format: "%.0f ms", report.durationMilliseconds))
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(MacCareTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Onglet 1 : Cartographie hiérarchique des dossiers

    private func folderMapSection(report: StorageScanReport) -> some View {
        let activeNode = currentNode ?? report.rootNode
        let topChildren = Array(activeNode.children.prefix(10))

        return VStack(alignment: .leading, spacing: 16) {
            breadcrumbBar(rootNode: report.rootNode)

            if !topChildren.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Répartition proportionnelle de « \(activeNode.name) » (\(MacCareFormatters.formatBytes(activeNode.allocatedBytes)))")
                        .font(.headline)

                    Chart(topChildren) { child in
                        BarMark(
                            x: .value("Mo", Double(child.allocatedBytes) / 1_048_576.0),
                            y: .value("Élément", child.name)
                        )
                        .foregroundStyle(child.isDirectory ? MacCareTheme.accentSecondary : MacCareTheme.accentPrimary)
                    }
                    .chartXAxisLabel("Mégaoctets physiques alloués (Mo)")
                    .frame(height: min(260, CGFloat(max(120, topChildren.count * 26))))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(MacCareTheme.cardBackground(for: colorScheme))
                )
            }

            VStack(spacing: 8) {
                ForEach(activeNode.children) { node in
                    storageNodeRow(node: node, parentBytes: max(1, activeNode.allocatedBytes))
                }
            }
        }
    }

    private func breadcrumbBar(rootNode: StorageNode) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Button {
                    navigationStack.removeAll()
                } label: {
                    Label(rootNode.name, systemImage: "house.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                ForEach(Array(navigationStack.enumerated()), id: \.element.id) { index, node in
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Button(node.name) {
                        navigationStack = Array(navigationStack.prefix(index + 1))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private func storageNodeRow(node: StorageNode, parentBytes: Int64) -> some View {
        let ratio = Double(node.allocatedBytes) / Double(max(1, parentBytes))
        return HStack(spacing: 12) {
            Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundStyle(node.isDirectory ? MacCareTheme.accentSecondary : MacCareTheme.accentPrimary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(node.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(String(format: "%.1f %%", ratio * 100.0))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Text(node.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            SafetyBadgeView(level: node.safetyLevel)

            Text(MacCareFormatters.formatBytes(node.allocatedBytes))
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .frame(width: 90, alignment: .trailing)

            if node.isDirectory && !node.children.isEmpty {
                Button("Explorer") {
                    navigationStack.append(node)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Button("Finder") {
                NSWorkspace.shared.selectFile(node.path, inFileViewerRootedAtPath: "")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if node.safetyLevel != .protected {
                Button {
                    let candidate = ScanCandidate(
                        path: node.path,
                        displayName: node.name,
                        category: .largeFiles,
                        sizeBytes: node.allocatedBytes,
                        lastModified: node.lastModified,
                        safetyLevel: node.safetyLevel,
                        explanation: node.safetyReason,
                        potentialImpact: "Déplacement réversible vers la Corbeille macOS.",
                        isSelected: true
                    )
                    coordinator.stagingQueue.addOrUpdate(candidate)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(MacCareTheme.accentPrimary)
                }
                .buttonStyle(.plain)
                .help("Ajouter au panier de préparation")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MacCareTheme.cardBackground(for: colorScheme))
        )
    }

    // MARK: - Onglet 2 : Fichiers Volumineux & Anciens

    private var largeFilesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Picker("Taille minimale", selection: $sizeFilter) {
                    ForEach(SizeFilterOption.allCases) { opt in
                        Text(opt.label).tag(opt)
                    }
                }
                .frame(width: 210)

                Picker("Ancienneté", selection: $ageFilter) {
                    ForEach(AgeFilterOption.allCases) { opt in
                        Text(opt.label).tag(opt)
                    }
                }
                .frame(width: 210)

                Picker("Type UTType", selection: $kindFilter) {
                    Text("Tous les types").tag(StorageFileKind?.none)
                    ForEach(StorageFileKind.allCases) { kind in
                        Text(kind.rawValue).tag(StorageFileKind?.some(kind))
                    }
                }
                .frame(width: 240)

                Spacer()

                Text("\(filteredLargeFiles.count) fichier(s)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            if filteredLargeFiles.isEmpty {
                ContentUnavailableView(
                    "Aucun fichier ne correspond aux filtres",
                    systemImage: "doc.magnifyingglass",
                    description: Text("Réduisez le seuil de taille ou d'ancienneté pour afficher davantage d'éléments.")
                )
                .frame(height: 200)
            } else {
                ForEach(filteredLargeFiles) { item in
                    largeFileRow(item)
                }
            }
        }
    }

    private func largeFileRow(_ item: LargeFileItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.kind.systemImage)
                .foregroundStyle(MacCareTheme.accentPrimary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(.subheadline.weight(.semibold))
                    Text(item.kind.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.14), in: Capsule())
                    Text("Il y a \(item.ageInDays()) j")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Text(item.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            SafetyBadgeView(level: item.safetyLevel)

            Text(MacCareFormatters.formatBytes(item.allocatedBytes))
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .frame(width: 90, alignment: .trailing)

            Button("Finder") {
                NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if item.safetyLevel != .protected {
                Button("Ajouter au panier") {
                    let candidate = ScanCandidate(
                        path: item.path,
                        displayName: item.name,
                        category: .largeFiles,
                        sizeBytes: item.allocatedBytes,
                        lastModified: item.lastAccessedOrModified,
                        safetyLevel: item.safetyLevel,
                        explanation: item.safetyReason,
                        potentialImpact: "Déplacement réversible vers la Corbeille macOS.",
                        isSelected: true
                    )
                    coordinator.stagingQueue.addOrUpdate(candidate)
                }
                .buttonStyle(.borderedProminent)
                .tint(MacCareTheme.accentPrimary)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MacCareTheme.cardBackground(for: colorScheme))
        )
    }

    private var emptyScanCard: some View {
        ModuleIntroHeroView(
            module: .storageAnalyzer,
            isScanning: coordinator.isAnalyzingStorage,
            statusText: coordinator.isAnalyzingStorage ? "Exploration APFS Space Lens en cours…" : "Prêt pour Space Lens",
            extraActionTitle: "Choisir un dossier spécifique…"
        ) {
            if let chosen = coordinator.permissionsManager.requestDirectoryAccess() {
                targetDirectoryURL = chosen
                navigationStack.removeAll()
                coordinator.runStorageAnalysis(at: chosen)
            }
        }
    }
}
