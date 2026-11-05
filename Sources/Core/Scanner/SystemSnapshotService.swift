import Foundation

/// Photographie temps réel de l'état du stockage APFS, de la mémoire Mach et de la charge processeur.
/// Assemblée par `SystemSnapshotService` à partir de `DiskSpaceService` et `MachMetricsService`.
public struct SystemSnapshot: Sendable, Equatable {
    public let capturedAt: Date
    public let volumeName: String
    public let fileSystemType: String
    public let totalDiskBytes: Int64
    public let availableDiskBytes: Int64
    public let availableImportantBytes: Int64
    public let availableOpportunisticBytes: Int64

    public let physicalMemoryBytes: Int64
    public let usedMemoryBytes: Int64
    public let activeMemoryBytes: Int64
    public let inactiveMemoryBytes: Int64
    public let wiredMemoryBytes: Int64
    public let compressedMemoryBytes: Int64
    public let freeMemoryBytes: Int64
    public let pageIns: Int64
    public let pageOuts: Int64
    public let memoryPressure: MemoryPressureLevel

    public let cpuLoadPercentage: Double
    public let cpuUserPercentage: Double
    public let cpuSystemPercentage: Double
    public let cpuIdlePercentage: Double
    public let processorCount: Int
    public let uptimeSeconds: TimeInterval
    public let bootDate: Date
    public let osVersionString: String

    /// Espace disque actuellement utilisé (hors purgeable opportuniste).
    public var usedDiskBytes: Int64 {
        max(0, totalDiskBytes - availableDiskBytes)
    }

    /// Estimation de l'espace purgeable géré par APFS (`important` - `available` standard).
    public var purgeableDiskBytes: Int64 {
        max(0, availableImportantBytes - max(availableDiskBytes, availableOpportunisticBytes))
    }

    /// Ratio d'occupation du disque (0.0 à 1.0).
    public var diskUsageRatio: Double {
        guard totalDiskBytes > 0 else { return 0 }
        return min(1.0, max(0.0, Double(usedDiskBytes) / Double(totalDiskBytes)))
    }

    /// Ratio d'occupation de la RAM (0.0 à 1.0).
    public var memoryUsageRatio: Double {
        guard physicalMemoryBytes > 0 else { return 0 }
        return min(1.0, max(0.0, Double(usedMemoryBytes) / Double(physicalMemoryBytes)))
    }
}

/// Service fédérateur de collecte des métriques macOS combinant `DiskSpaceService` (APFS) et `MachMetricsService` (noyau Mach & `sysctl`).
public struct SystemSnapshotService: Sendable {
    public let diskService: DiskSpaceService
    public let machService: MachMetricsService

    public init(
        diskService: DiskSpaceService = DiskSpaceService(),
        machService: MachMetricsService = MachMetricsService()
    ) {
        self.diskService = diskService
        self.machService = machService
    }

    /// Capture l'état instantané complet du système en moins de 5 ms.
    public func captureSnapshot() -> SystemSnapshot {
        let disk = diskService.queryVolumeMetrics(at: "/")
        let mach = machService.captureTelemetry()
        let info = ProcessInfo.processInfo

        return SystemSnapshot(
            capturedAt: Date(),
            volumeName: disk.volumeName,
            fileSystemType: disk.fileSystemType,
            totalDiskBytes: disk.totalBytes,
            availableDiskBytes: disk.availableBytes,
            availableImportantBytes: disk.availableImportantBytes,
            availableOpportunisticBytes: disk.availableOpportunisticBytes,
            physicalMemoryBytes: mach.physicalMemoryBytes,
            usedMemoryBytes: mach.usedMemoryBytes,
            activeMemoryBytes: mach.activeMemoryBytes,
            inactiveMemoryBytes: mach.inactiveMemoryBytes,
            wiredMemoryBytes: mach.wiredMemoryBytes,
            compressedMemoryBytes: mach.compressedMemoryBytes,
            freeMemoryBytes: mach.freeMemoryBytes,
            pageIns: mach.pageIns,
            pageOuts: mach.pageOuts,
            memoryPressure: mach.memoryPressure,
            cpuLoadPercentage: mach.cpuTotalLoadPercent,
            cpuUserPercentage: mach.cpuUserPercent,
            cpuSystemPercentage: mach.cpuSystemPercent,
            cpuIdlePercentage: mach.cpuIdlePercent,
            processorCount: mach.processorCount,
            uptimeSeconds: mach.uptimeSeconds,
            bootDate: mach.bootDate,
            osVersionString: info.operatingSystemVersionString
        )
    }
}
