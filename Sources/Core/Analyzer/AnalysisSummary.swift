import Foundation

/// Synthèse structurée d'une analyse de stockage ou de nettoyage par catégorie et niveau de sécurité.
public struct AnalysisSummary: Sendable, Equatable {
    public let totalCandidates: Int
    public let safeBytes: Int64
    public let conditionalBytes: Int64
    public let protectedBytes: Int64
    public let bytesByCategory: [ScanCategory: Int64]

    public init(candidates: [ScanCandidate]) {
        self.totalCandidates = candidates.count
        var safe: Int64 = 0
        var conditional: Int64 = 0
        var protected: Int64 = 0
        var byCat: [ScanCategory: Int64] = [:]

        for item in candidates {
            switch item.safetyLevel {
            case .safe:
                safe += item.sizeBytes
            case .conditional:
                conditional += item.sizeBytes
            case .protected:
                protected += item.sizeBytes
            }
            byCat[item.category, default: 0] += item.sizeBytes
        }

        self.safeBytes = safe
        self.conditionalBytes = conditional
        self.protectedBytes = protected
        self.bytesByCategory = byCat
    }

    /// Total récupérable (éléments `.safe` + `.conditional`).
    public var totalReclaimableBytes: Int64 {
        safeBytes + conditionalBytes
    }
}

/// Utilitaires de formatage lisibles pour les tailles de fichiers et durées.
public enum MacCareFormatters {
    public static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    public static func formatUptime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        if days > 0 {
            return "\(days)j \(hours)h \(minutes)m"
        }
        return "\(hours)h \(minutes)m"
    }
}

