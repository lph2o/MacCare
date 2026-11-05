import SwiftUI

/// Fenêtre de Réglages macOS (`⌘,`) permettant d'inspecter la base SQLite, le journal d'audit, la restauration et les permissions.
public struct SettingsView: View {
    @Bindable public var coordinator: NavigationCoordinator

    public init(coordinator: NavigationCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("Général & Sécurité", systemImage: "shield.checkered")
                }

            auditLogTab
                .tabItem {
                    Label("Journal d'audit SQLite & Restauration", systemImage: "list.clipboard")
                }
        }
        .padding(20)
        .frame(width: 720, height: 450)
    }

    private var generalTab: some View {
        Form {
            Section(coordinator.tr(fr: "Langue de l'interface (International)", en: "Interface Language (International)", es: "Idioma de la interfaz", de: "Oberflächensprache", ja: "インターフェース言語", zh: "界面语言")) {
                Picker(coordinator.tr(fr: "Langue / Language", en: "Language", es: "Idioma", de: "Sprache", ja: "言語", zh: "语言"), selection: $coordinator.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text("\(lang.flagEmoji) \(lang.displayName)").tag(lang)
                    }
                }
            }

            Section(coordinator.tr(fr: "Politique d'action par défaut", en: "Default Cleanup Policy", es: "Política de limpieza por defecto", de: "Standard-Bereinigungsrichtlinie", ja: "デフォルトのクリーンアップ動作", zh: "默认清理策略")) {
                Picker(coordinator.tr(fr: "Mode de nettoyage", en: "Cleanup Mode", es: "Modo de limpieza", de: "Bereinigungsmodus", ja: "クリーンアップモード", zh: "清理模式"), selection: $coordinator.stagingQueue.preferredMode) {
                    Text(coordinator.tr(fr: "Déplacer vers la Corbeille macOS (Recommandé)", en: "Move to macOS Trash (Recommended)", es: "Mover a la Papelera de macOS (Recomendado)", de: "In den macOS-Papierkorb bewegen (Empfohlen)", ja: "macOSのゴミ箱へ移動（推奨）", zh: "移至 macOS 废纸篓（推荐）")).tag(FileActionMode.moveToTrash)
                    Text(coordinator.tr(fr: "Suppression directe (Requiert confirmation)", en: "Permanent Delete (Requires confirmation)", es: "Eliminación directa (Requiere confirmación)", de: "Sofort löschen (Bestätigung erforderlich)", ja: "完全に削除（確認が必要）", zh: "直接删除（需确认）")).tag(FileActionMode.permanentDelete)
                }
                Toggle(coordinator.tr(fr: "Afficher le moniteur MacCare dans la barre des menus macOS", en: "Show MacCare monitor in macOS menu bar", es: "Mostrar monitor MacCare en la barra de menús", de: "MacCare-Monitor in der Menüleiste anzeigen", ja: "メニューバーにMacCareモニターを表示", zh: "在 macOS 菜单栏显示 MacCare 监控器"), isOn: $coordinator.showMenuBarExtra)
                Text(coordinator.tr(fr: "Conformément à la charte MacCare, aucune action n'est exécutée sans validation par SafetyEngine, ActiveProcessGuard et confirmation explicite.", en: "In accordance with the MacCare Safety Charter, no action is executed without SafetyEngine, ActiveProcessGuard, and explicit confirmation.", es: "Ninguna acción se ejecuta sin validación por SafetyEngine, ActiveProcessGuard y confirmación explícita.", de: "Keine Aktion wird ohne Prüfung durch SafetyEngine, ActiveProcessGuard und explizite Bestätigung ausgeführt.", ja: "SafetyEngine、ActiveProcessGuard、および明示的な確認なしに操作が実行されることはありません。", zh: "所有清理操作均需通过 SafetyEngine、ActiveProcessGuard 校验并经您明确确认后方可执行。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Permissions macOS (TCC)") {
                HStack {
                    Text(coordinator.tr(fr: "Accès complet au disque :", en: "Full Disk Access:", es: "Acceso total al disco:", de: "Festplattenvollzugriff:", ja: "フルディスクアクセス:", zh: "完全磁盘访问权限:"))
                    Spacer()
                    Text(coordinator.fullDiskAccessStatus.rawValue)
                        .fontWeight(.semibold)
                    Button(coordinator.tr(fr: "Ouvrir Réglages Système…", en: "Open System Settings…", es: "Abrir Ajustes del Sistema…", de: "Systemeinstellungen öffnen…", ja: "システム設定を開く…", zh: "打开系统设置…")) {
                        coordinator.permissionsManager.openFullDiskAccessSettings()
                    }
                }
            }
        }
    }

    private var auditLogTab: some View {
        let logs = coordinator.recentAuditLogs
        return VStack(alignment: .leading, spacing: 10) {
            Text("Historique des opérations enregistrées dans SQLite (`action_logs`)")
                .font(.headline)

            if logs.isEmpty {
                ContentUnavailableView(
                    "Aucune opération exécutée",
                    systemImage: "checkmark.seal",
                    description: Text("Les opérations de nettoyage confirmées apparaîtront ici avec possibilité de restauration depuis la Corbeille.")
                )
            } else {
                List {
                    ForEach(logs) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(entry.module)
                                        .font(.caption.weight(.bold))
                                    Text(entry.status)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(entry.status == "FAILED" ? MacCareTheme.statusProtected : MacCareTheme.statusSafe)
                                    Text(MacCareFormatters.formatBytes(entry.bytesFreed))
                                        .font(.caption)
                                        .monospacedDigit()
                                }
                                Text(entry.originalPath)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let trashPath = entry.destinationPath,
                               entry.status == "SUCCESS",
                               FileManager.default.fileExists(atPath: trashPath) {
                                Button("Restaurer") {
                                    Task {
                                        await coordinator.restoreAuditEntry(entry)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }
        }
    }
}
