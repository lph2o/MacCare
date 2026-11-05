import AppKit
import SwiftUI

/// Module 05 — Duplicate Finder : Pipeline déterministe en 3 passes (Taille -> Pré-empreinte 64 Ko -> `CryptoKit.SHA256`)
/// avec verrouillage obligatoire d'au moins un exemplaire original par groupe.
public struct DuplicateFinderView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable public var coordinator: NavigationCoordinator
    @State private var selectedDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")

    public init(coordinator: NavigationCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                ModuleHeaderView(module: .duplicateFinder)

                Button("Choisir un dossier…") {
                    if let url = coordinator.permissionsManager.requestDirectoryAccess(
                        message: "Sélectionnez un dossier à analyser avec le détecteur SHA-256 en 3 passes"
                    ) {
                        selectedDirectoryURL = url
                        Task {
                            await coordinator.performDuplicateScan(in: url, autoSelectRedundant: true)
                        }
                    }
                }
                .buttonStyle(.bordered)

                Button {
                    Task {
                        await coordinator.performDuplicateScan(in: selectedDirectoryURL, autoSelectRedundant: true)
                    }
                } label: {
                    Label(
                        coordinator.isDetectingDuplicates ? "Hachage SHA-256…" : "Analyser les doublons",
                        systemImage: "doc.on.doc.fill"
                    )
                    .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(MacCareTheme.accentPrimary)
                .disabled(coordinator.isDetectingDuplicates)
            }

            pipelineExplanationBanner

            if let report = coordinator.duplicateScanReport {
                passStatsCard(report: report)
                groupsListSection(report: report)
            } else {
                ModuleIntroHeroView(
                    module: .duplicateFinder,
                    isScanning: coordinator.isDetectingDuplicates,
                    statusText: coordinator.isDetectingDuplicates ? "Hachage SHA-256 en 3 passes…" : "Dossier cible : \(selectedDirectoryURL.lastPathComponent)",
                    extraActionTitle: "Choisir un autre dossier…"
                ) {
                    if let url = coordinator.permissionsManager.requestDirectoryAccess(
                        message: "Sélectionnez un dossier à analyser avec le détecteur SHA-256 en 3 passes"
                    ) {
                        selectedDirectoryURL = url
                        Task {
                            await coordinator.performDuplicateScan(in: url, autoSelectRedundant: true)
                        }
                    }
                }
            }
        }
    }

    private var pipelineExplanationBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Pipeline de vérification cryptographique en 3 passes (0 faux positif)", systemImage: "lock.doc.fill")
                .font(.headline)
            Text("Passe 1 : Regroupement par taille exacte • Passe 2 : Pré-empreinte 64 Ko (début/fin) • Passe 3 : Empreinte complète SHA-256 (CryptoKit). Dans chaque groupe, l'exemplaire original est verrouillé (Protégé) pour empêcher toute perte de fichier unique.")
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

    private func passStatsCard(report: DuplicateScanReport) -> some View {
        HStack(spacing: 18) {
            Text("Dossier : \(selectedDirectoryURL.path)")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Spacer()
            Text("Inspectés : \(report.totalFilesInspected) → Passe 1 : \(report.pass1SizeCandidatesCount) → Passe 2 : \(report.pass2PartialHashCandidatesCount) → Confirmés SHA-256 : \(report.pass3ConfirmedDuplicatesCount)")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            if !report.groups.isEmpty {
                Button("Ajouter les copies cochées au panier (\(MacCareFormatters.formatBytes(report.totalReclaimableBytes)))") {
                    coordinator.stageSelectedDuplicates()
                }
                .buttonStyle(.borderedProminent)
                .tint(MacCareTheme.accentPrimary)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(MacCareTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 10))
    }

    private func groupsListSection(report: DuplicateScanReport) -> some View {
        VStack(spacing: 12) {
            if report.groups.isEmpty {
                ContentUnavailableView(
                    "Aucun doublon SHA-256 détecté",
                    systemImage: "checkmark.seal.fill",
                    description: Text("Aucun fichier en double n'a été trouvé dans \(selectedDirectoryURL.lastPathComponent).")
                )
                .frame(height: 180)
            } else {
                ForEach(report.groups) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("SHA-256 : \(group.sha256Hex.prefix(16))…", systemImage: "number.square.fill")
                                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                            Spacer()
                            Text("\(group.members.count) exemplaires • \(MacCareFormatters.formatBytes(group.fileSizeBytes)) chacun")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        ForEach(group.members) { member in
                            HStack(spacing: 10) {
                                if member.isLockedOriginal {
                                    SafetyBadgeView(level: .protected)
                                    Text("Original conservé")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(MacCareTheme.statusSafe)
                                } else {
                                    Button {
                                        coordinator.toggleDuplicateSelection(groupId: group.id, memberId: member.id)
                                    } label: {
                                        Image(systemName: member.isSelectedForRemoval ? "checkmark.square.fill" : "square")
                                            .foregroundStyle(member.isSelectedForRemoval ? MacCareTheme.accentPrimary : .secondary)
                                    }
                                    .buttonStyle(.plain)
                                    SafetyBadgeView(level: .conditional)
                                }

                                Text(member.path)
                                    .font(.system(.caption, design: .monospaced))
                                    .lineLimit(1)

                                Spacer()

                                Button("Finder") {
                                    NSWorkspace.shared.selectFile(member.path, inFileViewerRootedAtPath: "")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(MacCareTheme.cardBackground(for: colorScheme))
                    )
                }
            }
        }
    }
}
