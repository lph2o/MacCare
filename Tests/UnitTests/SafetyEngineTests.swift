import XCTest
@testable import MacCare

final class SafetyEngineTests: XCTestCase {
    func testHardProtectedSystemPrefixesAreAlwaysBlocked() {
        let engine = SafetyEngine()

        let systemEval = engine.evaluate(path: "/System/Library/CoreServices/Finder.app", category: .applicationBundles)
        XCTAssertEqual(systemEval.level, .protected)

        let usrEval = engine.evaluate(path: "/usr/bin/swift", category: .temporaryFiles)
        XCTAssertEqual(usrEval.level, .protected)

        let sbinEval = engine.evaluate(path: "/sbin/mount", category: .temporaryFiles)
        XCTAssertEqual(sbinEval.level, .protected)
    }

    func testSensitiveUserPathsAreProtected() {
        let engine = SafetyEngine()

        let keychainEval = engine.evaluate(
            path: "/Users/alpha/Library/Keychains/login.keychain-db",
            category: .userCaches
        )
        XCTAssertEqual(keychainEval.level, .protected)

        let tccEval = engine.evaluate(
            path: "/Users/alpha/Library/Application Support/com.apple.TCC/TCC.db",
            category: .applicationLeftovers
        )
        XCTAssertEqual(tccEval.level, .protected)

        let sshEval = engine.evaluate(
            path: "/Users/alpha/.ssh/id_ed25519",
            category: .temporaryFiles
        )
        XCTAssertEqual(sshEval.level, .protected)

        let gitRepoEval = engine.evaluate(
            path: "/Users/alpha/Projects/MyRepo/.git/config",
            category: .temporaryFiles
        )
        XCTAssertEqual(gitRepoEval.level, .protected)
    }

    func testInternalAppBundleContentsAreProtectedToPreserveCodeSignature() {
        let engine = SafetyEngine()

        let innerEval = engine.evaluate(
            path: "/Applications/SampleApp.app/Contents/Resources/es.lproj",
            category: .userCaches
        )
        XCTAssertEqual(innerEval.level, .protected)
    }

    func testRunningApplicationCachesAreProtected() {
        let engine = SafetyEngine(
            userExclusions: [],
            runningBundleIdentifiers: ["com.apple.safari", "com.example.activeapp"]
        )

        let runningCache = engine.evaluate(
            path: "/Users/alpha/Library/Caches/com.example.activeapp/Cache.db",
            category: .userCaches
        )
        XCTAssertEqual(runningCache.level, .protected)

        let inactiveCache = engine.evaluate(
            path: "/Users/alpha/Library/Caches/com.example.closedapp/Cache.db",
            category: .userCaches
        )
        XCTAssertEqual(inactiveCache.level, .safe)
    }

    func testUserExclusionRulesOverrideSafeClassification() {
        let rule = ExclusionRule(
            pathOrPattern: "/Users/alpha/Library/Caches/com.protected.custom",
            ruleType: .exactPath,
            note: "Protégé par l'utilisateur"
        )
        let engine = SafetyEngine(userExclusions: [rule])

        let eval = engine.evaluate(
            path: "/Users/alpha/Library/Caches/com.protected.custom/data.bin",
            category: .userCaches
        )
        XCTAssertEqual(eval.level, .protected)
    }

    func testDerivedDataAndTrashAreClassifiedAsConditional() {
        let engine = SafetyEngine()

        let derivedEval = engine.evaluate(
            path: "/Users/alpha/Library/Developer/Xcode/DerivedData/MacCare-abcdef",
            category: .xcodeDeveloperArtifacts
        )
        XCTAssertEqual(derivedEval.level, .conditional)

        let trashEval = engine.evaluate(
            path: "/Users/alpha/.Trash/OldArchive.zip",
            category: .trashItems
        )
        XCTAssertEqual(trashEval.level, .conditional)
    }

    func testValidatePlanRejectsProtectedCandidate() {
        let engine = SafetyEngine()
        let badCandidate = ScanCandidate(
            path: "/System/Library/Kernels/kernel",
            displayName: "kernel",
            category: .temporaryFiles,
            sizeBytes: 1024,
            safetyLevel: .safe,
            explanation: "Falsifié",
            potentialImpact: "Critique",
            isSelected: true
        )
        let plan = StagingPlan(candidates: [badCandidate], actionMode: .moveToTrash)

        XCTAssertThrowsError(try engine.validate(plan: plan)) { error in
            guard case SafetyValidationError.protectedItemInPlan(let path, _) = error else {
                XCTFail("Erreur inattendue : \(error)")
                return
            }
            XCTAssertEqual(path, "/System/Library/Kernels/kernel")
        }
    }
}

