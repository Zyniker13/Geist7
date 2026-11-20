import XCTest

@testable import Rosette_macOS

/// RS-P8: `LaunchArguments` parsing — the UI-test launch knobs must accept
/// well-formed values and reject malformed or nonsensical ones ("-aiDelay"
/// keeps an autoPilot match incomplete across a relaunch; see the resume
/// perf test).
final class LaunchArgumentsUnitTests: XCTestCase {

    func testSeedParses() {
        let parsed = LaunchArguments.parse(["-seed", "42"])
        XCTAssertEqual(parsed.seed, 42)
        XCTAssertNil(parsed.aiDelay)
    }

    func testSeedRejectsMalformedValue() {
        XCTAssertNil(LaunchArguments.parse(["-seed", "abc"]).seed)
        XCTAssertNil(LaunchArguments.parse(["-seed"]).seed)
    }

    func testAIDelayParses() {
        let parsed = LaunchArguments.parse(["-aiDelay", "0.5"])
        XCTAssertEqual(parsed.aiDelay, 0.5)
        XCTAssertNil(parsed.seed)
    }

    func testAIDelayRejectsNonPositiveAndMalformed() {
        XCTAssertNil(LaunchArguments.parse(["-aiDelay", "0"]).aiDelay)
        XCTAssertNil(LaunchArguments.parse(["-aiDelay", "-1"]).aiDelay)
        XCTAssertNil(LaunchArguments.parse(["-aiDelay", "slow"]).aiDelay)
        XCTAssertNil(LaunchArguments.parse(["-aiDelay"]).aiDelay)
    }

    func testFlagsAndRegion() {
        let parsed = LaunchArguments.parse([
            "-daily", "-startMatch", "-region", "nineveh",
        ])
        XCTAssertTrue(parsed.daily)
        XCTAssertTrue(parsed.startMatch)
        XCTAssertEqual(parsed.region, "nineveh")
    }

    func testAccessibilityAndResumeFlags() {
        let parsed = LaunchArguments.parse(["-leftHanded", "-autoResume"])
        XCTAssertTrue(parsed.leftHanded)
        XCTAssertTrue(parsed.autoResume)
        XCTAssertFalse(LaunchArguments.parse([]).leftHanded)
        XCTAssertFalse(LaunchArguments.parse([]).autoResume)
    }

    func testEmptyArgumentsAreDefaults() {
        XCTAssertEqual(LaunchArguments.parse([]), LaunchArguments.Parsed())
    }
}
