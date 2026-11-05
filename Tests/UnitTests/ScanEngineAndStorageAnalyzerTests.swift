import XCTest
@testable import MacCare

final class ScanEngineAndStorageAnalyzerTests: XCTestCase {
    private var sandboxRoot: URL!

    override func setUpWithError() throws {
        sandboxRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacCareMission04-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sandboxRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let sandboxRoot {
            try? FileManager.default.removeItem(at: sandboxRoot)
        }
    }

    func testAPFSFirmlinkAndVirtualMountDetection() {
        XCTAssertTrue(ScanEngine.isRedundantFirmlinkOrVirtualMount("/System/Volumes/Data/Users/alpha"))
        XCTAssertTrue(ScanEngine.isRedundantFirmlinkOrVirtualMount("/Volumes/ExternalDisk"))
        XCTAssertTrue(ScanEngine.isRedundantFirmlinkOrVirtualMount("/dev/null"))
        XCTAssertFalse(ScanEngine.isRedundantFirmlinkOrVirtualMount("/Users/alpha/Documents"))
    }

    func testEvictedCloudPlaceholderDetection() {
        let placeholderURL = sandboxRoot.appendingPathComponent(".LargeMovie.mov.icloud")
        XCTAssertTrue(ScanEngine.isEvictedCloudPlaceholder(url: placeholderURL, resourceValues: nil))

        let normalURL = sandboxRoot.appendingPathComponent("LargeMovie.mov")
        XCTAssertFalse(ScanEngine.isEvictedCloudPlaceholder(url: normalURL, resourceValues: nil))
    }

    func testScanEngineAnalyzesDirectoryHierarchyAndClassifiesLargeFiles() async throws {
        let archivesDir = sandboxRoot.appendingPathComponent("Archives", isDirectory: true)
        let videosDir = sandboxRoot.appendingPathComponent("Videos", isDirectory: true)
        try FileManager.default.createDirectory(at: archivesDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: videosDir, withIntermediateDirectories: true)

        let zipFile = archivesDir.appendingPathComponent("backup.zip")
        let movFile = videosDir.appendingPathComponent("demo.mov")
        try Data(repeating: 0xAB, count: 120_000).write(to: zipFile)
        try Data(repeating: 0xCD, count: 240_000).write(to: movFile)

        let engine = ScanEngine()
        let report = try await engine.analyzeDirectory(
            at: sandboxRoot,
            safetyEngine: SafetyEngine(),
            largeFileThresholdBytes: 50_000,
            maxDepth: 3
        )

        XCTAssertEqual(report.scannedFilesCount, 2)
        XCTAssertEqual(report.rootNode.children.count, 2)
        XCTAssertEqual(report.rootNode.children.first?.name, "Videos")
        XCTAssertGreaterThanOrEqual(report.rootNode.allocatedBytes, 360_000)

        XCTAssertEqual(report.largeFiles.count, 2)
        let kinds = Set(report.largeFiles.map(\.kind))
        XCTAssertTrue(kinds.contains(.archiveOrDiskImage))
        XCTAssertTrue(kinds.contains(.video))
    }

    func testScanEngineSupportsImmediateCancellationUnder200Milliseconds() async throws {
        // Crée plusieurs sous-dossiers pour tester l'annulation coopérative
        for idx in 0 ..< 12 {
            let sub = sandboxRoot.appendingPathComponent("Folder-\(idx)", isDirectory: true)
            try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
            for fileIdx in 0 ..< 15 {
                let f = sub.appendingPathComponent("file-\(fileIdx).dat")
                try Data(repeating: 0x01, count: 4_096).write(to: f)
            }
        }

        let engine = ScanEngine()
        let rootURL = sandboxRoot!
        let start = CFAbsoluteTimeGetCurrent()

        let task = Task {
            try await engine.analyzeDirectory(
                at: rootURL,
                safetyEngine: SafetyEngine(),
                largeFileThresholdBytes: 1_024
            )
        }

        task.cancel()
        do {
            _ = try await task.value
        } catch is CancellationError {
            // Annulation coopérative attendue
        }

        let elapsedMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
        XCTAssertLessThan(elapsedMs, 200.0, "L'annulation du scan doit se terminer en moins de 200 ms (observé : \(elapsedMs) ms)")
    }
}

