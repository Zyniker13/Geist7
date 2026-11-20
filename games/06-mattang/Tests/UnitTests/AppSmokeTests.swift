// AppSmokeTests.swift — P0 smoke tests for the app target.

import XCTest

@testable import Mattang_macOS

final class AppSmokeTests: XCTestCase {
    func testLaunchArgumentsDefaultsFailClosed() {
        let parsed = LaunchArguments.parse([])
        XCTAssertFalse(parsed.startMatch)
        XCTAssertFalse(parsed.autoPilot)
        XCTAssertFalse(parsed.debugOverlay)
        XCTAssertNil(parsed.seed)
        XCTAssertNil(parsed.scenario)
        XCTAssertNil(parsed.snapshotPly)
    }

    func testNoTeachingNavigationStatement() {
        // The About statement matches docs/SOURCING.md §1 word for word
        // (MT-P0.1): no claim of teaching navigation.
        let expected =
            "Mattang is an abstract strategy game about reading swells, not a navigation trainer. Charts were memorised on land, not carried at sea."
        XCTAssertEqual(AboutText.noTeachingNavigation, expected)
    }
}
