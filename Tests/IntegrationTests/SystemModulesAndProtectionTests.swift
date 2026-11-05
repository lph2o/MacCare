import Darwin
import XCTest
@testable import MacCare

final class SystemModulesAndProtectionTests: XCTestCase {
    private var sandboxRoot: URL!

    override func setUpWithError() throws {
        sandboxRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacCareMission07-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sandboxRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let sandboxRoot {
            try? FileManager.default.removeItem(at: sandboxRoot)
        }
    }

    func testProcessMonitorServiceReadsCurrentProcessMachRusage() {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let usage = ProcessMonitorService.queryProcessResourceUsage(pid: currentPID)

        XCTAssertGreaterThan(usage.footprintBytes, 0, "L'empreinte mémoire physique Mach ri_phys_footprint doit être > 0")
        XCTAssertGreaterThanOrEqual(usage.cpuSeconds, 0.0)
    }

    func testStartupItemsServiceDetectsBrokenPlistsAndPerformsReversibleSQLiteDisableRestore() async throws {
        let agentsDir = sandboxRoot.appendingPathComponent("LaunchAgents", isDirectory: true)
        let backupDir = sandboxRoot.appendingPathComponent("DisabledBackups", isDirectory: true)
        try FileManager.default.createDirectory(at: agentsDir, withIntermediateDirectories: true)

        // 1. Agent valide pointant vers /bin/ls
        let validPlistURL = agentsDir.appendingPathComponent("com.vendor.validhelper.plist")
        let validDict: [String: Any] = [
            "Label": "com.vendor.validhelper",
            "ProgramArguments": ["/bin/ls", "-la"],
            "RunAtLoad": true
        ]
        (validDict as NSDictionary).write(to: validPlistURL, atomically: true)

        // 2. Agent orphelin/brisé pointant vers un binaire désinstallé
        let brokenPlistURL = agentsDir.appendingPathComponent("com.vendor.orphanhelper.plist")
        let brokenDict: [String: Any] = [
            "Label": "com.vendor.orphanhelper",
            "Program": "/Applications/RemovedApp.app/Contents/MacOS/RemovedDaemon",
            "RunAtLoad": true
        ]
        (brokenDict as NSDictionary).write(to: brokenPlistURL, atomically: true)

        // 3. Agent Apple protégé
        let applePlistURL = agentsDir.appendingPathComponent("com.apple.protectedagent.plist")
        let appleDict: [String: Any] = [
            "Label": "com.apple.protectedagent",
            "Program": "/usr/libexec/trustd"
        ]
        (appleDict as NSDictionary).write(to: applePlistURL, atomically: true)

        let service = StartupItemsService()
        let items = service.discoverStartupItems(directories: [(url: agentsDir, scope: .userLaunchAgent)])
        XCTAssertEqual(items.count, 3)

        guard let validItem = items.first(where: { $0.label == "com.vendor.validhelper" }),
              let brokenItem = items.first(where: { $0.label == "com.vendor.orphanhelper" }),
              let appleItem = items.first(where: { $0.label == "com.apple.protectedagent" }) else {
            XCTFail("Les 3 agents doivent être découverts")
            return
        }

        XCTAssertFalse(validItem.isBrokenExecutable)
        XCTAssertEqual(validItem.safetyLevel, .conditional)

        XCTAssertTrue(brokenItem.isBrokenExecutable)
        XCTAssertEqual(brokenItem.safetyLevel, .conditional)

        XCTAssertTrue(appleItem.isAppleProtected)
        XCTAssertEqual(appleItem.safetyLevel, .protected)

        let dbPath = sandboxRoot.appendingPathComponent("startup_m07.sqlite").path
        let db = try DatabaseManager(path: dbPath)

        // Vérifie qu'un agent protégé Apple ne peut pas être désactivé
        do {
            _ = try await service.disableUserLaunchAgent(appleItem, backupDirectory: backupDir, database: db)
            XCTFail("Un agent Apple protégé ne doit jamais pouvoir être désactivé")
        } catch StartupManagerError.itemIsProtected {
            // Attendu
        }

        // Désactive l'agent orphelin avec sauvegarde SQLite
        let backupRecord = try await service.disableUserLaunchAgent(
            brokenItem,
            backupDirectory: backupDir,
            database: db
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: brokenPlistURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupRecord.backupPath))

        let savedBackups = try await db.fetchStartupBackups()
        XCTAssertEqual(savedBackups.count, 1)
        XCTAssertEqual(savedBackups.first?.label, "com.vendor.orphanhelper")

        // Restaure l'agent à son emplacement d'origine
        try await service.restoreUserLaunchAgent(backupRecord, database: db)
        XCTAssertTrue(FileManager.default.fileExists(atPath: brokenPlistURL.path))
        let remainingBackups = try await db.fetchStartupBackups()
        XCTAssertTrue(remainingBackups.isEmpty)
    }

    func testMaintenanceRunnerServicePreviewsExactCommandAndLogsOutputToSQLite() async throws {
        XCTAssertGreaterThanOrEqual(MaintenanceRunnerService.catalog.count, 5)
        for spec in MaintenanceRunnerService.catalog {
            XCTAssertFalse(spec.commandLinePreview.isEmpty)
            XCTAssertTrue(spec.commandLinePreview.hasPrefix("/usr/"))
        }

        let dbPath = sandboxRoot.appendingPathComponent("maintenance_m07.sqlite").path
        let db = try DatabaseManager(path: dbPath)

        let runner = MaintenanceRunnerService { exec, args in
            return (exitCode: 0, output: "Simulated OK for \(exec) \(args.joined(separator: " "))")
        }

        let spec = MaintenanceRunnerService.catalog[0]
        let result = await runner.runOperation(spec, database: db)

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.commandLine, "/usr/bin/qlmanage -r cache")
        XCTAssertTrue(result.outputText.contains("Simulated OK"))

        let logs = try await db.fetchAuditLogs(limit: 5)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.status, "MAINTENANCE_OK")
        XCTAssertEqual(logs.first?.originalPath, "/usr/bin/qlmanage -r cache")
    }

    func testSecurityPostureServiceVerifiesSecStaticCodeAndReadsPOSIXQuarantineXattr() throws {
        // 1. Vérifie SecStaticCode sur un binaire système signé (/bin/ls)
        let lsAudit = SecurityPostureService.verifyCodeSignature(atPath: "/bin/ls", label: "ls")
        XCTAssertEqual(lsAudit.status, .validSigned)
        XCTAssertEqual(lsAudit.safetyLevel, .safe)

        // 2. Vérifie SecStaticCode sur un fichier texte non signé
        let unsignedURL = sandboxRoot.appendingPathComponent("unsigned_script.sh")
        try Data("#!/bin/sh\necho hello\n".utf8).write(to: unsignedURL)
        let unsignedAudit = SecurityPostureService.verifyCodeSignature(atPath: unsignedURL.path, label: "script")
        XCTAssertNotEqual(unsignedAudit.status, .validSigned)

        // 3. Pose un attribut étendu com.apple.quarantine via setxattr et vérifie sa lecture par getxattr
        let quarantinedFile = sandboxRoot.appendingPathComponent("DownloadedInstaller.dmg")
        try Data(repeating: 0x7F, count: 4_096).write(to: quarantinedFile)

        let quarantineValue = "0081;6728a000;Safari;99887766-5544-3322-1100-AABBCCDDEEFF"
        let cValue = Array(quarantineValue.utf8CString)
        let setRes = setxattr(
            quarantinedFile.path,
            SecurityPostureService.quarantineAttributeName,
            cValue,
            cValue.count - 1,
            0,
            XATTR_NOFOLLOW
        )
        XCTAssertEqual(setRes, 0)

        let scanned = SecurityPostureService.scanQuarantinedFiles(in: sandboxRoot)
        XCTAssertEqual(scanned.count, 1)
        XCTAssertEqual(scanned.first?.name, "DownloadedInstaller.dmg")
        XCTAssertEqual(scanned.first?.agentName, "Safari")
    }
}

