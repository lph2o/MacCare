import Foundation
import SwiftUI

/// Les 9 modules fonctionnels officiels de MacCare, enrichis des 3 piliers d'introduction (`introFeatures`).
public enum AppModule: String, CaseIterable, Identifiable, Sendable {
    case smartCare = "smart_care"
    case systemJunk = "system_junk"
    case storageAnalyzer = "storage_analyzer"
    case appManager = "app_manager"
    case duplicateFinder = "duplicate_finder"
    case performance = "performance"
    case startupManager = "startup_manager"
    case maintenance = "maintenance"
    case protection = "protection"

    public struct IntroFeaturePillar: Identifiable, Sendable {
        public var id: String { title }
        public let icon: String
        public let title: String
        public let detail: String

        public init(icon: String, title: String, detail: String) {
            self.icon = icon
            self.title = title
            self.detail = detail
        }
    }

    public var id: String { rawValue }

    public var indexNumber: Int {
        switch self {
        case .smartCare: return 1
        case .systemJunk: return 2
        case .storageAnalyzer: return 3
        case .appManager: return 4
        case .duplicateFinder: return 5
        case .performance: return 6
        case .startupManager: return 7
        case .maintenance: return 8
        case .protection: return 9
        }
    }

    public var title: String {
        switch self {
        case .smartCare: return "Smart Care"
        case .systemJunk: return "System Junk"
        case .storageAnalyzer: return "Storage Analyzer"
        case .appManager: return "App Manager"
        case .duplicateFinder: return "Duplicate Finder"
        case .performance: return "Performance"
        case .startupManager: return "Startup Manager"
        case .maintenance: return "Maintenance"
        case .protection: return "Protection"
        }
    }

    public var subtitle: String {
        switch self {
        case .smartCare:
            return "Analysez votre Mac en profondeur : nettoyage intelligent, sécurité, performances et stockage APFS."
        case .systemJunk:
            return "Libérez de l'espace disque en nettoyant les caches temporaires, journaux et résidus système."
        case .storageAnalyzer:
            return "Explorez visuellement votre disque (Space Lens) et repérez les fichiers volumineux et anciens."
        case .appManager:
            return "Désinstallez proprement vos applications et éliminez les résidus orphelins de ~/Library."
        case .duplicateFinder:
            return "Identifiez avec précision vos fichiers en double grâce à l'empreinte SHA-256 en 3 passes."
        case .performance:
            return "Surveillez la pression mémoire Mach, la charge processeur et les processus gourmands."
        case .startupManager:
            return "Contrôlez les agents d'ouverture de session (LaunchAgents) et réparez les plists brisés."
        case .maintenance:
            return "Exécutez les scripts d'entretien macOS (DNS, QuickLook, Spotlight, snapshots APFS)."
        case .protection:
            return "Vérifiez l'intégrité SIP, Gatekeeper, XProtect, les signatures de code et la quarantaine."
        }
    }

    public var systemImage: String {
        switch self {
        case .smartCare: return "sparkles"
        case .systemJunk: return "trash.circle.fill"
        case .storageAnalyzer: return "circle.hexagongrid.fill"
        case .appManager: return "square.grid.2x2.fill"
        case .duplicateFinder: return "doc.on.doc.fill"
        case .performance: return "gauge.with.dots.needle.67percent"
        case .startupManager: return "bolt.circle.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .protection: return "checkmark.shield.fill"
        }
    }

    public var shortcutKey: KeyEquivalent {
        KeyEquivalent(Character("\(indexNumber)"))
    }

    public var phaseBadge: String {
        switch self {
        case .smartCare: return "01 • Entretien Intelligent"
        case .systemJunk: return "02 • Nettoyage Système"
        case .storageAnalyzer: return "03 • Télescope Disque"
        case .appManager: return "04 • Applications"
        case .duplicateFinder: return "05 • Mes Doublons"
        case .performance: return "06 • Performances"
        case .startupManager: return "07 • Démarrage"
        case .maintenance: return "08 • Boîte à Outils"
        case .protection: return "09 • Protection"
        }
    }

    public var primaryActionLabel: String {
        switch self {
        case .smartCare: return "Analyser"
        case .systemJunk: return "Analyser"
        case .storageAnalyzer: return "Analyser"
        case .appManager: return "Analyser"
        case .duplicateFinder: return "Analyser"
        case .performance: return "Actualiser"
        case .startupManager: return "Analyser"
        case .maintenance: return "Tout vérifier"
        case .protection: return "Analyser"
        }
    }

    public func localizedTitle(in lang: AppLanguage) -> String {
        switch self {
        case .smartCare:
            return L10n.text(lang, fr: "Smart Care", en: "Smart Care", es: "Cuidado Inteligente", de: "Smart Care", ja: "スマートケア", zh: "智能护理")
        case .systemJunk:
            return L10n.text(lang, fr: "System Junk", en: "System Junk", es: "Basura del Sistema", de: "Systemreste", ja: "システムジャンク", zh: "系统垃圾")
        case .storageAnalyzer:
            return L10n.text(lang, fr: "Storage Analyzer", en: "Storage Analyzer", es: "Analizador de Espacio", de: "Speicheranalyse", ja: "ストレージ解析", zh: "存储空间分析")
        case .appManager:
            return L10n.text(lang, fr: "App Manager", en: "App Manager", es: "Gestor de Apps", de: "App-Manager", ja: "アプリ管理", zh: "应用管理")
        case .duplicateFinder:
            return L10n.text(lang, fr: "Duplicate Finder", en: "Duplicate Finder", es: "Buscador de Duplicados", de: "Duplikatfinder", ja: "重複ファインダー", zh: "重复文件查找")
        case .performance:
            return L10n.text(lang, fr: "Performance", en: "Performance", es: "Rendimiento", de: "Leistung", ja: "パフォーマンス", zh: "性能监控")
        case .startupManager:
            return L10n.text(lang, fr: "Startup Manager", en: "Startup Manager", es: "Gestor de Inicio", de: "Autostart", ja: "スタートアップ管理", zh: "启动项管理")
        case .maintenance:
            return L10n.text(lang, fr: "Maintenance", en: "Maintenance", es: "Mantenimiento", de: "Wartung", ja: "メンテナンス", zh: "系统维护")
        case .protection:
            return L10n.text(lang, fr: "Protection", en: "Protection", es: "Protección", de: "Schutz", ja: "プロテクション", zh: "安全防护")
        }
    }

    public func localizedSubtitle(in lang: AppLanguage) -> String {
        switch self {
        case .smartCare:
            return L10n.text(
                lang,
                fr: subtitle,
                en: "Deeply inspect your Mac: smart cleanup, security posture, Mach memory performance, and APFS storage.",
                es: "Analiza tu Mac a fondo: limpieza inteligente, seguridad, rendimiento y almacenamiento APFS.",
                de: "Analysieren Sie Ihren Mac gründlich: intelligente Bereinigung, Sicherheit, Leistung und APFS-Speicher.",
                ja: "Macを徹底診断：スマートクリーンアップ、セキュリティ、Machメモリ性能、APFSストレージを解析します。",
                zh: "全面深度检测您的 Mac：智能清理、安全态势、Mach 内存性能与 APFS 存储空间。"
            )
        case .systemJunk:
            return L10n.text(
                lang,
                fr: subtitle,
                en: "Free up disk space safely by cleaning temporary caches, logs, and developer build artifacts.",
                es: "Libera espacio en disco limpiando cachés temporales, registros y residuos del sistema.",
                de: "Geben Sie Speicherplatz frei, indem Sie temporäre Caches, Protokolle und Entwicklungsreste bereinigen.",
                ja: "一時キャッシュ、ログ、開発キャッシュを安全に整理してディスク容量を解放します。",
                zh: "安全清理临时缓存、系统日志与开发构建残留，释放磁盘空间。"
            )
        case .storageAnalyzer:
            return L10n.text(
                lang,
                fr: subtitle,
                en: "Visually map your APFS drive (Space Lens) and pinpoint large or forgotten files.",
                es: "Explora visualmente tu disco (Space Lens) y localiza archivos grandes y antiguos.",
                de: "Erkunden Sie Ihr Laufwerk visuell (Space Lens) und finden Sie große oder alte Dateien.",
                ja: "ディスク使用状況を視覚的にマップ（Space Lens）し、大容量ファイルや古いファイルを特定します。",
                zh: "可视化探索您的 APFS 磁盘（Space Lens），快速定位大文件与闲置文件。"
            )
        case .appManager:
            return L10n.text(
                lang,
                fr: subtitle,
                en: "Cleanly uninstall applications and remove orphaned leftovers from ~/Library.",
                es: "Desinstala aplicaciones limpiamente y elimina residuos huérfanos de ~/Library.",
                de: "Deinstallieren Sie Apps sauber und entfernen Sie verwaiste Überreste aus ~/Library.",
                ja: "アプリを完全にアンインストールし、~/Library 内の孤立した残存ファイルを削除します。",
                zh: "彻底卸载应用程序，并清除 ~/Library 中孤立的残留文件。"
            )
        case .duplicateFinder:
            return L10n.text(
                lang,
                fr: subtitle,
                en: "Accurately detect duplicate files using a zero-false-positive 3-pass SHA-256 pipeline.",
                es: "Identifica archivos duplicados con precisión mediante huella SHA-256 en 3 pasadas.",
                de: "Finden Sie doppelte Dateien präzise mit einer 3-stufigen SHA-256-Prüfung ohne Fehlalarme.",
                ja: "3段階のSHA-256ハッシュ検査により、誤検出ゼロで重複ファイルを正確に特定します。",
                zh: "通过三阶段 SHA-256 哈希校验零误报精准识别重复文件。"
            )
        case .performance:
            return L10n.text(
                lang,
                fr: subtitle,
                en: "Monitor real-time Mach virtual memory pressure, CPU load, and resource-heavy processes.",
                es: "Supervisa la presión de memoria Mach, la carga de CPU y los procesos activos en tiempo real.",
                de: "Überwachen Sie Mach-Speicherdruck, CPU-Last und ressourcenintensive Prozesse in Echtzeit.",
                ja: "Machメモリプレッシャー、CPU負荷、高負荷プロセスをリアルタイムに監視します。",
                zh: "实时监控 Mach 虚拟内存压力、CPU 负载及高资源占用进程。"
            )
        case .startupManager:
            return L10n.text(
                lang,
                fr: subtitle,
                en: "Inspect user LaunchAgents, detect broken plists, and reversibly toggle startup items.",
                es: "Controla los agentes de inicio (LaunchAgents) y repara archivos plist rotos.",
                de: "Verwalten Sie LaunchAgents beim Anmelden und reparieren Sie defekte Plist-Dateien.",
                ja: "LaunchAgentsの監査、破損したplistの検出、安全な無効化と復元を行います。",
                zh: "管理登录启动项（LaunchAgents），检测损坏的 plist 并支持一键还原。"
            )
        case .maintenance:
            return L10n.text(
                lang,
                fr: subtitle,
                en: "Run documented macOS maintenance scripts (DNS cache, QuickLook, Spotlight, APFS verify).",
                es: "Ejecuta scripts de mantenimiento de macOS (DNS, QuickLook, Spotlight, APFS).",
                de: "Führen Sie macOS-Wartungsskripte aus (DNS-Cache, QuickLook, Spotlight, APFS).",
                ja: "macOSメンテナンススクリプト（DNS、QuickLook、Spotlight、APFS検証）を実行します。",
                zh: "执行透明可审计的 macOS 维护脚本（DNS 缓存、QuickLook、Spotlight、APFS 校验）。"
            )
        case .protection:
            return L10n.text(
                lang,
                fr: subtitle,
                en: "Audit SIP, Gatekeeper, XProtect, FileVault, cryptographic code signatures, and quarantine.",
                es: "Verifica la integridad de SIP, Gatekeeper, XProtect, firmas de código y cuarentena.",
                de: "Prüfen Sie SIP, Gatekeeper, XProtect, Code-Signaturen und Quarantäne-Attribute.",
                ja: "SIP、Gatekeeper、XProtect、コード署名、隔離属性の整合性を検証します。",
                zh: "全面核查 SIP、Gatekeeper、XProtect、代码签名与隔离属性安全状态。"
            )
        }
    }

    public func localizedPrimaryAction(in lang: AppLanguage) -> String {
        switch self {
        case .performance:
            return L10n.text(lang, fr: "Actualiser", en: "Refresh", es: "Actualizar", de: "Aktualisieren", ja: "更新", zh: "刷新")
        case .maintenance:
            return L10n.text(lang, fr: "Tout vérifier", en: "Run All", es: "Verificar todo", de: "Alle prüfen", ja: "すべて実行", zh: "全部执行")
        default:
            return L10n.text(lang, fr: "Analyser", en: "Scan", es: "Analizar", de: "Scannen", ja: "スキャン", zh: "扫描")
        }
    }

    /// Les 3 piliers pédagogiques affichés sur la scène d'introduction du module.
    public var introFeatures: [IntroFeaturePillar] {
        switch self {
        case .smartCare:
            return [
                IntroFeaturePillar(
                    icon: "wand.and.stars",
                    title: "Analyse rapide du stockage",
                    detail: "Détecte les caches applicatifs, journaux temporaires et artefacts Xcode régénérables sans perte de données."
                ),
                IntroFeaturePillar(
                    icon: "shield.checkered",
                    title: "Contrôle de sécurité & intégrité",
                    detail: "Vérifie l'état de SIP, XProtect, Gatekeeper et les signatures cryptographiques de vos agents."
                ),
                IntroFeaturePillar(
                    icon: "speedometer",
                    title: "Bilan de santé & mémoire Mach",
                    detail: "Mesure la pression mémoire du noyau XNU, la charge CPU et calcule l'indice de santé sur 100."
                )
            ]
        case .systemJunk:
            return [
                IntroFeaturePillar(
                    icon: "internaldrive.fill",
                    title: "Caches utilisateur & système",
                    detail: "Identifie les fichiers de cache obsolètes qui ralentissent les applications et occupent des gigaoctets."
                ),
                IntroFeaturePillar(
                    icon: "hammer.fill",
                    title: "Artefacts Xcode & développement",
                    detail: "Repère DerivedData, caches SwiftPM et journaux de diagnostic en qualifiant chaque élément."
                ),
                IntroFeaturePillar(
                    icon: "trash.slash.fill",
                    title: "Corbeille & restauration SQLite",
                    detail: "Déplace par défaut vers la Corbeille avec possibilité de restauration en un clic à l'emplacement d'origine."
                )
            ]
        case .storageAnalyzer:
            return [
                IntroFeaturePillar(
                    icon: "circle.hexagongrid.fill",
                    title: "Cartographie visuelle Space Lens",
                    detail: "Explorez l'arborescence de vos dossiers classés par taille physique réellement allouée sur APFS."
                ),
                IntroFeaturePillar(
                    icon: "archivebox.fill",
                    title: "Fichiers volumineux & oubliés",
                    detail: "Filtrez instantanément les vidéos, archives, images disque (.dmg) et éléments non ouverts depuis des mois."
                ),
                IntroFeaturePillar(
                    icon: "icloud.fill",
                    title: "Protection des fichiers iCloud",
                    detail: "Ignore automatiquement les placeholders Cloud non téléchargés pour ne jamais déclencher de téléchargement."
                )
            ]
        case .appManager:
            return [
                IntroFeaturePillar(
                    icon: "app.badge.checkmark.fill",
                    title: "Désinstalleur complet",
                    detail: "Regroupe chaque application (.app) avec tous ses dossiers de support, caches et préférences dans ~/Library."
                ),
                IntroFeaturePillar(
                    icon: "puzzlepiece.extension.fill",
                    title: "Détection des restes orphelins",
                    detail: "Retrouve les résidus oubliés par les applications déjà supprimées manuellement dans le Finder."
                ),
                IntroFeaturePillar(
                    icon: "cpu.fill",
                    title: "Inspection Mach-O universelle",
                    detail: "Identifie l'architecture binaire (Universal, Apple Silicon arm64 ou Intel x86_64) et protège les apps système."
                )
            ]
        case .duplicateFinder:
            return [
                IntroFeaturePillar(
                    icon: "number.square.fill",
                    title: "Pipeline SHA-256 en 3 passes",
                    detail: "Compare d'abord la taille exacte, puis l'empreinte rapide 64 Ko, puis le hachage complet CryptoKit SHA-256."
                ),
                IntroFeaturePillar(
                    icon: "lock.doc.fill",
                    title: "Verrouillage de l'original",
                    detail: "Garantit mathématiquement qu'au moins un exemplaire original reste protégé dans chaque groupe de doublons."
                ),
                IntroFeaturePillar(
                    icon: "folder.badge.gearshape",
                    title: "Sélection intelligente rapide",
                    detail: "Pré-coche les copies redondantes pour vous permettre de récupérer de l'espace en quelques secondes."
                )
            ]
        case .performance:
            return [
                IntroFeaturePillar(
                    icon: "memorychip.fill",
                    title: "Mémoire Mach en temps réel",
                    detail: "Visualisez la répartition Active, Résidente (Wired), Compressée et Libre directement via host_statistics64."
                ),
                IntroFeaturePillar(
                    icon: "waveform.path.ecg",
                    title: "Moniteur CPU & Processus",
                    detail: "Identifiez les applications qui consomment le plus de mémoire physique (proc_pid_rusage) et de temps CPU."
                ),
                IntroFeaturePillar(
                    icon: "xmark.app.fill",
                    title: "Fermeture coopérative sûre",
                    detail: "Fermez proprement les applications gourmandes sans fausse purge destructrice du cache noyau."
                )
            ]
        case .startupManager:
            return [
                IntroFeaturePillar(
                    icon: "power.circle.fill",
                    title: "Agents & Démons de lancement",
                    detail: "Inspectez tous les fichiers .plist exécutés automatiquement à l'ouverture de votre session macOS."
                ),
                IntroFeaturePillar(
                    icon: "exclamationmark.triangle.fill",
                    title: "Éléments de connexion brisés",
                    detail: "Détecte les LaunchAgents orphelins dont l'exécutable binaire cible n'existe plus sur le disque."
                ),
                IntroFeaturePillar(
                    icon: "arrow.uturn.backward.circle.fill",
                    title: "Désactivation 100 % réversible",
                    detail: "Sauvegarde intégralement chaque plist désactivé dans SQLite pour permettre sa restauration immédiate."
                )
            ]
        case .maintenance:
            return [
                IntroFeaturePillar(
                    icon: "network",
                    title: "Rafraîchissement du cache DNS",
                    detail: "Purge le résolveur DNS mDNSResponder lorsque certaines adresses web ou locales ne répondent plus."
                ),
                IntroFeaturePillar(
                    icon: "photo.stack.fill",
                    title: "Aperçus QuickLook & Spotlight",
                    detail: "Réinitialise le cache de vignettes QuickLook (`qlmanage -r cache`) et vérifie l'état d'indexation."
                ),
                IntroFeaturePillar(
                    icon: "clock.arrow.circlepath",
                    title: "Instantanés locaux Time Machine",
                    detail: "Liste les snapshots APFS locaux (`tmutil listlocalsnapshots /`) avec prévisualisation exacte des commandes."
                )
            ]
        case .protection:
            return [
                IntroFeaturePillar(
                    icon: "checkmark.shield.fill",
                    title: "Posture SIP, Gatekeeper & XProtect",
                    detail: "Vérifie en temps réel que les protections fondamentales de macOS et les bases antimalware sont actives."
                ),
                IntroFeaturePillar(
                    icon: "signature",
                    title: "Audit SecStaticCode des binaires",
                    detail: "Contrôle la signature cryptographique Apple ou Developer ID des exécutables lancés au démarrage."
                ),
                IntroFeaturePillar(
                    icon: "exclamationmark.shield.fill",
                    title: "Inspection de la Quarantaine",
                    detail: "Analyse l'attribut étendu com.apple.quarantine des téléchargements récents et gère vos exclusions."
                )
            ]
        }
    }
}
