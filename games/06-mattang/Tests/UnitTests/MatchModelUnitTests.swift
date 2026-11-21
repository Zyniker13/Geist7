// MatchModelUnitTests.swift — S2.2 pause and flow semantics (macOS-hosted
// app unit bundle).

import Combine
import MTCore
import XCTest

@testable import Mattang_macOS

/// The MatchModel is @MainActor; these tests drive it on the main actor
/// and wait for its async AI tasks through XCTest expectations fed by
/// the published state, so the suite stays deterministic under machine
/// load without polling the wall clock.
@MainActor
final class MatchModelUnitTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        UserDefaults.standard.removeObject(forKey: MatchModel.saveKey)
    }

    // MARK: Helpers

    /// A fresh model on a fixed seed with a short AI delay.
    private func makeModel(seed: UInt64 = 7) -> MatchModel {
        MatchModel(seed: seed, aiDelay: 0.02, autoPilot: false, snapshotPly: nil)
    }

    /// The stable hash of the current state (identity here; GameState
    /// itself is not Equatable).
    private func hash(_ model: MatchModel) -> UInt64? {
        try? StateHashing.stableHash(model.state)
    }

    /// Drives the human's (player 1's) first move through the public
    /// input path: tap a legal placement cell to arm the preview, tap
    /// it again to commit. Returns true when a ply was committed.
    @discardableResult
    private func playHumanPlacement(_ model: MatchModel) -> Bool {
        XCTAssertEqual(model.state.toMove, .p1, "the human moves first")
        for cell in model.state.chart.ocean.allCells {
            model.tap(cell)
            if model.ghostIsland != nil {
                model.tap(cell)  // second tap on the ghost commits
                return model.plies > 0
            }
            model.cancelSelection()
        }
        return false
    }

    /// An expectation fulfilled when the published ply count advances
    /// beyond `baseline`; the subscription lives for the caller's
    /// scope. Combine's sink replays the current value, so the target
    /// is relative to the count at subscription time.
    private func plyExpectation(
        _ model: MatchModel, beyond baseline: Int, cancellables: inout Set<AnyCancellable>
    ) -> XCTestExpectation {
        let reached = expectation(description: "plies advance past \(baseline)")
        model.$plies.sink { plies in
            if plies > baseline { reached.fulfill() }
        }.store(in: &cancellables)
        return reached
    }

    // MARK: Pause state

    /// Toggling pause flips the published flag and pause can be
    /// cleared.
    func testTogglePauseFlipsFlag() {
        let model = makeModel()
        XCTAssertFalse(model.isPaused)
        model.togglePause()
        XCTAssertTrue(model.isPaused)
        model.togglePause()
        XCTAssertFalse(model.isPaused)
    }

    /// Pausing does not change the game: the state hash and ply count
    /// are identical before and after, including across a resume.
    func testPauseDoesNotMutateGameState() {
        let model = makeModel()
        let before = hash(model)
        model.togglePause()
        XCTAssertEqual(model.plies, 0)
        model.togglePause()
        XCTAssertEqual(hash(model), before)
    }

    /// Pausing on Sailor's turn cancels the pending AI move: nothing
    /// commits while paused, and resume restarts the AI scheduling.
    func testPauseOnAITurnHoldsAndResumeResumes() {
        let model = makeModel()
        var cancellables = Set<AnyCancellable>()
        XCTAssertTrue(playHumanPlacement(model))
        // The synchronous pause lands while the AI's task (0.02 s) is
        // still pending: commit → toggle, with no wait in between.
        model.togglePause()
        XCTAssertTrue(model.isPaused)
        XCTAssertEqual(model.state.toMove, .p2, "the AI side is to move")
        let frozen = hash(model)

        // While paused the AI must not advance the game: a short
        // expected-nothing wait must time out.
        XCTAssertEqual(
            XCTWaiter.wait(
                for: [plyExpectation(model, beyond: model.plies, cancellables: &cancellables)],
                timeout: 2),
            .timedOut,
            "paused AI must not move")
        XCTAssertEqual(hash(model), frozen)

        // Resume lets the AI move again.
        model.togglePause()
        wait(
            for: [plyExpectation(model, beyond: 1, cancellables: &cancellables)],
            timeout: 10)
        XCTAssertTrue(model.plies >= 2, "resume must let the AI move again")
    }

    /// Player taps are ignored while paused: no placement preview can
    /// be armed.
    func testTapIgnoredWhilePaused() {
        let model = makeModel()
        XCTAssertEqual(model.state.toMove, .p1, "the human moves first")
        model.togglePause()
        model.tap(Hex(0, 0))
        XCTAssertNil(model.ghostIsland, "a paused tap must not arm placement")
    }

    /// Restart while paused clears the pause and leaves a fresh match.
    func testRestartClearsPause() {
        let model = makeModel()
        model.togglePause()
        model.restart()
        XCTAssertFalse(model.isPaused)
        XCTAssertEqual(model.plies, 0)
    }

    /// Pause is transient across persistence (S2.4): the position
    /// committed while playing is saved, and a restored session comes
    /// back playing, never frozen behind a forgotten pause flag.
    func testPausedPositionResumesPlaying() {
        let model = makeModel()
        var cancellables = Set<AnyCancellable>()
        XCTAssertTrue(playHumanPlacement(model))
        wait(
            for: [plyExpectation(model, beyond: 1, cancellables: &cancellables)],
            timeout: 10)
        guard !model.isOver else { return }
        let pliesAtPause = model.plies
        model.togglePause()
        XCTAssertTrue(model.isPaused)

        // The public restore path: no -startMatch argument, so the
        // saved record drives the model.
        let restored = MatchModel.forCurrentLaunch()
        XCTAssertFalse(restored.isPaused)
        XCTAssertEqual(restored.plies, pliesAtPause)
    }

    // MARK: Full-match completion

    /// The Mac half of G2 check 1, SUBSTITUTED (issue #8: the macOS
    /// UI-test runner cannot initialize automation mode on this
    /// machine): the same auto-pilot match the Mac app drives plays to
    /// completion vs Sailor through MatchModel — the shared flow both
    /// platforms run. The iPad UI test (`testAutoPilotCompletesGameVsSailor`)
    /// pins the rendered half.
    func testAutoPilotMatchCompletesVsSailor() {
        let model = MatchModel(seed: 7, aiDelay: 0, autoPilot: true, snapshotPly: nil)
        var cancellables = Set<AnyCancellable>()
        let finished = expectation(description: "auto-pilot match completes")
        model.$state.sink { state in
            if state.status.isOver { finished.fulfill() }
        }.store(in: &cancellables)
        wait(for: [finished], timeout: 120)
        XCTAssertTrue(model.isOver, "auto-pilot completes the match vs Sailor")
    }
}
