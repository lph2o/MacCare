import SwiftUI

/// Module 08 — Maintenance : Catalogue transparent des opérations de maintenance macOS.
/// Affiche systématiquement la ligne de commande exacte avant exécution et journalise la sortie dans SQLite.
public struct MaintenanceView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable public var coordinator: NavigationCoordinator

    public init(coordinator: NavigationCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ModuleHeaderView(module: .maintenance)

            ForEach(MaintenanceRunnerService.catalog) { spec in
                operationCard(spec)
            }
        }
    }

    private func operationCard(_ spec: MaintenanceOperationSpec) -> some View {
        let lastResult = coordinator.maintenanceResults[spec.id]

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(spec.title)
                        .font(.headline)
                    Text(spec.explanation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                SafetyBadgeView(level: spec.safetyLevel)
                Button {
                    Task {
                        await coordinator.executeMaintenanceOperation(spec)
                    }
                } label: {
                    Label("Exécuter", systemImage: "terminal.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(MacCareTheme.accentPrimary)
                .disabled(coordinator.isRunningMaintenance)
            }

            HStack(spacing: 12) {
                Text("Commande exacte : \(spec.commandLinePreview)")
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                    .textSelection(.enabled)

                Text("Impact : \(spec.impactDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let lastResult {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label(
                            lastResult.succeeded ? "Sortie journalisée (Code 0)" : "Erreur (Code \(lastResult.exitCode))",
                            systemImage: lastResult.succeeded ? "checkmark.circle.fill" : "xmark.octagon.fill"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(lastResult.succeeded ? MacCareTheme.statusSafe : MacCareTheme.statusProtected)

                        Spacer()

                        Text(String(format: "%.0f ms", lastResult.durationMilliseconds))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }

                    Text(lastResult.outputText)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                        .textSelection(.enabled)
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
}
