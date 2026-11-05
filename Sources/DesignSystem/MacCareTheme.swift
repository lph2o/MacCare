import SwiftUI

/// Système de design Glassmorphic Aurora natif de MacCare :
/// - Fond Aurora radial par module
/// - Lueurs dynamiques d'état de santé de l'appareil
/// - Surfaces vitrées translucides à contraste élevé
/// - Bouton central d'action flottant en bas au centre de la fenêtre.
public enum MacCareTheme {
    // MARK: - Couleurs de base (Dark Mode immersif + Light Mode)

    /// Fond sombre profond `#0D0E17`
    public static let backgroundDark = Color(red: 0.051, green: 0.055, blue: 0.090)
    /// Surface de carte vitrée sombre `#191B2A`
    public static let surfaceCardDark = Color(red: 0.098, green: 0.106, blue: 0.165)
    /// Fond clair `#F6F5FC`
    public static let backgroundLight = Color(red: 0.969, green: 0.961, blue: 0.988)
    /// Surface de carte claire `#FFFFFF`
    public static let surfaceCardLight = Color.white

    /// Couleur de teinte vitrée
    public static let glassTintDark = Color.white.opacity(0.08)
    public static let glassTintLight = Color.black.opacity(0.04)

    /// Bordure de conteneur vitré
    public static let glassBorderDark = Color.white.opacity(0.16)
    public static let glassBorderLight = Color.black.opacity(0.12)

    // MARK: - Couleurs d'état de santé

    /// `HealthStatusExcellent` : `[0.298, 0.867, 0.992]`
    public static let healthExcellent = Color(red: 0.298, green: 0.867, blue: 0.992)
    /// `HealthStatusGood` : `[0.282, 1.0, 0.827]`
    public static let healthGood = Color(red: 0.282, green: 1.000, blue: 0.827)
    /// `HealthStatusFair` : `[0.780, 1.0, 0.420]`
    public static let healthFair = Color(red: 0.780, green: 1.000, blue: 0.420)
    /// `HealthStatusAttention` : `[1.0, 0.871, 0.184]`
    public static let healthAttention = Color(red: 1.000, green: 0.871, blue: 0.184)
    /// `HealthStatusCritical` : `[1.0, 0.318, 0.318]`
    public static let healthCritical = Color(red: 1.000, green: 0.318, blue: 0.318)

    // MARK: - Accents principaux & statuts de sécurité

    /// Accent principal Cyan/Turquoise lumineux
    public static let accentPrimary = Color(red: 0.224, green: 0.855, blue: 0.992)
    /// Accent secondaire Rose/Magenta Aurora (`[1.0, 0.391, 0.585]`)
    public static let accentSecondary = Color(red: 1.000, green: 0.391, blue: 0.585)
    /// Accent Violet Aurora (`[0.780, 0.459, 1.0]`)
    public static let accentPurple = Color(red: 0.780, green: 0.459, blue: 1.000)

    /// Statut sûr / OK (`#48FFCE`)
    public static let statusSafe = Color(red: 0.282, green: 0.890, blue: 0.690)
    /// Statut attention / conditionnel (`#FFDE2F`)
    public static let statusConditional = Color(red: 1.000, green: 0.780, blue: 0.240)
    /// Statut risque / protégé (`#FF5151`)
    public static let statusProtected = Color(red: 1.000, green: 0.350, blue: 0.420)

    /// Texte principal sombre `#F8F9FC`
    public static let textPrimaryDark = Color(red: 0.973, green: 0.976, blue: 0.988)
    /// Texte secondaire `#A4AEC4`
    public static let textSecondary = Color(red: 0.643, green: 0.682, blue: 0.769)

    // MARK: - Palettes Aurora par module

    public static func auroraPalette(for module: AppModule) -> (primary: Color, secondary: Color) {
        switch module {
        case .smartCare:
            // auroraColorSmartCare : Violet -> Cyan lumineux
            return (
                Color(red: 0.54, green: 0.34, blue: 0.98),
                Color(red: 0.22, green: 0.85, blue: 0.99)
            )
        case .systemJunk:
            // auroraColorJunk : Rose corail -> Magenta
            return (
                Color(red: 1.00, green: 0.36, blue: 0.58),
                Color(red: 0.75, green: 0.24, blue: 0.88)
            )
        case .storageAnalyzer:
            // auroraColorSpaceLens : Cyan profond -> Bleu électrique
            return (
                Color(red: 0.16, green: 0.78, blue: 0.96),
                Color(red: 0.32, green: 0.44, blue: 0.98)
            )
        case .appManager:
            // auroraColorApplications : Bleu azur -> Indigo
            return (
                Color(red: 0.25, green: 0.60, blue: 1.00),
                Color(red: 0.56, green: 0.35, blue: 0.96)
            )
        case .duplicateFinder:
            // auroraColorClutter : Ambre -> Rose vif
            return (
                Color(red: 0.98, green: 0.52, blue: 0.32),
                Color(red: 0.96, green: 0.32, blue: 0.68)
            )
        case .performance:
            // auroraColorPerformance : Orange énergétique -> Rouge corail
            return (
                Color(red: 1.00, green: 0.56, blue: 0.24),
                Color(red: 0.96, green: 0.28, blue: 0.52)
            )
        case .startupManager:
            // Startup / LaunchAgents : Turquoise -> Vert menthe
            return (
                Color(red: 0.20, green: 0.86, blue: 0.76),
                Color(red: 0.24, green: 0.64, blue: 0.96)
            )
        case .maintenance:
            // auroraColorToolbox : Violet -> Bleu
            return (
                Color(red: 0.64, green: 0.40, blue: 0.98),
                Color(red: 0.28, green: 0.68, blue: 0.98)
            )
        case .protection:
            // Protection : Émeraude -> Cyan
            return (
                Color(red: 0.24, green: 0.92, blue: 0.68),
                Color(red: 0.18, green: 0.76, blue: 0.92)
            )
        }
    }

    public static func healthGlowColor(for score: Int) -> Color {
        if score >= 90 {
            return healthExcellent
        } else if score >= 75 {
            return healthGood
        } else if score >= 60 {
            return healthFair
        } else if score >= 45 {
            return healthAttention
        } else {
            return healthCritical
        }
    }

    public static func healthStatusLabel(for score: Int) -> String {
        if score >= 90 {
            return "Excellent"
        } else if score >= 75 {
            return "Bon"
        } else if score >= 60 {
            return "Correct"
        } else if score >= 45 {
            return "Attention requise"
        } else {
            return "Critique"
        }
    }

    // MARK: - Helpers adaptatifs

    public static func primaryBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? backgroundDark : backgroundLight
    }

    public static func cardBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.065) : Color.white.opacity(0.85)
    }

    public static func cardBorder(for scheme: ColorScheme) -> Color {
        scheme == .dark ? glassBorderDark : glassBorderLight
    }

    public static func color(for level: SafetyLevel) -> Color {
        switch level {
        case .safe:
            return statusSafe
        case .conditional:
            return statusConditional
        case .protected:
            return statusProtected
        }
    }

    public static func icon(for level: SafetyLevel) -> String {
        switch level {
        case .safe:
            return "checkmark.shield.fill"
        case .conditional:
            return "exclamationmark.triangle.fill"
        case .protected:
            return "lock.shield.fill"
        }
    }
}
