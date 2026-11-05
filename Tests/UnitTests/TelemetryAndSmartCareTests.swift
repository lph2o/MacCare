import XCTest
@testable import MacCare

final class TelemetryAndSmartCareTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacCareMission03-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
    }

    func testDiskSpaceServiceReturnsCoherentAPFSMetrics() throws {
        let diskService = DiskSpaceService()
        let metrics = diskService.queryVolumeMetrics(at: "/")

        XCTAssertGreaterThan(metrics.totalBytes, 0)
        XCTAssertGreaterThan(metrics.availableBytes, 0)
        XCTAssertGreaterThanOrEqual(metrics.availableImportantBytes, metrics.availableOpportunisticBytes)
        XCTAssertEqual(metrics.fileSystemType, "APFS")

        let sampleFile = tempRoot.appendingPathComponent("block_test.bin")
        try Data(repeating: 0x5A, count: 16_384).write(to: sampleFile)
        let allocated = diskService.allocatedSize(at: sampleFile)
        XCTAssertGreaterThanOrEqual(allocated, 16_384)
    }

    func testMachMetricsServiceCapturesCPUAndVirtualMemory() {
        let machService = MachMetricsService()
        let telemetry = machService.captureTelemetry()

        XCTAssertGreaterThanOrEqual(telemetry.cpuTotalLoadPercent, 0.0)
        XCTAssertLessThanOrEqual(telemetry.cpuTotalLoadPercent, 100.0)
        XCTAssertGreaterThan(telemetry.physicalMemoryBytes, 0)
        XCTAssertGreaterThan(telemetry.activeMemoryBytes, 0)
        XCTAssertGreaterThan(telemetry.wiredMemoryBytes, 0)
        XCTAssertGreaterThan(telemetry.uptimeSeconds, 60.0)
    }

    func testSnapshotCaptureLatencyIsUnder300Milliseconds() {
        let snapshotService = SystemSnapshotService()
        let start = CFAbsoluteTimeGetCurrent()
        let snapshot = snapshotService.captureSnapshot()
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0

        XCTAssertGreaterThan(snapshot.totalDiskBytes, 0)
        XCTAssertLessThan(elapsedMs, 300.0, "La capture de télémétrie doit s'exécuter en moins de 300 ms (observé : \(elapsedMs) ms)")
    }

    func testSmartCareDiagnosticServiceAndScanSessionPersistence() async throws {
        let cachesDir = tempRoot.appendingPathComponent("Caches/com.example.demo", isDirectory: true)
        let derivedDir = tempRoot.appendingPathComponent("DerivedData/ProjectA", isDirectory: true)
        try FileManager.default.createDirectory(at: cachesDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: derivedDir, withIntermediateDirectories: true)

        try Data(repeating: 0x11, count: 32_768).write(to: cachesDir.appendingPathComponent("cache.bin"))
        try Data(repeating: 0x22, count: 65_536).write(to: derivedDir.appendingPathComponent("build.o"))

        let targets = [
            DiagnosticTarget(path: tempRoot.appendingPathComponent("Caches").path, category: .userCaches),
            DiagnosticTarget(path: tempRoot.appendingPathComponent("DerivedData").path, category: .xcodeDeveloperArtifacts)
        ]

        let snapshot = SystemSnapshotService().captureSnapshot()
        let diagnosticService = SmartCareDiagnosticService()
        let report = try await diagnosticService.runDiagnostic(
            targets: targets,
            safetyEngine: SafetyEngine(),
            snapshot: snapshot
        )

        XCTAssertEqual(report.candidates.count, 2)
        XCTAssertGreaterThanOrEqual(report.summary.safeBytes, 32_768)
        XCTAssertGreaterThanOrEqual(report.summary.conditionalBytes, 65_536)
        XCTAssertTrue((20 ... 100).contains(report.healthScore))
        XCTAssertFalse(report.recommendations.isEmpty)

        // Persistance SQLite de la session de diagnostic
        let dbPath = tempRoot.appendingPathComponent("sessions.sqlite").path
        let db = try DatabaseManager(path: dbPath)
        try await db.insertScanSession(report.session)

        let sessions = try await db.fetchRecentScanSessions(limit: 5)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.candidatesCount, 2)
        XCTAssertEqual(sessions.first?.reclaimableBytes, report.summary.totalReclaimableBytes)
    }
}

