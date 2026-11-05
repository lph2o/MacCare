import CryptoKit
import Foundation

/// Exemplaire individuel au sein d'un groupe de fichiers doublons.
public struct DuplicateFileMember: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let path: String
    public let name: String
    public let sizeBytes: Int64
    public let lastModified: Date?
    public let isLockedOriginal: Bool
    public var isSelectedForRemoval: Bool

    public init(
        id: UUID = UUID(),
        path: String,
        name: String,
        sizeBytes: Int64,
        lastModified: Date? = nil,
        isLockedOriginal: Bool,
        isSelectedForRemoval: Bool = false
    ) {
        self.id = id
        self.path = path
        self.name = name
        self.sizeBytes = sizeBytes
        self.lastModified = lastModified
        self.isLockedOriginal = isLockedOriginal
        self.isSelectedForRemoval = isLockedOriginal ? false : isSelectedForRemoval
    }
}

/// Groupe de doublons strictement identiques (même taille + même empreinte complète `SHA-256`).
/// Garantit par construction qu'au moins un exemplaire original reste non coché.
public struct DuplicateGroup: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let sha256Hex: String
    public let fileSizeBytes: Int64
    public var members: [DuplicateFileMember]

    public init(
        id: UUID = UUID(),
        sha256Hex: String,
        fileSizeBytes: Int64,
        members: [DuplicateFileMember]
    ) {
        self.id = id
        self.sha256Hex = sha256Hex
        self.fileSizeBytes = fileSizeBytes
        self.members = members
    }

    /// Espace récupérable si toutes les copies secondaires sont supprimées (en conservant 1 original).
    public var reclaimableBytes: Int64 {
        Int64(max(0, members.count - 1)) * fileSizeBytes
    }

    /// Nombre d'exemplaires actuellement non cochés (conservés).
    public var keptMembersCount: Int {
        members.filter { !$0.isSelectedForRemoval }.count
    }

    /// Bascule la sélection d'un membre tout en interdisant de sélectionner le dernier exemplaire conservé.
    public mutating func toggleMemberSelection(memberId: UUID) throws {
        guard let idx = members.firstIndex(where: { $0.id == memberId }) else { return }
        if members[idx].isLockedOriginal {
            throw SafetyValidationError.allDuplicatesSelectedInGroup(sha256: sha256Hex)
        }

        let targetNewState = !members[idx].isSelectedForRemoval
        if targetNewState {
            let currentlyUnselected = members.filter { !$0.isSelectedForRemoval }.count
            if currentlyUnselected <= 1 {
                throw SafetyValidationError.allDuplicatesSelectedInGroup(sha256: sha256Hex)
            }
        }
        members[idx].isSelectedForRemoval = targetNewState
    }

    /// Vérifie que le groupe conserve au moins un exemplaire non sélectionné.
    public func validateKeeperInvariant() throws {
        let unselectedCount = members.filter { !$0.isSelectedForRemoval }.count
        if unselectedCount < 1 {
            throw SafetyValidationError.allDuplicatesSelectedInGroup(sha256: sha256Hex)
        }
    }
}

/// Rapport produit par le pipeline en 3 passes de `DuplicateDetector`.
public struct DuplicateScanReport: Sendable, Equatable {
    public let groups: [DuplicateGroup]
    public let totalFilesInspected: Int
    public let pass1SizeCandidatesCount: Int
    public let pass2PartialHashCandidatesCount: Int
    public let pass3ConfirmedDuplicatesCount: Int
    public let totalReclaimableBytes: Int64
    public let durationMilliseconds: Double
}

/// Détecteur déterministe de fichiers doublons en **3 passes** :
/// 1. Regroupement exact par taille en octets (`O(1)` élimination des tailles uniques).
/// 2. Pré-empreinte rapide `SHA256` sur les premiers `32 Ko` et derniers `32 Ko` (`64 Ko`).
/// 3. Empreinte cryptographique intégrale `CryptoKit.SHA256` sur la totalité du fichier.
public struct DuplicateDetector: Sendable {
    public init() {}

    public func detectDuplicates(
        in rootURL: URL,
        safetyEngine: SafetyEngine,
        minimumFileSizeBytes: Int64 = 1_024,
        maxFilesToInspect: Int = 4_000,
        autoSelectRedundantCopies: Bool = false
    ) async throws -> DuplicateScanReport {
        try await Task.detached(priority: .userInitiated) {
            let startTime = CFAbsoluteTimeGetCurrent()
            try Task.checkCancellation()

            let keys: Set<URLResourceKey> = [
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .fileSizeKey,
                .contentModificationDateKey,
                .ubiquitousItemDownloadingStatusKey
            ]

            guard let enumerator = FileManager.default.enumerator(
                at: rootURL,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                return DuplicateScanReport(
                    groups: [],
                    totalFilesInspected: 0,
                    pass1SizeCandidatesCount: 0,
                    pass2PartialHashCandidatesCount: 0,
                    pass3ConfirmedDuplicatesCount: 0,
                    totalReclaimableBytes: 0,
                    durationMilliseconds: 0.1
                )
            }

            // PASSE 1 : Regroupement par taille exacte en octets
            var bySize: [Int64: [(url: URL, modDate: Date?)]] = [:]
            var inspectedCount = 0

            for case let fileURL as URL in enumerator {
                if inspectedCount % 64 == 0 {
                    try Task.checkCancellation()
                }
                if inspectedCount >= maxFilesToInspect { break }

                let vals = try? fileURL.resourceValues(forKeys: keys)
                if vals?.isSymbolicLink == true { continue }
                if ScanEngine.isEvictedCloudPlaceholder(url: fileURL, resourceValues: vals) { continue }
                guard vals?.isRegularFile == true, let rawSize = vals?.fileSize else { continue }

                let size = Int64(rawSize)
                guard size >= minimumFileSizeBytes else { continue }

                let eval = safetyEngine.evaluate(path: fileURL.path, category: .duplicateFiles)
                guard eval.level != .protected else { continue }

                inspectedCount += 1
                bySize[size, default: []].append((url: fileURL, modDate: vals?.contentModificationDate))
            }

            let sizeGroups = bySize.filter { $0.value.count >= 2 }
            let pass1Count = sizeGroups.values.reduce(0) { $0 + $1.count }

            // PASSE 2 : Empreinte partielle rapide (64 Ko : 32 Ko début + 32 Ko fin)
            var byPartialHash: [String: (size: Int64, entries: [(url: URL, modDate: Date?)])] = [:]
            for (size, entries) in sizeGroups {
                for entry in entries {
                    try Task.checkCancellation()
                    guard let partial = try? Self.computePartialHash(for: entry.url, fileSize: size) else { continue }
                    let key = "\(size)-\(partial)"
                    var current = byPartialHash[key]?.entries ?? []
                    current.append(entry)
                    byPartialHash[key] = (size: size, entries: current)
                }
            }

            let partialGroups = byPartialHash.filter { $0.value.entries.count >= 2 }
            let pass2Count = partialGroups.values.reduce(0) { $0 + $1.entries.count }

            // PASSE 3 : Empreinte cryptographique complète CryptoKit.SHA256
            var byFullHash: [String: (size: Int64, entries: [(url: URL, modDate: Date?)])] = [:]
            for (_, groupData) in partialGroups {
                for entry in groupData.entries {
                    try Task.checkCancellation()
                    guard let fullSHA = try? Self.computeFullSHA256(for: entry.url) else { continue }
                    var current = byFullHash[fullSHA]?.entries ?? []
                    current.append(entry)
                    byFullHash[fullSHA] = (size: groupData.size, entries: current)
                }
            }

            var confirmedGroups: [DuplicateGroup] = []
            var pass3Count = 0

            for (shaHex, groupData) in byFullHash where groupData.entries.count >= 2 {
                // Trie de façon déterministe par longueur de chemin puis ordre alphabétique pour désigner l'original conservé
                let sortedEntries = groupData.entries.sorted {
                    if $0.url.path.count != $1.url.path.count {
                        return $0.url.path.count < $1.url.path.count
                    }
                    return $0.url.path < $1.url.path
                }

                var members: [DuplicateFileMember] = []
                for (index, item) in sortedEntries.enumerated() {
                    let isOriginal = (index == 0)
                    members.append(
                        DuplicateFileMember(
                            path: item.url.standardizedFileURL.path,
                            name: item.url.lastPathComponent,
                            sizeBytes: groupData.size,
                            lastModified: item.modDate,
                            isLockedOriginal: isOriginal,
                            isSelectedForRemoval: isOriginal ? false : autoSelectRedundantCopies
                        )
                    )
                }

                pass3Count += members.count
                confirmedGroups.append(
                    DuplicateGroup(
                        sha256Hex: shaHex,
                        fileSizeBytes: groupData.size,
                        members: members
                    )
                )
            }

            confirmedGroups.sort { $0.reclaimableBytes > $1.reclaimableBytes }
            let totalReclaimable = confirmedGroups.reduce(Int64(0)) { $0 + $1.reclaimableBytes }
            let elapsedMs = max(0.1, (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)

            return DuplicateScanReport(
                groups: confirmedGroups,
                totalFilesInspected: inspectedCount,
                pass1SizeCandidatesCount: pass1Count,
                pass2PartialHashCandidatesCount: pass2Count,
                pass3ConfirmedDuplicatesCount: pass3Count,
                totalReclaimableBytes: totalReclaimable,
                durationMilliseconds: elapsedMs
            )
        }.value
    }

    // MARK: - Fonctions de hachage CryptoKit

    /// Calcule l'empreinte partielle sur les premiers 32 Ko et les derniers 32 Ko du fichier.
    public static func computePartialHash(for url: URL, fileSize: Int64) throws -> String {
        let chunkSize = 32_768
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        if fileSize <= Int64(chunkSize * 2) {
            if let allData = try handle.readToEnd() {
                hasher.update(data: allData)
            }
        } else {
            if let headData = try handle.read(upToCount: chunkSize) {
                hasher.update(data: headData)
            }
            try handle.seek(toOffset: UInt64(fileSize - Int64(chunkSize)))
            if let tailData = try handle.read(upToCount: chunkSize) {
                hasher.update(data: tailData)
            }
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Calcule l'empreinte cryptographique complète `SHA-256` en lisant le fichier par blocs de 256 Ko.
    public static func computeFullSHA256(for url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        let bufferSize = 262_144
        while let chunk = try handle.read(upToCount: bufferSize), !chunk.isEmpty {
            hasher.update(data: chunk)
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

