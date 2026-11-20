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

    // RS-P10: screenshot-staging knobs.

    func testSnapshotPlyParses() {
        XCTAssertEqual(LaunchArguments.parse(["-snapshotPly", "45"]).snapshotPly, 45)
        XCTAssertEqual(LaunchArguments.parse(["-snapshotPly", "0"]).snapshotPly, 0)
        XCTAssertNil(LaunchArguments.parse([]).snapshotPly)
    }

    func testSnapshotPlyRejectsMalformedAndNegative() {
        XCTAssertNil(LaunchArguments.parse(["-snapshotPly", "abc"]).snapshotPly)
        XCTAssertNil(LaunchArguments.parse(["-snapshotPly", "-5"]).snapshotPly)
        XCTAssertNil(LaunchArguments.parse(["-snapshotPly", "4.5"]).snapshotPly)
        XCTAssertNil(LaunchArguments.parse(["-snapshotPly"]).snapshotPly)
    }

    func testCircuitFlagParses() {
        XCTAssertTrue(LaunchArguments.parse(["-circuit"]).circuit)
        XCTAssertFalse(LaunchArguments.parse([]).circuit)
    }

    /// "-snapshotPly" fast-forward must be deterministic: two matches built
    /// from the same seed and fast-forwarded the same amount reach identical
    /// match states (the whole point of the staging knob is a reproducible
    /// screenshot composition).
    @MainActor
    func testFastForwardIsDeterministicAcrossSeededMatches() {
        let first = GameViewModel(useAI: true, seed: 7, autoPilot: true)
        first.fastForward(plies: 40)
        let second = GameViewModel(useAI: true, seed: 7, autoPilot: true)
        second.fastForward(plies: 40)

        XCTAssertEqual(first.matchState, second.matchState)
        XCTAssertFalse(first.matchState.isComplete, "40 staged actions must leave seed 7 mid-match")
    }
}
