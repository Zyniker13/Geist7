// RSPlatform — haptic feedback tests (RS-P8.4).

import RSCore
import XCTest

@testable import RSPlatform

/// A player that records the feedback it was asked to play.
@MainActor
private final class RecordingHapticPlayer: HapticPlaying {
    private(set) var captures = 0
    private(set) var matchEnds = 0

    func captureOccurred() { captures += 1 }
    func matchEnded() { matchEnds += 1 }
}

@MainActor
final class HapticFeedbackTests: XCTestCase {
    private var suiteName: String?
    private var defaults: UserDefaults?

    /// A fresh isolated defaults suite per test (unique name, removed in
    /// tearDown) — no force unwraps, no cross-test persistence.
    private func makeIsolatedDefaults() throws -> UserDefaults {
        let name = "test-haptics-\(ProcessInfo.processInfo.globallyUniqueString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        suiteName = name
        self.defaults = defaults
        return defaults
    }

    override func tearDown() {
        if let suiteName {
            UserDefaults().removePersistentDomain(forName: suiteName)
        }
        suiteName = nil
        defaults = nil
        super.tearDown()
    }

    func testEnabledDefaultsToOn() throws {
        let defaults = try makeIsolatedDefaults()
        XCTAssertTrue(HapticPreferences(defaults: defaults).isEnabled)
    }

    func testDisabledPersists() throws {
        let defaults = try makeIsolatedDefaults()
        let preferences = HapticPreferences(defaults: defaults)
        preferences.isEnabled = false
        XCTAssertFalse(HapticPreferences(defaults: defaults).isEnabled)
    }

    func testRouterPlaysCaptureAndMatchEndWhenEnabled() throws {
        let defaults = try makeIsolatedDefaults()
        let player = RecordingHapticPlayer()
        let router = HapticsRouter(
            preferences: HapticPreferences(defaults: defaults),
            player: player)

        router.handle(events: [
            .diceRolled(value: 2),
            .pieceMoved(piece: 0, from: 3, to: 4),
            .pieceCaptured(piece: 3, by: .player0),
            .rosetteLanded(player: .player0),
            .matchWon(winner: .player0, gammon: false),
        ])

        XCTAssertEqual(player.captures, 1, "exactly one capture impact")
        XCTAssertEqual(player.matchEnds, 1, "exactly one match-end notification")
    }

    func testRouterIsSilentWhenDisabled() throws {
        let defaults = try makeIsolatedDefaults()
        let player = RecordingHapticPlayer()
        let preferences = HapticPreferences(defaults: defaults)
        preferences.isEnabled = false
        let router = HapticsRouter(preferences: preferences, player: player)

        router.handle(events: [
            .pieceCaptured(piece: 3, by: .player1),
            .matchWon(winner: .player1, gammon: true),
        ])

        XCTAssertEqual(player.captures, 0, "no haptics while disabled")
        XCTAssertEqual(player.matchEnds, 0, "no haptics while disabled")
    }

    func testRouterIgnoresUnmappedEvents() throws {
        let defaults = try makeIsolatedDefaults()
        let player = RecordingHapticPlayer()
        let router = HapticsRouter(
            preferences: HapticPreferences(defaults: defaults),
            player: player)

        router.handle(events: [
            .diceRolled(value: 4),
            .stakeSet(value: 2),
            .turnPassed,
        ])

        XCTAssertEqual(player.captures, 0)
        XCTAssertEqual(player.matchEnds, 0)
    }

    func testNoopPlayerIsInert() {
        let player = NoopHapticPlayer()
        player.captureOccurred()
        player.matchEnded()
    }
}
