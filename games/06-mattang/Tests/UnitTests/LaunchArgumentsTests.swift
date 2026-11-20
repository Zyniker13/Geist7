import XCTest

@testable import Mattang_macOS

final class LaunchArgumentsTests: XCTestCase {
    func testEmptyArgumentsParseToDefaults() {
        let parsed = LaunchArguments.parse([])
        XCTAssertEqual(parsed, LaunchArguments.Parsed())
    }

    func testFlagsAndValuesParse() {
        let parsed = LaunchArguments.parse([
            "-startMatch", "-seed", "42", "-autoPilot",
            "-scenario", "reef", "-snapshotPly", "7",
        ])
        XCTAssertTrue(parsed.startMatch)
        XCTAssertEqual(parsed.seed, 42)
        XCTAssertTrue(parsed.autoPilot)
        XCTAssertEqual(parsed.scenario, "reef")
        XCTAssertEqual(parsed.snapshotPly, 7)
    }

    func testMissingValueIsIgnored() {
        let parsed = LaunchArguments.parse(["-seed"])
        XCTAssertNil(parsed.seed)

        let trailing = LaunchArguments.parse(["-scenario"])
        XCTAssertNil(trailing.scenario)
    }

    func testUnknownArgumentsAreIgnored() {
        let parsed = LaunchArguments.parse(["-notAFlag", "-startMatch"])
        XCTAssertTrue(parsed.startMatch)
        XCTAssertEqual(parsed, LaunchArguments.parse(["-startMatch"]))
    }

    func testDebugOverlayFlagParses() {
        let parsed = LaunchArguments.parse(["-debugOverlay"])
        XCTAssertTrue(parsed.debugOverlay)
        XCTAssertEqual(LaunchArguments.parse([]), LaunchArguments.Parsed())
    }
}
