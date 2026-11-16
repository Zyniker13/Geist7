import XCTest

@testable import RSCore

/// R-7 (exact bear-off) and R-8 (win condition).
final class RulesBearOffWinTests: XCTestCase {
    func testR7_ExactRollBearsOff() throws {
        let start = TestSupport.state(
            dice: TestSupport.loaded(1),
            player0: [13, -1, -1, -1, -1, -1, -1],
            player1: Array(repeating: -1, count: 7)
        )
        let (moved, events) = try TestSupport.rollAndMove(start, diceSeed: 3)
        XCTAssertEqual(moved.pieces.first { $0.owner == .player0 && $0.id == 0 }?.position, -2)
        XCTAssertTrue(events.contains(Event.pieceBorneOff(piece: 0, player: .player0)))
    }

    func testR7_OffByOneStaysOnBoard() throws {
        let start = TestSupport.state(
            dice: TestSupport.loaded(1),
            player0: [12, -1, -1, -1, -1, -1, -1],
            player1: Array(repeating: -1, count: 7)
        )
        let moved = try TestSupport.rollAndMove(start, diceSeed: 3).state
        XCTAssertEqual(moved.pieces.first { $0.owner == .player0 && $0.id == 0 }?.position, 13)
        XCTAssertEqual(moved.borneOff[.player0], 0)
    }

    func testR7_OvershootIsIllegalUnderExactBearOff() {
        let start = TestSupport.state(
            player0: [10, -2, -2, -2, -2, -2, -2],
            player1: Array(repeating: -1, count: 7)
        )
        // 10 + 5 overshoots the 14-square path; exact bear-off forbids it and no
        // other piece can move.
        let moves = MoveGen.legalMoves(
            for: .player0, amount: 5, pieces: start.pieces, track: start.track, rules: start.ruleset
        )
        XCTAssertTrue(moves.isEmpty)
    }

    func testR7_InexactBearOffVariantOvershootBearsOff() {
        let ruleset = RuleSet(
            id: "inexact-bearoff",
            label: "Variant: overshoot bears off",
            trackLength: 14,
            pieces: 7,
            rosettes: [3, 7, 13],
            safeRosettes: [7],
            diceModel: "tetra4",
            exactBearOff: false,
            extraRollOnRosette: true,
            captureRule: .standard,
            moveGenerator: "ur",
            source: "Variant table",
            historyLabel: .invented
        )
        let state = TestSupport.state(
            ruleset: ruleset,
            player0: [10, -1, -1, -1, -1, -1, -1],
            player1: Array(repeating: -1, count: 7)
        )
        let moves = MoveGen.legalMoves(
            for: .player0, amount: 4, pieces: state.pieces, track: state.track, rules: ruleset)
        XCTAssertTrue(
            moves.contains(Move(piece: 0, destination: -1)), "overshoot bears off under the variant"
        )
        XCTAssertFalse(
            moves.contains { $0.destination == 13 }, "no partial landing on the last square")
    }

    func testR8_BearingOffAllPiecesWins() throws {
        let start = TestSupport.state(
            dice: TestSupport.loaded(1),
            player0: [13, -2, -2, -2, -2, -2, -2],
            player1: Array(repeating: -1, count: 7)
        )
        let (moved, events) = try TestSupport.rollAndMove(start, diceSeed: 3)
        XCTAssertTrue(moved.isComplete)
        XCTAssertEqual(moved.outcome?.winner, .player0)
        XCTAssertTrue(moved.outcome?.gammon ?? false, "loser has borne off nothing")
        XCTAssertTrue(events.contains(Event.matchWon(winner: .player0, gammon: true)))
    }

    func testR8_NonGammonOutcomeWhenLoserBoreOff() throws {
        let start = TestSupport.state(
            dice: TestSupport.loaded(1),
            player0: [13, -2, -2, -2, -2, -2, -2],
            player1: [-2, -1, -1, -1, -1, -1, -1]
        )
        let moved = try TestSupport.rollAndMove(start, diceSeed: 3).state
        XCTAssertTrue(moved.isComplete)
        XCTAssertEqual(moved.outcome?.gammon, false)
        // R-11: score is stake x cube without the gammon multiplier.
        XCTAssertEqual(moved.outcome?.score(for: .player0), 2)
    }

    func testR8_CompletedMatchRejectsFurtherActions() throws {
        let start = TestSupport.state(
            dice: TestSupport.loaded(1),
            player0: [13, -2, -2, -2, -2, -2, -2],
            player1: Array(repeating: -1, count: 7)
        )
        let moved = try TestSupport.rollAndMove(start, diceSeed: 3).state
        XCTAssertTrue(moved.isComplete)
        XCTAssertThrowsError(try TestSupport.apply(.roll, to: moved)) { error in
            guard case RuleError.matchComplete = error else {
                return XCTFail("expected matchComplete, got \(error)")
            }
        }
    }
}
