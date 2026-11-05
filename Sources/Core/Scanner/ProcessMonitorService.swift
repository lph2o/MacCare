import AppKit
import Darwin
import Foundation

/// Échantillon horodaté de télémétrie CPU et RAM pour les courbes temps réel `Swift Charts`.
public struct TelemetryHistoryPoint: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let cpuLoadPercentage: Double
    public let usedMemoryGigabytes: Double

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        cpuLoadPercentage: Double,
        usedMemoryGigabytes: Double
    ) {
        self.id = id
        self.timestamp = timestamp
        self.cpuLoadPercentage = cpuLoadPercentage
        self.usedMemoryGigabytes = usedMemoryGigabytes
    }
}

/// Informations sur un processus applicatif actif collectées via `NSWorkspace` et `proc_pid_rusage`.
public struct RunningProcessItem: Identifiable, Hashable, Sendable {
    public var id: Int32 { pid }
    public let pid: Int32
    public let name: String
    public let bundleIdentifier: String
    public let bundlePath: String?
    public let physicalFootprintBytes: Int64
    public let cpuTimeSeconds: Double
    public let isSystemOrProtected: Bool
    public let safetyLevel: SafetyLevel

    public init(
        pid: Int32,
        name: String,
        bundleIdentifier: String,
        bundlePath: String?,
        physicalFootprintBytes: Int64,
        cpuTimeSeconds: Double,
        isSystemOrProtected: Bool,
        safetyLevel: SafetyLevel
    ) {
        self.pid = pid
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.bundlePath = bundlePath
        self.physicalFootprintBytes = physicalFootprintBytes
        self.cpuTimeSeconds = cpuTimeSeconds
        self.isSystemOrProtected = isSystemOrProtected
        self.safetyLevel = safetyLevel
    }
}

/// Service natif de surveillance des processus actifs (`NSWorkspace.shared.runningApplications` + appel noyau `proc_pid_rusage`).
/// N'invoque jamais `/bin/ps` et ne promet aucune « optimisation magique » de la RAM.
public struct ProcessMonitorService: Sendable {
    public init() {}

    /// Liste les applications actives avec leur empreinte mémoire physique Mach (`ri_phys_footprint`) et leur temps CPU cumulé.
    public func listRunningProcesses() -> [RunningProcessItem] {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let apps = NSWorkspace.shared.runningApplications
        var items: [RunningProcessItem] = []

        for app in apps {
            let pid = app.processIdentifier
            guard pid > 0 else { continue }

            let name = app.localizedName ?? app.bundleURL?.deletingPathExtension().lastPathComponent ?? "Processus \(pid)"
            let bundleID = app.bundleIdentifier ?? "pid.\(pid)"
            let path = app.bundleURL?.path

            let rusage = Self.queryProcessResourceUsage(pid: pid)
            let isAppleSystem = bundleID.lowercased().hasPrefix("com.apple.")
                || (path?.hasPrefix("/System/") == true)
                || pid == currentPID

            let level: SafetyLevel = isAppleSystem ? .protected : .conditional

            items.append(
                RunningProcessItem(
                    pid: pid,
                    name: name,
                    bundleIdentifier: bundleID,
                    bundlePath: path,
                    physicalFootprintBytes: rusage.footprintBytes,
                    cpuTimeSeconds: rusage.cpuSeconds,
                    isSystemOrProtected: isAppleSystem,
                    safetyLevel: level
                )
            )
        }

        items.sort {
            if $0.physicalFootprintBytes != $1.physicalFootprintBytes {
                return $0.physicalFootprintBytes > $1.physicalFootprintBytes
            }
            return $0.cpuTimeSeconds > $1.cpuTimeSeconds
        }
        return items
    }

    /// Demande la fermeture coopérative (`NSRunningApplication.terminate()`) d'une application utilisateur non système.
    @MainActor
    public func terminateUserApplication(pid: Int32) -> Bool {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        guard pid != currentPID else { return false }
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == pid }) else {
            return false
        }
        if let bundleID = app.bundleIdentifier?.lowercased(), bundleID.hasPrefix("com.apple.") {
            return false
        }
        if let path = app.bundleURL?.path, path.hasPrefix("/System/") {
            return false
        }
        return app.terminate()
    }

    /// Interroge le noyau XNU via `proc_pid_rusage(pid, RUSAGE_INFO_V4, ...)` pour lire l'empreinte mémoire et le temps CPU.
    public static func queryProcessResourceUsage(pid: Int32) -> (footprintBytes: Int64, cpuSeconds: Double) {
        var info = rusage_info_v4()
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }

        guard status == 0 else {
            return (footprintBytes: 0, cpuSeconds: 0.0)
        }

        let footprint = Int64(info.ri_phys_footprint)
        let totalNanoseconds = Double(info.ri_user_time + info.ri_system_time)
        return (footprintBytes: max(0, footprint), cpuSeconds: totalNanoseconds / 1_000_000_000.0)
    }
}

