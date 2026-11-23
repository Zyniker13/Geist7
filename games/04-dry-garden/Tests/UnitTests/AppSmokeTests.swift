// AppSmokeTests.swift — P0 smoke tests for the app target.

import XCTest

@testable import DryGarden_macOS

final class AppSmokeTests: XCTestCase {
    func testLaunchArgumentsDefaultsFailClosed() {
        let parsed = LaunchArguments.parse([])
        XCTAssertFalse(parsed.startMatch)
        XCTAssertFalse(parsed.debugOverlay)
        XCTAssertNil(parsed.seed)
        XCTAssertNil(parsed.scenario)
    }

    func testLaunchArgumentsParseSeedAndOverlay() {
        let parsed = LaunchArguments.parse(["-debugOverlay", "-seed", "42"])
        XCTAssertTrue(parsed.debugOverlay)
        XCTAssertEqual(parsed.seed, 42)
    }

    func testLaunchArgumentsParseScenario() {
        let parsed = LaunchArguments.parse(["-scenario", "tutorial"])
        XCTAssertEqual(parsed.scenario, "tutorial")
    }
}
