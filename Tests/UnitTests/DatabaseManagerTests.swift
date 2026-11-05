import XCTest
@testable import MacCare

final class DatabaseManagerTests: XCTestCase {
    private var tempDBURL: URL!

    override func setUpWithError() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacCareDBTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        tempDBURL = tempDir.appendingPathComponent("test_maccare.sqlite")
    }

    override func tearDownWithError() throws {
        if let dir = tempDBURL?.deletingLastPathComponent() {
            try? FileManager.default.removeItem(at: dir)
        }
    }

    func testExclusionRulesLifecycle() async throws {
        let db = try DatabaseManager(path: tempDBURL.path)

        let rule = ExclusionRule(
            pathOrPattern: "/Users/alpha/Documents/SecretProject",
            ruleType: .exactPath,
            note: "Ne jamais analyser"
        )

        try await db.upsertExclusionRule(rule)
        var fetched = try await db.fetchExclusionRules()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.pathOrPattern, "/Users/alpha/Documents/SecretProject")
        XCTAssertEqual(fetched.first?.note, "Ne jamais analyser")

        try await db.removeExclusionRule(id: rule.id)
        fetched = try await db.fetchExclusionRules()
        XCTAssertTrue(fetched.isEmpty)
    }

    func testAuditLogsAndCumulativeBytesFreed() async throws {
        let db = try DatabaseManager(path: tempDBURL.path)

        let log1 = AuditLogEntry(
            module: "System Junk",
            actionMode: .moveToTrash,
            originalPath: "/Users/alpha/Library/Caches/com.test.one/cache.db",
            destinationPath: "/Users/alpha/.Trash/cache.db",
            bytesFreed: 4_000_000,
            status: "SUCCESS"
        )
        let log2 = AuditLogEntry(
            module: "System Junk",
            actionMode: .moveToTrash,
            originalPath: "/Users/alpha/Library/Caches/com.test.two/cache.db",
            destinationPath: nil,
            bytesFreed: 0,
            status: "FAILED",
            errorMessage: "Permission refusée"
        )

        try await db.insertAuditLog(log1)
        try await db.insertAuditLog(log2)

        let logs = try await db.fetchAuditLogs(limit: 10)
        XCTAssertEqual(logs.count, 2)

        let totalFreed = try await db.totalBytesFreed()
        XCTAssertEqual(totalFreed, 4_000_000)
    }
}

