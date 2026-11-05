import Foundation
import UniformTypeIdentifiers

/// Famille de type de fichier détectée via `UniformTypeIdentifiers` (`UTType`).
public enum StorageFileKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case video = "Vidéo"
    case archiveOrDiskImage = "Archive & Image Disque"
    case audio = "Audio"
    case image = "Image"
    case developer = "Développement"
    case document = "Document"
    case application = "Application"
    case other = "Autre"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .video: return "film.fill"
        case .archiveOrDiskImage: return "doc.zipper"
        case .audio: return "waveform"
        case .image: return "photo.fill"
        case .developer: return "hammer.fill"
        case .document: return "doc.text.fill"
        case .application: return "app.badge.fill"
        case .other: return "doc.fill"
        }
    }

    /// Détermine la famille d'un fichier à partir de son `UTType` ou de son extension.
    public static func classify(url: URL, contentType: UTType?) -> StorageFileKind {
        let ext = url.pathExtension.lowercased()
        if ["dmg", "iso", "pkg", "zip", "tar", "gz", "tgz", "bz2", "xz", "7z", "rar", "xip"].contains(ext) {
            return .archiveOrDiskImage
        }
        if ["swift", "c", "cpp", "h", "hpp", "m", "mm", "py", "js", "ts", "rs", "go", "java", "kt", "o", "a", "dylib", "framework", "xcarchive"].contains(ext) {
            return .developer
        }
        if ext == "app" {
            return .application
        }

        if let type = contentType {
            if type.conforms(to: .movie) || type.conforms(to: .video) {
                return .video
            }
            if type.conforms(to: .archive) || type.conforms(to: .diskImage) {
                return .archiveOrDiskImage
            }
            if type.conforms(to: .audio) {
                return .audio
            }
            if type.conforms(to: .image) {
                return .image
            }
            if type.conforms(to: .sourceCode) {
                return .developer
            }
            if type.conforms(to: .pdf) || type.conforms(to: .presentation) || type.conforms(to: .spreadsheet) || type.conforms(to: .text) {
                return .document
            }
            if type.conforms(to: .applicationBundle) {
                return .application
            }
        }
        return .other
    }
}

/// Nœud de l'arborescence de stockage calculé par `ScanEngine`.
public struct StorageNode: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let path: String
    public let name: String
    public let isDirectory: Bool
    public let allocatedBytes: Int64
    public let fileCount: Int
    public let lastModified: Date?
    public let safetyLevel: SafetyLevel
    public let safetyReason: String
    public let children: [StorageNode]

    public init(
        id: UUID = UUID(),
        path: String,
        name: String,
        isDirectory: Bool,
        allocatedBytes: Int64,
        fileCount: Int,
        lastModified: Date?,
        safetyLevel: SafetyLevel,
        safetyReason: String,
        children: [StorageNode] = []
    ) {
        self.id = id
        self.path = path
        self.name = name
        self.isDirectory = isDirectory
        self.allocatedBytes = max(0, allocatedBytes)
        self.fileCount = max(0, fileCount)
        self.lastModified = lastModified
        self.safetyLevel = safetyLevel
        self.safetyReason = safetyReason
        self.children = children
    }
}

/// Fichier volumineux ou ancien identifié lors de l'exploration arborescente.
public struct LargeFileItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let path: String
    public let name: String
    public let allocatedBytes: Int64
    public let lastAccessedOrModified: Date
    public let kind: StorageFileKind
    public let safetyLevel: SafetyLevel
    public let safetyReason: String

    public init(
        id: UUID = UUID(),
        path: String,
        name: String,
        allocatedBytes: Int64,
        lastAccessedOrModified: Date,
        kind: StorageFileKind,
        safetyLevel: SafetyLevel,
        safetyReason: String
    ) {
        self.id = id
        self.path = path
        self.name = name
        self.allocatedBytes = allocatedBytes
        self.lastAccessedOrModified = lastAccessedOrModified
        self.kind = kind
        self.safetyLevel = safetyLevel
        self.safetyReason = safetyReason
    }

    /// Ancienneté en jours depuis le dernier accès ou la dernière modification.
    public func ageInDays(referenceDate: Date = Date()) -> Int {
        max(0, Int(referenceDate.timeIntervalSince(lastAccessedOrModified) / 86_400.0))
    }
}

/// Résultat complet d'une analyse de stockage produite par `ScanEngine`.
public struct StorageScanReport: Sendable, Equatable {
    public let rootNode: StorageNode
    public let largeFiles: [LargeFileItem]
    public let scannedFilesCount: Int
    public let skippedCloudPlaceholdersCount: Int
    public let skippedFirmlinksCount: Int
    public let durationMilliseconds: Double
}

/// Moteur d'analyse arborescente asynchrone (`actor`) de MacCare.
/// Utilise `withThrowingTaskGroup` borné, évite les firmlinks APFS redondants (`/System/Volumes/Data`),
/// ignore les fichiers iCloud non téléchargés (`ubiquitousItemDownloadingStatusKey`) pour ne déclencher aucun téléchargement,
/// et supporte l'annulation immédiate (`Task.checkCancellation()`).
public actor ScanEngine {
    /// Chemins de firmlinks APFS ou points de montage virtuels ignorés pour éviter le double comptage.
    public static let apfsFirmlinkAndVirtualMountPrefixes: [String] = [
        "/System/Volumes/Data",
        "/System/Volumes/VM",
        "/System/Volumes/Preboot",
        "/System/Volumes/Update",
        "/Volumes",
        "/dev",
        "/net",
        "/home"
    ]

    public init() {}

    /// Indique si un chemin correspond à un firmlink APFS redondant ou système virtuel.
    public nonisolated static func isRedundantFirmlinkOrVirtualMount(_ path: String) -> Bool {
        let normalized = (path as NSString).standardizingPath
        for prefix in apfsFirmlinkAndVirtualMountPrefixes {
            if normalized == prefix || normalized.hasPrefix(prefix + "/") {
                return true
            }
        }
        return false
    }

    /// Indique si une URL correspond à un fichier iCloud Drive évincé / non téléchargé localement.
    public nonisolated static func isEvictedCloudPlaceholder(url: URL, resourceValues: URLResourceValues?) -> Bool {
        let name = url.lastPathComponent
        if name.hasPrefix(".") && name.lowercased().hasSuffix(".icloud") {
            return true
        }
        if let status = resourceValues?.ubiquitousItemDownloadingStatus,
           status == .notDownloaded {
            return true
        }
        return false
    }

    /// Analyse en parallèle les sous-dossiers d'un répertoire racine et construit la cartographie `StorageNode` ainsi que la liste `LargeFileItem`.
    public func analyzeDirectory(
        at rootURL: URL,
        safetyEngine: SafetyEngine,
        largeFileThresholdBytes: Int64 = 1_048_576,
        maxDepth: Int = 3,
        maxEntriesPerSubtree: Int = 2_500
    ) async throws -> StorageScanReport {
        let startTime = CFAbsoluteTimeGetCurrent()
        try Task.checkCancellation()

        let fm = FileManager.default
        let rootPath = rootURL.standardizedFileURL.path
        let topEntries = (try? fm.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .isSymbolicLinkKey,
                .isRegularFileKey,
                .totalFileAllocatedSizeKey,
                .fileAllocatedSizeKey,
                .fileSizeKey,
                .contentModificationDateKey,
                .contentAccessDateKey,
                .contentTypeKey,
                .ubiquitousItemDownloadingStatusKey
            ],
            options: [.skipsHiddenFiles]
        )) ?? []

        // Parallélisme borné par lots de 6 tâches concurrentes maximum
        let maxConcurrency = 6
        var childNodes: [StorageNode] = []
        var allLargeFiles: [LargeFileItem] = []
        var totalFilesScanned = 0
        var totalSkippedCloud = 0
        var totalSkippedFirmlinks = 0

        try await withThrowingTaskGroup(
            of: (node: StorageNode?, largeFiles: [LargeFileItem], fileCount: Int, skippedCloud: Int, skippedFirmlink: Int).self
        ) { group in
            var activeTasks = 0

            for entryURL in topEntries {
                try Task.checkCancellation()
                if activeTasks >= maxConcurrency {
                    if let result = try await group.next() {
                        activeTasks -= 1
                        if let node = result.node { childNodes.append(node) }
                        allLargeFiles.append(contentsOf: result.largeFiles)
                        totalFilesScanned += result.fileCount
                        totalSkippedCloud += result.skippedCloud
                        totalSkippedFirmlinks += result.skippedFirmlink
                    }
                }

                activeTasks += 1
                group.addTask {
                    try Task.checkCancellation()
                    return try Self.scanSubtree(
                        at: entryURL,
                        currentDepth: 1,
                        maxDepth: maxDepth,
                        maxEntries: maxEntriesPerSubtree,
                        largeFileThresholdBytes: largeFileThresholdBytes,
                        safetyEngine: safetyEngine
                    )
                }
            }

            while let result = try await group.next() {
                if let node = result.node { childNodes.append(node) }
                allLargeFiles.append(contentsOf: result.largeFiles)
                totalFilesScanned += result.fileCount
                totalSkippedCloud += result.skippedCloud
                totalSkippedFirmlinks += result.skippedFirmlink
            }
        }

        childNodes.sort { $0.allocatedBytes > $1.allocatedBytes }
        allLargeFiles.sort { $0.allocatedBytes > $1.allocatedBytes }

        let totalAllocated = childNodes.reduce(Int64(0)) { $0 + $1.allocatedBytes }
        let rootEval = safetyEngine.evaluate(path: rootPath, category: .largeFiles)
        let rootNode = StorageNode(
            path: rootPath,
            name: rootURL.lastPathComponent.isEmpty ? rootPath : rootURL.lastPathComponent,
            isDirectory: true,
            allocatedBytes: totalAllocated,
            fileCount: totalFilesScanned,
            lastModified: Date(),
            safetyLevel: rootEval.level,
            safetyReason: rootEval.reason,
            children: childNodes
        )

        let elapsedMs = max(0.1, (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)
        return StorageScanReport(
            rootNode: rootNode,
            largeFiles: Array(allLargeFiles.prefix(250)),
            scannedFilesCount: totalFilesScanned,
            skippedCloudPlaceholdersCount: totalSkippedCloud,
            skippedFirmlinksCount: totalSkippedFirmlinks,
            durationMilliseconds: elapsedMs
        )
    }

    private nonisolated static func scanSubtree(
        at url: URL,
        currentDepth: Int,
        maxDepth: Int,
        maxEntries: Int,
        largeFileThresholdBytes: Int64,
        safetyEngine: SafetyEngine
    ) throws -> (node: StorageNode?, largeFiles: [LargeFileItem], fileCount: Int, skippedCloud: Int, skippedFirmlink: Int) {
        try Task.checkCancellation()
        let path = url.standardizedFileURL.path

        if isRedundantFirmlinkOrVirtualMount(path) {
            return (nil, [], 0, 0, 1)
        }

        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .isRegularFileKey,
            .isPackageKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .contentAccessDateKey,
            .contentTypeKey,
            .ubiquitousItemDownloadingStatusKey
        ]

        let vals = try? url.resourceValues(forKeys: keys)
        if vals?.isSymbolicLink == true {
            return (nil, [], 0, 0, 0)
        }

        if isEvictedCloudPlaceholder(url: url, resourceValues: vals) {
            return (nil, [], 0, 1, 0)
        }

        let isDir = vals?.isDirectory ?? false
        let isPackage = vals?.isPackage ?? false

        // Fichier simple
        if !isDir {
            let size = Int64(vals?.totalFileAllocatedSize ?? vals?.fileAllocatedSize ?? vals?.fileSize ?? 0)
            let modDate = vals?.contentAccessDate ?? vals?.contentModificationDate ?? Date()
            let eval = safetyEngine.evaluate(path: path, category: .largeFiles)
            let node = StorageNode(
                path: path,
                name: url.lastPathComponent,
                isDirectory: false,
                allocatedBytes: size,
                fileCount: 1,
                lastModified: modDate,
                safetyLevel: eval.level,
                safetyReason: eval.reason
            )

            var large: [LargeFileItem] = []
            if size >= largeFileThresholdBytes {
                let kind = StorageFileKind.classify(url: url, contentType: vals?.contentType)
                large.append(
                    LargeFileItem(
                        path: path,
                        name: url.lastPathComponent,
                        allocatedBytes: size,
                        lastAccessedOrModified: modDate,
                        kind: kind,
                        safetyLevel: eval.level,
                        safetyReason: eval.reason
                    )
                )
            }
            return (node, large, 1, 0, 0)
        }

        // Si on est encore dans la profondeur d'arbre interactive et que ce n'est pas un bundle .app/.framework
        if currentDepth < maxDepth && !isPackage {
            let childrenURLs = (try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles]
            )) ?? []

            var subNodes: [StorageNode] = []
            var subLarge: [LargeFileItem] = []
            var count = 0
            var skippedCloud = 0
            var skippedFirmlinks = 0

            for childURL in childrenURLs.prefix(120) {
                try Task.checkCancellation()
                let sub = try scanSubtree(
                    at: childURL,
                    currentDepth: currentDepth + 1,
                    maxDepth: maxDepth,
                    maxEntries: max(100, maxEntries / 4),
                    largeFileThresholdBytes: largeFileThresholdBytes,
                    safetyEngine: safetyEngine
                )
                if let n = sub.node { subNodes.append(n) }
                subLarge.append(contentsOf: sub.largeFiles)
                count += sub.fileCount
                skippedCloud += sub.skippedCloud
                skippedFirmlinks += sub.skippedFirmlink
            }

            subNodes.sort { $0.allocatedBytes > $1.allocatedBytes }
            let sumBytes = subNodes.reduce(Int64(0)) { $0 + $1.allocatedBytes }
            let eval = safetyEngine.evaluate(path: path, category: .largeFiles)

            let dirNode = StorageNode(
                path: path,
                name: url.lastPathComponent,
                isDirectory: true,
                allocatedBytes: sumBytes,
                fileCount: count,
                lastModified: vals?.contentModificationDate,
                safetyLevel: eval.level,
                safetyReason: eval.reason,
                children: Array(subNodes.prefix(40))
            )
            return (dirNode, subLarge, count, skippedCloud, skippedFirmlinks)
        }

        // Exploration linéaire bornée au-delà de maxDepth ou pour un paquet (.app)
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return (nil, [], 0, 0, 0)
        }

        var totalBytes: Int64 = 0
        var fileCount = 0
        var skippedCloud = 0
        var largeFiles: [LargeFileItem] = []

        for case let fileURL as URL in enumerator {
            if fileCount % 64 == 0 {
                try Task.checkCancellation()
            }
            if fileCount >= maxEntries { break }

            let itemVals = try? fileURL.resourceValues(forKeys: keys)
            if itemVals?.isSymbolicLink == true { continue }
            if isEvictedCloudPlaceholder(url: fileURL, resourceValues: itemVals) {
                skippedCloud += 1
                continue
            }
            guard itemVals?.isRegularFile == true else { continue }

            fileCount += 1
            let size = Int64(itemVals?.totalFileAllocatedSize ?? itemVals?.fileAllocatedSize ?? itemVals?.fileSize ?? 0)
            totalBytes += size

            if !isPackage && size >= largeFileThresholdBytes {
                let itemPath = fileURL.standardizedFileURL.path
                let eval = safetyEngine.evaluate(path: itemPath, category: .largeFiles)
                let modDate = itemVals?.contentAccessDate ?? itemVals?.contentModificationDate ?? Date()
                let kind = StorageFileKind.classify(url: fileURL, contentType: itemVals?.contentType)
                largeFiles.append(
                    LargeFileItem(
                        path: itemPath,
                        name: fileURL.lastPathComponent,
                        allocatedBytes: size,
                        lastAccessedOrModified: modDate,
                        kind: kind,
                        safetyLevel: eval.level,
                        safetyReason: eval.reason
                    )
                )
            }
        }

        let cat: ScanCategory = isPackage ? .applicationBundles : .largeFiles
        let eval = safetyEngine.evaluate(path: path, category: cat)
        let leafDirNode = StorageNode(
            path: path,
            name: url.lastPathComponent,
            isDirectory: true,
            allocatedBytes: totalBytes,
            fileCount: fileCount,
            lastModified: vals?.contentModificationDate,
            safetyLevel: eval.level,
            safetyReason: eval.reason
        )
        return (leafDirNode, largeFiles, fileCount, skippedCloud, 0)
    }
}

