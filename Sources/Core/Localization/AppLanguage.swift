import Foundation
import SwiftUI

private struct MacCareLanguageEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .en
}

public extension EnvironmentValues {
    var macCareLanguage: AppLanguage {
        get { self[MacCareLanguageEnvironmentKey.self] }
        set { self[MacCareLanguageEnvironmentKey.self] = newValue }
    }
}

/// Langues supportées nativement par MacCare dans l'interface et la barre des menus.
public enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case en = "en"
    case fr = "fr"
    case es = "es"
    case de = "de"
    case ja = "ja"
    case zh = "zh"

    public var id: String { rawValue }

    /// Détecte automatiquement la langue préférée du système macOS au premier lancement.
    public static func detectSystemDefault() -> AppLanguage {
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
        if preferred.hasPrefix("fr") { return .fr }
        if preferred.hasPrefix("es") { return .es }
        if preferred.hasPrefix("de") { return .de }
        if preferred.hasPrefix("ja") { return .ja }
        if preferred.hasPrefix("zh") { return .zh }
        return .en
    }

    public var displayName: String {
        switch self {
        case .en: return "English"
        case .fr: return "Français"
        case .es: return "Español"
        case .de: return "Deutsch"
        case .ja: return "日本語"
        case .zh: return "简体中文"
        }
    }

    public var flagEmoji: String {
        switch self {
        case .en: return "🇬🇧"
        case .fr: return "🇫🇷"
        case .es: return "🇪🇸"
        case .de: return "🇩🇪"
        case .ja: return "🇯🇵"
        case .zh: return "🇨🇳"
        }
    }

    public var shortBadge: String {
        "\(flagEmoji) \(rawValue.uppercased())"
    }
}

/// Moteur de traduction multilingue instantané sans redémarrage.
public enum L10n {
    public static func text(
        _ lang: AppLanguage,
        fr: String,
        en: String,
        es: String? = nil,
        de: String? = nil,
        ja: String? = nil,
        zh: String? = nil
    ) -> String {
        switch lang {
        case .fr:
            return fr
        case .en:
            return en
        case .es:
            return es ?? en
        case .de:
            return de ?? en
        case .ja:
            return ja ?? en
        case .zh:
            return zh ?? en
        }
    }
}
