import XCTest
@testable import MacCare

final class SystemJunkAndRestoreIntegrationTests: XCTestCase {
    private var sandboxRoot: URL!

    override func setUpWithError() throws {
        sandboxRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacCareMission05-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sandboxRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let sandboxRoot {
            try? FileManager.default.removeItem(at: sandboxRoot)
        }
    }

    func testSystemJunkScannerClassifiesSafeConditionalAndRunningAppProtected() async throws {
        let inactiveCacheDir = sandboxRoot.appendingPathComponent("Caches/com.example.inactive", isDirectory: true)
        let runningCacheDir = sandboxRoot.appendingPathComponent("Caches/com.example.running", isDirectory: true)
        let derivedDir = sandboxRoot.appendingPathComponent("DerivedData/AppBuild", isDirectory: true)

        try FileManager.default.createDirectory(at: inactiveCacheDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: runningCacheDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: derivedDir, withIntermediateDirectories: true)

        try Data(repeating: 0xAA, count: 16_384).write(to: inactiveCacheDir.appendingPathComponent("cache.bin"))
        try Data(repeating: 0xBB, count: 16_384).write(to: runningCacheDir.appendingPathComponent("live.bin"))
        try Data(repeating: 0xCC, count: 32_768).write(to: derivedDir.appendingPathComponent("index.o"))

        let targets = [
            SystemJunkTarget(path: sandboxRoot.appendingPathComponent("Caches").path, category: .userCaches),
            SystemJunkTarget(path: sandboxRoot.appendingPathComponent("DerivedData").path, category: .xcodeDeveloperArtifacts)
        ]

        let safetyEngine = SafetyEngine(
            userExclusions: [],
            runningBundleIdentifiers: ["com.example.running"]
        )
        let scanner = SystemJunkScanner()
        let report = try await scanner.scan(targets: targets, safetyEngine: safetyEngine, autoSelectSafeItems: true)

        XCTAssertEqual(report.candidates.count, 3)
        XCTAssertEqual(report.protectedRunningAppCount, 1)

        let inactiveItem = report.candidates.first { $0.displayName == "com.example.inactive" }
        XCTAssertEqual(inactiveItem?.safetyLevel, .safe)
        XCTAssertEqual(inactiveItem?.isSelected, true)

        let runningItem = report.candidates.first { $0.displayName == "com.example.running" }
        XCTAssertEqual(runningItem?.safetyLevel, .protected)
        XCTAssertEqual(runningItem?.isSelected, false)

        let derivedItem = report.candidates.first { $0.displayName == "AppBuild" }
        XCTAssertEqual(derivedItem?.safetyLevel, .conditional)
        XCTAssertEqual(derivedItem?.isSelected, false, "Un élément conditionnel ne doit jamais être coché par défaut")
    }

    func testActiveProcessGuardBlocksSymlinkPointingToProtectedSystemArea() throws {
        let symlinkURL = sandboxRoot.appendingPathComponent("malicious_link")
        try FileManager.default.createSymbolicLink(
            atPath: symlinkURL.path,
            withDestinationPath: "/System/Library/CoreServices/Finder.app"
        )

        let candidate = ScanCandidate(
            path: symlinkURL.path,
            displayName: "malicious_link",
            category: .userCaches,
            sizeBytes: 4_096,
            safetyLevel: .safe,
            explanation: "Test symlink",
            potentialImpact: "Aucun",
            isSelected: true
        )

        let guardService = ActiveProcessGuard(activeBundleIdentifiers: [])
        XCTAssertThrowsError(
            try guardService.verifyPreFlight(candidate: candidate, safetyEngine: SafetyEngine())
        ) { error in
            guard case PreFlightSecurityError.symlinkPointsToProtectedArea = error else {
                XCTFail("Erreur attendue : symlinkPointsToProtectedArea, reçu : \(error)")
                return
            }
        }
    }

    @MainActor
    func testFullLifecycleDetectionStagingTrashAuditAndRestore() async throws {
        let dbPath = sandboxRoot.appendingPathComponent("maccare_m05.sqlite").path
        let db = try DatabaseManager(path: dbPath)
        let trashDir = sandboxRoot.appendingPathComponent("TrashSandbox", isDirectory: true)

        let cacheFolder = sandboxRoot.appendingPathComponent("Caches/com.example.restorable", isDirectory: true)
        try FileManager.default.createDirectory(at: cacheFolder, withIntermediateDirectories: true)
        let payloadFile = cacheFolder.appendingPathComponent("state.dat")
        let expectedData = Data("MacCare-Restorable-Payload-2026".utf8)
        try expectedData.write(to: payloadFile)

        // 1. Scan via SystemJunkScanner
        let scanner = SystemJunkScanner()
        let engine = SafetyEngine()
        let scanReport = try await scanner.scan(
            targets: [SystemJunkTarget(path: sandboxRoot.appendingPathComponent("Caches").path, category: .userCaches)],
            safetyEngine: engine
        )
        XCTAssertEqual(scanReport.candidates.count, 1)

        // 2. Ajout au StagingQueue et exécution vers la Corbeille isolée
        let queue = StagingQueue()
        for item in scanReport.candidates {
            queue.addOrUpdate(item)
        }
        let execReport = try await queue.executeCurrentPlan(
            moduleName: "System Junk",
            safetyEngine: engine,
            database: db,
            customTrashDirectory: trashDir
        )

        XCTAssertEqual(execReport.succeededCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheFolder.path))

        // 3. Restauration depuis le journal SQLite vers l'emplacement d'origine
        guard let trashLog = execReport.logEntries.first else {
            XCTFail("Entrée de journal manquante")
            return
        }

        let restoredLog = try await queue.restoreFromTrash(logEntry: trashLog, database: db)
        XCTAssertEqual(restoredLog.status, "RESTORED")
        XCTAssertEqual(restoredLog.actionMode, .restoreFromTrash)

        // 4. Vérification de la restauration physique et de l'intégrité des données
        XCTAssertTrue(FileManager.default.fileExists(atPath: payloadFile.path))
        let restoredData = try Data(contentsOf: payloadFile)
        XCTAssertEqual(restoredData, expectedData)

        let allLogs = try await db.fetchAuditLogs(limit: 10)
        XCTAssertEqual(allLogs.count, 2)
    }
}

