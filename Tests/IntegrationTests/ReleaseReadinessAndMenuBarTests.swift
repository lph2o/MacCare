import XCTest
@testable import MacCare

final class ReleaseReadinessAndMenuBarTests: XCTestCase {
    func testAllNineModulesHaveUniqueIndicesShortcutsAndMetadata() {
        let allModules = AppModule.allCases
        XCTAssertEqual(allModules.count, 9)

        let indices = Set(allModules.map(\.indexNumber))
        XCTAssertEqual(indices, Set(1 ... 9))

        for module in allModules {
            XCTAssertFalse(module.title.isEmpty)
            XCTAssertFalse(module.subtitle.isEmpty)
            XCTAssertFalse(module.systemImage.isEmpty)
            XCTAssertFalse(module.phaseBadge.isEmpty)
        }
    }

    @MainActor
    func testCoordinatorSupportsMenuBarToggleAndTelemetryHistory() throws {
        let tempDB = try DatabaseManager(path: ":memory:")
        let coordinator = NavigationCoordinator(database: tempDB)

        XCTAssertTrue(coordinator.showMenuBarExtra)
        coordinator.showMenuBarExtra = false
        XCTAssertFalse(coordinator.showMenuBarExtra)

        let initialCount = coordinator.telemetryHistory.count
        coordinator.refreshSystemMetrics()
        XCTAssertEqual(coordinator.telemetryHistory.count, initialCount + 1)
    }

    func testFormattersProduceHumanReadableFrenchStrings() {
        let formattedSize = MacCareFormatters.formatBytes(1_048_576)
        XCTAssertFalse(formattedSize.isEmpty)

        let formattedUptime = MacCareFormatters.formatUptime(90_060)
        XCTAssertEqual(formattedUptime, "1j 1h 1m")
    }
}

