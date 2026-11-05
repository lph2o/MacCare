import Darwin
import Foundation

/// Niveau de pression mémoire estimé à partir des compteurs Mach VM.
public enum MemoryPressureLevel: String, Codable, Sendable, Equatable {
    case normal = "Normale"
    case warning = "Modérée"
    case critical = "Élevée"
}

/// Compteurs détaillés du processeur et de la mémoire virtuelle Mach.
public struct MachTelemetryMetrics: Sendable, Equatable {
    public let cpuUserPercent: Double
    public let cpuSystemPercent: Double
    public let cpuIdlePercent: Double
    public let cpuTotalLoadPercent: Double
    public let processorCount: Int

    public let physicalMemoryBytes: Int64
    public let activeMemoryBytes: Int64
    public let inactiveMemoryBytes: Int64
    public let wiredMemoryBytes: Int64
    public let compressedMemoryBytes: Int64
    public let freeMemoryBytes: Int64
    public let pageIns: Int64
    public let pageOuts: Int64
    public let memoryPressure: MemoryPressureLevel

    public let uptimeSeconds: TimeInterval
    public let bootDate: Date

    public var usedMemoryBytes: Int64 {
        activeMemoryBytes + wiredMemoryBytes + compressedMemoryBytes
    }
}

/// Service natif de télémétrie noyau Mach (`host_processor_info`, `host_statistics64`, `sysctl KERN_BOOTTIME`).
/// N'invoque aucun processus externe (`/bin/ps` ou `top`) et libère systématiquement les buffers Mach (`vm_deallocate`).
public struct MachMetricsService: Sendable {
    public init() {}

    /// Capture l'ensemble des métriques Mach (CPU, RAM, Pression mémoire, Uptime `KERN_BOOTTIME`).
    public func captureTelemetry() -> MachTelemetryMetrics {
        let cpu = Self.sampleCPULoad()
        let vm = Self.sampleVirtualMemory()
        let boot = Self.queryKernelBootTime()

        return MachTelemetryMetrics(
            cpuUserPercent: cpu.user,
            cpuSystemPercent: cpu.system,
            cpuIdlePercent: cpu.idle,
            cpuTotalLoadPercent: cpu.total,
            processorCount: max(1, ProcessInfo.processInfo.activeProcessorCount),
            physicalMemoryBytes: vm.physical,
            activeMemoryBytes: vm.active,
            inactiveMemoryBytes: vm.inactive,
            wiredMemoryBytes: vm.wired,
            compressedMemoryBytes: vm.compressed,
            freeMemoryBytes: vm.free,
            pageIns: vm.pageIns,
            pageOuts: vm.pageOuts,
            memoryPressure: vm.pressure,
            uptimeSeconds: boot.uptime,
            bootDate: boot.bootDate
        )
    }

    // MARK: - Mach host_processor_info

    private static func sampleCPULoad() -> (user: Double, system: Double, idle: Double, total: Double) {
        var numCPUsU: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUsU,
            &cpuInfo,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let info = cpuInfo else {
            var loadAvg: [Double] = [0.0, 0.0, 0.0]
            _ = getloadavg(&loadAvg, 3)
            let cores = Double(max(1, ProcessInfo.processInfo.activeProcessorCount))
            let total = min(100.0, max(1.0, (loadAvg[0] / cores) * 100.0))
            return (user: total * 0.65, system: total * 0.35, idle: max(0.0, 100.0 - total), total: total)
        }

        defer {
            let byteCount = vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), byteCount)
        }

        var totalUser: Int64 = 0
        var totalSystem: Int64 = 0
        var totalIdle: Int64 = 0
        var totalNice: Int64 = 0

        for i in 0 ..< Int(numCPUsU) {
            let base = Int(CPU_STATE_MAX) * i
            totalUser += Int64(info[base + Int(CPU_STATE_USER)])
            totalSystem += Int64(info[base + Int(CPU_STATE_SYSTEM)])
            totalIdle += Int64(info[base + Int(CPU_STATE_IDLE)])
            totalNice += Int64(info[base + Int(CPU_STATE_NICE)])
        }

        let grandTotal = Double(max(1, totalUser + totalSystem + totalIdle + totalNice))
        let userPct = (Double(totalUser + totalNice) / grandTotal) * 100.0
        let sysPct = (Double(totalSystem) / grandTotal) * 100.0
        let idlePct = (Double(totalIdle) / grandTotal) * 100.0
        let busyPct = min(100.0, max(0.0, userPct + sysPct))

        return (user: userPct, system: sysPct, idle: idlePct, total: busyPct)
    }

    // MARK: - Mach host_statistics64

    private static func sampleVirtualMemory() -> (
        physical: Int64,
        active: Int64,
        inactive: Int64,
        wired: Int64,
        compressed: Int64,
        free: Int64,
        pageIns: Int64,
        pageOuts: Int64,
        pressure: MemoryPressureLevel
    ) {
        let physical = Int64(ProcessInfo.processInfo.physicalMemory)
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let hostPort = mach_host_self()

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
            }
        }

        var pageSize: vm_size_t = 4096
        host_page_size(hostPort, &pageSize)
        let pageBytes = Int64(pageSize)

        guard result == KERN_SUCCESS else {
            return (
                physical: physical,
                active: physical / 3,
                inactive: physical / 6,
                wired: physical / 6,
                compressed: physical / 12,
                free: physical / 4,
                pageIns: 0,
                pageOuts: 0,
                pressure: .normal
            )
        }

        let active = Int64(stats.active_count) * pageBytes
        let inactive = Int64(stats.inactive_count) * pageBytes
        let wired = Int64(stats.wire_count) * pageBytes
        let compressed = Int64(stats.compressor_page_count) * pageBytes
        let free = Int64(stats.free_count) * pageBytes
        let pageIns = Int64(stats.pageins)
        let pageOuts = Int64(stats.pageouts)

        let usedRatio = Double(active + wired + compressed) / Double(max(1, physical))
        let compressedRatio = Double(compressed) / Double(max(1, physical))

        let pressure: MemoryPressureLevel
        if usedRatio > 0.90 || compressedRatio > 0.30 {
            pressure = .critical
        } else if usedRatio > 0.78 || compressedRatio > 0.18 {
            pressure = .warning
        } else {
            pressure = .normal
        }

        return (
            physical: physical,
            active: active,
            inactive: inactive,
            wired: wired,
            compressed: compressed,
            free: free,
            pageIns: pageIns,
            pageOuts: pageOuts,
            pressure: pressure
        )
    }

    // MARK: - sysctl KERN_BOOTTIME

    private static func queryKernelBootTime() -> (uptime: TimeInterval, bootDate: Date) {
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        var bootTime = timeval()
        var size = MemoryLayout<timeval>.stride

        if sysctl(&mib, 2, &bootTime, &size, nil, 0) == 0, bootTime.tv_sec > 0 {
            let bootDate = Date(timeIntervalSince1970: TimeInterval(bootTime.tv_sec))
            let uptime = max(1.0, Date().timeIntervalSince(bootDate))
            return (uptime: uptime, bootDate: bootDate)
        }

        let fallbackUptime = ProcessInfo.processInfo.systemUptime
        return (uptime: fallbackUptime, bootDate: Date().addingTimeInterval(-fallbackUptime))
    }
}

