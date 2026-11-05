import AppKit
import SwiftUI

/// Module 09 — Protection : Audit défensif de la posture de sécurité macOS (SIP, XProtect, Gatekeeper),
/// vérification cryptographique `SecStaticCode` des `LaunchAgents`, inspection des fichiers en quarantaine (`com.apple.quarantine`)
/// et gestion des règles d'exclusion utilisateur dans SQLite.
public struct ProtectionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable public var coordinator: NavigationCoordinator
    @State private var newExclusionPath: String = ""
    @State private var newExclusionNote: String = ""

    public init(coordinator: NavigationCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        let report = coordinator.securityPostureReport
        VStack(alignment: .leading, spacing: 18) {
            ModuleHeaderView(
                module: .protection,
                primaryActionTitle: "Lancer l'audit de sécurité"
            ) {
                coordinator.refreshSecurityPosture()
            }

            postureMetricsGrid(report: report)

            exclusionEditorCard

            if let report {
                HStack(alignment: .top, spacing: 16) {
                    signaturesAuditCard(report.auditedStartupSignatures)
                    quarantinedFilesCard(report.quarantinedFiles)
                }
            }
        }
        .onAppear {
            if coordinator.securityPostureReport == nil {
                coordinator.refreshSecurityPosture()
            }
        }
    }

    private func postureMetricsGrid(report: SecurityPostureReport?) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
            MetricCardView(
                title: "Protection SIP & /System",
                primaryValue: (report?.sipRootReadOnlyVerified ?? true) ? "Actif & Verrouillé" : "À vérifier",
                subtitle: "Volume racine macOS en lecture seule",
                systemImage: "lock.shield.fill",
                accentColor: MacCareTheme.statusSafe
            )
            MetricCardView(
                title: "XProtect & Gatekeeper",
                primaryValue: ((report?.xprotectBundlePresent ?? true) && (report?.gatekeeperDatabasePresent ?? true)) ? "Opérationnels" : "Partiel",
                subtitle: "Signatures antimalware Apple & SystemPolicy",
                systemImage: "checkmark.shield.fill",
                accentColor: MacCareTheme.accentPrimary
            )
            MetricCardView(
                title: "Signatures LaunchAgents",
                primaryValue: "\(report?.auditedStartupSignatures.count ?? 0) audité(s)",
                subtitle: "Vérifiés via Security.framework (SecStaticCode)",
                systemImage: "signature",
                accentColor: MacCareTheme.accentSecondary
            )
            MetricCardView(
                title: "Exclusions SafetyEngine",
                primaryValue: "\(coordinator.exclusionRules.count) règle(s)",
                subtitle: "Persistées dans SQLite (WAL)",
                systemImage: "hand.raised.shield.fill",
                accentColor: MacCareTheme.statusConditional
            )
        }
    }

    private func signaturesAuditCard(_ items: [CodeSignatureAuditItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Audit cryptographique `SecStaticCode` des agents de démarrage")
                .font(.headline)

            if items.isEmpty {
                Text("Aucun agent audité.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items.prefix(12)) { item in
                    HStack(spacing: 10) {
                        SafetyBadgeView(level: item.safetyLevel)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.label)
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                            Text("\(item.status.rawValue) • \(item.signingIdentifier ?? item.targetPath)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MacCareTheme.cardBackground(for: colorScheme))
        )
    }

    private func quarantinedFilesCard(_ files: [QuarantinedFileItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Fichiers en quarantaine (`com.apple.quarantine` via `getxattr`)")
                .font(.headline)

            if files.isEmpty {
                Text("Aucun fichier porteur de l'attribut de quarantaine dans Téléchargements.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(files.prefix(12)) { file in
                    HStack(spacing: 10) {
                        SafetyBadgeView(level: file.safetyLevel)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.name)
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                            Text("Source : \(file.agentName) • \(MacCareFormatters.formatBytes(file.sizeBytes))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Finder") {
                            NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MacCareTheme.cardBackground(for: colorScheme))
        )
    }

    private var exclusionEditorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Règles d'exclusion personnalisées (`SafetyEngine` + SQLite)")
                .font(.headline)

            HStack(spacing: 10) {
                TextField("Chemin absolu à protéger (ex: /Users/alpha/Projets)", text: $newExclusionPath)
                    .textFieldStyle(.roundedBorder)
                TextField("Note (optionnel)", text: $newExclusionNote)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                Button("Protéger ce chemin") {
                    let path = newExclusionPath
                    let note = newExclusionNote
                    newExclusionPath = ""
                    newExclusionNote = ""
                    Task {
                        await coordinator.addExclusionRule(
                            pathOrPattern: path,
                            ruleType: .exactPath,
                            note: note
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(MacCareTheme.accentPrimary)
                .disabled(newExclusionPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ForEach(coordinator.exclusionRules) { rule in
                HStack {
                    SafetyBadgeView(level: .protected)
                    Text(rule.pathOrPattern)
                        .font(.system(.caption, design: .monospaced))
                    if !rule.note.isEmpty {
                        Text("— \(rule.note)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(role: .destructive) {
                        Task {
                            await coordinator.deleteExclusionRule(id: rule.id)
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MacCareTheme.cardBackground(for: colorScheme))
        )
    }
}
