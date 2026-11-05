import XCTest
@testable import MacCare

final class AppManagerAndDuplicateFinderTests: XCTestCase {
    private var sandboxRoot: URL!

    override func setUpWithError() throws {
        sandboxRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacCareMission06-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sandboxRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let sandboxRoot {
            try? FileManager.default.removeItem(at: sandboxRoot)
        }
    }

    func testDuplicateDetectorThreePassZeroFalsePositivesOnSingleMiddleByteDifference() async throws {
        // Crée 3 fichiers de 128 Ko (> 64 Ko de la Passe 2) :
        // - fileA et fileB sont strictement identiques (128 Ko)
        // - fileC a exactement la même taille (128 Ko), les mêmes premiers 32 Ko et les mêmes derniers 32 Ko,
        //   mais diffère d'UN SEUL OCTET à l'offset 64 000 (au milieu du fichier) !
        let totalSize = 131_072
        var baseBuffer = Data(repeating: 0x3C, count: totalSize)
        let fileA = sandboxRoot.appendingPathComponent("original_doc.pdf")
        let fileB = sandboxRoot.appendingPathComponent("copy_doc.pdf")
        let fileC = sandboxRoot.appendingPathComponent("modified_middle_byte_doc.pdf")

        try baseBuffer.write(to: fileA)
        try baseBuffer.write(to: fileB)

        baseBuffer[64_000] = 0xFF
        try baseBuffer.write(to: fileC)

        let detector = DuplicateDetector()
        let report = try await detector.detectDuplicates(
            in: sandboxRoot,
            safetyEngine: SafetyEngine(),
            minimumFileSizeBytes: 1_024,
            autoSelectRedundantCopies: true
        )

        // Les 3 fichiers ont la même taille (Passe 1 = 3) et les mêmes 64 Ko début/fin (Passe 2 = 3),
        // mais la Passe 3 (SHA-256 complet) doit isoler uniquement fileA et fileB (Passe 3 = 2) !
        XCTAssertEqual(report.totalFilesInspected, 3)
        XCTAssertEqual(report.pass1SizeCandidatesCount, 3)
        XCTAssertEqual(report.pass2PartialHashCandidatesCount, 3)
        XCTAssertEqual(report.pass3ConfirmedDuplicatesCount, 2)
        XCTAssertEqual(report.groups.count, 1)

        guard var group = report.groups.first else {
            XCTFail("Groupe de doublons attendu")
            return
        }

        XCTAssertEqual(group.members.count, 2)
        XCTAssertEqual(group.keptMembersCount, 1)

        // Vérifie l'impossibilité de cocher l'original verrouillé
        guard let lockedMember = group.members.first(where: \.isLockedOriginal) else {
            XCTFail("Un original verrouillé est requis")
            return
        }
        XCTAssertThrowsError(try group.toggleMemberSelection(memberId: lockedMember.id)) { error in
            guard case SafetyValidationError.allDuplicatesSelectedInGroup = error else {
                XCTFail("Erreur attendue : allDuplicatesSelectedInGroup")
                return
            }
        }
    }

    func testAppBundleAnalyzerCorrelatesLibraryFilesProtectsAppleAppsAndFindsOrphanedLeftovers() async throws {
        let appsDir = sandboxRoot.appendingPathComponent("Applications", isDirectory: true)
        let libraryDir = sandboxRoot.appendingPathComponent("Library", isDirectory: true)
        try FileManager.default.createDirectory(at: appsDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: libraryDir, withIntermediateDirectories: true)

        // 1. Crée une application utilisateur simulée : StudioPro.app (com.vendor.studiopro)
        let userAppURL = appsDir.appendingPathComponent("StudioPro.app", isDirectory: true)
        let userContents = userAppURL.appendingPathComponent("Contents/MacOS", isDirectory: true)
        try FileManager.default.createDirectory(at: userContents, withIntermediateDirectories: true)

        let userPlist: [String: Any] = [
            "CFBundleName": "StudioPro",
            "CFBundleIdentifier": "com.vendor.studiopro",
            "CFBundleShortVersionString": "2.4.0",
            "CFBundleExecutable": "StudioPro"
        ]
        (userPlist as NSDictionary).write(to: userAppURL.appendingPathComponent("Contents/Info.plist"), atomically: true)

        // Écrit un en-tête universel Fat Mach-O (0xCAFEBABE) dans le binaire
        var fatHeader = Data([0xCA, 0xFE, 0xBA, 0xBE, 0x00, 0x00, 0x00, 0x02])
        fatHeader.append(Data(repeating: 0x90, count: 16_384))
        try fatHeader.write(to: userContents.appendingPathComponent("StudioPro"))

        // 2. Crée une application système Apple simulée : AppleCalc.app (com.apple.calculator)
        let appleAppURL = appsDir.appendingPathComponent("AppleCalc.app", isDirectory: true)
        try FileManager.default.createDirectory(at: appleAppURL.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        let applePlist: [String: Any] = [
            "CFBundleName": "AppleCalc",
            "CFBundleIdentifier": "com.apple.calculator",
            "CFBundleShortVersionString": "14.0"
        ]
        (applePlist as NSDictionary).write(to: appleAppURL.appendingPathComponent("Contents/Info.plist"), atomically: true)

        // 3. Crée des fichiers associés dans Library pour com.vendor.studiopro
        let appCacheDir = libraryDir.appendingPathComponent("Caches/com.vendor.studiopro", isDirectory: true)
        let appSupportDir = libraryDir.appendingPathComponent("Application Support/com.vendor.studiopro", isDirectory: true)
        try FileManager.default.createDirectory(at: appCacheDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        try Data(repeating: 0x01, count: 8_192).write(to: appCacheDir.appendingPathComponent("cache.db"))
        try Data(repeating: 0x02, count: 8_192).write(to: appSupportDir.appendingPathComponent("settings.json"))

        // 4. Crée un résidu orphelin d'une application désinstallée : com.oldcompany.ghostapp
        let orphanDir = libraryDir.appendingPathComponent("Caches/com.oldcompany.ghostapp", isDirectory: true)
        try FileManager.default.createDirectory(at: orphanDir, withIntermediateDirectories: true)
        try Data(repeating: 0xEE, count: 12_288).write(to: orphanDir.appendingPathComponent("leftover.dat"))

        let analyzer = AppBundleAnalyzer()
        let report = try await analyzer.analyzeApplications(
            applicationDirectories: [appsDir],
            userLibraryURL: libraryDir,
            safetyEngine: SafetyEngine()
        )

        XCTAssertEqual(report.apps.count, 2)

        // Vérifie StudioPro.app
        guard let studioApp = report.apps.first(where: { $0.bundleIdentifier == "com.vendor.studiopro" }) else {
            XCTFail("StudioPro.app introuvable")
            return
        }
        XCTAssertEqual(studioApp.architecture, .universal)
        XCTAssertEqual(studioApp.safetyLevel, .conditional)
        XCTAssertEqual(studioApp.associatedFiles.count, 2)
        XCTAssertEqual(analyzer.buildUninstallCandidates(for: studioApp).count, 3)

        // Vérifie que l'application Apple est strictement protégée et refuse toute désinstallation
        guard let appleApp = report.apps.first(where: { $0.bundleIdentifier == "com.apple.calculator" }) else {
            XCTFail("AppleCalc.app introuvable")
            return
        }
        XCTAssertTrue(appleApp.isAppleSystemApp)
        XCTAssertEqual(appleApp.safetyLevel, .protected)
        XCTAssertTrue(analyzer.buildUninstallCandidates(for: appleApp).isEmpty)

        // Vérifie la détection du résidu orphelin com.oldcompany.ghostapp
        XCTAssertEqual(report.orphanedLeftovers.count, 1)
        XCTAssertEqual(report.orphanedLeftovers.first?.displayName, "com.oldcompany.ghostapp")
    }
}

