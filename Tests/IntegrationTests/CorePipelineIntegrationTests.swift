import XCTest
@testable import MacCare

final class CorePipelineIntegrationTests: XCTestCase {
    private var sandboxRoot: URL!

    override func setUpWithError() throws {
        sandboxRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacCareIntegration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sandboxRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let sandboxRoot {
            try? FileManager.default.removeItem(at: sandboxRoot)
        }
    }

    @MainActor
    func testEndToEndStagingValidationAndTrashExecutionWithSQLiteAudit() async throws {
        let dbPath = sandboxRoot.appendingPathComponent("audit.sqlite").path
        let db = try DatabaseManager(path: dbPath)
        let trashDir = sandboxRoot.appendingPathComponent("SimulatedTrash", isDirectory: true)

        // Crée un fichier temporaire de cache simulé
        let fakeCacheFile = sandboxRoot.appendingPathComponent("sample_cache.tmp")
        let payload = Data(repeating: 0x41, count: 8_192)
        try payload.write(to: fakeCacheFile)

        let engine = SafetyEngine()
        let eval = engine.evaluate(path: fakeCacheFile.path, category: .temporaryFiles)
        XCTAssertEqual(eval.level, .safe)

        let candidate = ScanCandidate(
            path: fakeCacheFile.path,
            displayName: "sample_cache.tmp",
            category: .temporaryFiles,
            sizeBytes: Int64(payload.count),
            safetyLevel: eval.level,
            explanation: eval.reason,
            potentialImpact: eval.impact,
            isSelected: true
        )

        let queue = StagingQueue()
        queue.addOrUpdate(candidate)
        XCTAssertEqual(queue.selectedItems.count, 1)
        XCTAssertEqual(queue.selectedBytes, 8_192)

        let report = try await queue.executeCurrentPlan(
            moduleName: "IntegrationTest",
            safetyEngine: engine,
            database: db,
            customTrashDirectory: trashDir
        )

        XCTAssertEqual(report.succeededCount, 1)
        XCTAssertEqual(report.failedCount, 0)
        XCTAssertEqual(report.totalBytesFreed, 8_192)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fakeCacheFile.path))

        // Vérifie que le fichier a bien été déplacé dans la corbeille simulée (et non détruit définitivement)
        let trashedFiles = try FileManager.default.contentsOfDirectory(atPath: trashDir.path)
        XCTAssertEqual(trashedFiles.count, 1)

        // Vérifie que l'audit SQLite a bien enregistré l'opération
        let logs = try await db.fetchAuditLogs(limit: 5)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.status, "SUCCESS")
        XCTAssertEqual(logs.first?.bytesFreed, 8_192)
    }

    func testSystemSnapshotServiceCapturesValidMetrics() {
        let service = SystemSnapshotService()
        let snapshot = service.captureSnapshot()

        XCTAssertGreaterThan(snapshot.totalDiskBytes, 0)
        XCTAssertGreaterThan(snapshot.physicalMemoryBytes, 0)
        XCTAssertGreaterThanOrEqual(snapshot.processorCount, 1)
        XCTAssertFalse(snapshot.osVersionString.isEmpty)
    }
}

