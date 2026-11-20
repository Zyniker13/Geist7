import XCTest
@testable import RSCore
@testable import Rosette_macOS

// MARK: - Async bot decision tests (restored; P8 closeout claimed this file
// but it was never committed, so the regression coverage was missing).

/// The P8 frame-rate fix moves the bot's think off the main actor (RS-P8,
/// §7): `aiTurn` snapshots the state, runs `RosetteBot.chooseMove` in a
/// detached task, and lands the decision through `finishBotMove` with a
/// generation check. These tests pin the landing path and the discard guard.
@MainActor
final class AsyncBotDecisionUnitTests: XCTestCase {

    private func makeViewModel(seed: UInt64 = 7) -> GameViewModel {
        GameViewModel(
            stakeValue: 1,
            useAI: true,
            seed: seed,
            autoSave: false,
            opponentBot: RosetteBot(personality: .careful, strength: 1))
    }

    /// A decision stamped with a superseded generation is discarded: the
    /// human acted while the bot was thinking, so nothing may apply.
    func testStaleBotDecisionIsDiscarded() {
        let viewModel = makeViewModel()
        let playerBefore = viewModel.matchState.currentPlayer
        let rolledBefore = viewModel.matchState.hasRolled
        XCTAssertTrue(viewModel.aiThinking == false)

        viewModel.finishBotMove(
            nil,
            advancedRng: SeededRNG(seed: 1),
            generation: viewModel.actionGeneration &+ 1)

        XCTAssertEqual(viewModel.matchState.currentPlayer, playerBefore)
        XCTAssertEqual(viewModel.matchState.hasRolled, rolledBefore)
        XCTAssertFalse(viewModel.aiThinking)
    }

    /// A decision stamped with the current generation lands: the move
    /// applies and the match state advances.
    func testBotDecisionLandsAtCurrentGeneration() throws {
        let viewModel = makeViewModel()
        viewModel.rollDice()
        let move = try XCTUnwrap(viewModel.legalMoves.first)
        let generation = viewModel.actionGeneration
        let playerBefore = viewModel.matchState.currentPlayer
        let rolledBefore = viewModel.matchState.hasRolled
        let completeBefore = viewModel.matchState.isComplete

        viewModel.finishBotMove(
            move, advancedRng: SeededRNG(seed: 2), generation: generation)

        let advanced = viewModel.matchState.currentPlayer != playerBefore
            || viewModel.matchState.hasRolled != rolledBefore
            || viewModel.matchState.isComplete != completeBefore
        XCTAssertTrue(advanced, "a current-generation decision must apply")
        XCTAssertFalse(viewModel.aiThinking)
    }

    /// The full async chain: when the human's turn ends, the scheduled AI
    /// turn rolls, thinks off the main actor, and lands its move — play
    /// returns to the human (or the match completes) without a synchronous
    /// think blocking the main thread.
    func testBotTurnPlaysOutViaDetachedTask() async throws {
        let viewModel = makeViewModel()

        // Drive the human (player 0) side synchronously until the AI side
        // is to move. Each action the human takes schedules the AI chain.
        for _ in 0..<40 {
            guard !viewModel.matchState.isComplete else { return }
            guard viewModel.matchState.currentPlayer != .player1 else { break }
            if viewModel.matchState.doubleOffered {
                viewModel.declineDouble()
                continue
            }
            if !viewModel.matchState.hasRolled {
                viewModel.rollDice()
                continue
            }
            if let first = viewModel.legalMoves.first {
                viewModel.movePiece(first.piece)
            }
        }
        if viewModel.matchState.isComplete { return }
        XCTAssertEqual(
            viewModel.matchState.currentPlayer, .player1,
            "the AI side must be to move after the human's turn")

        // The AI chain (scheduled delay + detached think + landing hop)
        // runs on the main actor between our suspensions. Poll until the
        // turn comes back to the human or the match ends.
        var landed = false
        for _ in 0..<150 {
            try await Task.sleep(nanoseconds: 100_000_000)
            if viewModel.matchState.currentPlayer == .player0
                || viewModel.matchState.isComplete {
                landed = true
                break
            }
        }
        XCTAssertTrue(
            landed, "the bot's turn never completed within 15 s")
        XCTAssertFalse(viewModel.aiThinking)
    }
}
