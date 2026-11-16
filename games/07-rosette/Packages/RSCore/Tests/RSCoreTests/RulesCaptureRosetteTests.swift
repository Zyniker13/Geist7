import XCTest

@testable import RSCore

/// R-5 (captures), R-6/R-19 (rosette extra rolls), R-20 (variant safety).
final class RulesCaptureRosetteTests: XCTestCase {
    // MARK: R-5

    func testR5_CaptureOnSharedSquareSendsOpponentOffBoard() throws {
        let start = TestSupport.state(
            dice: TestSupport.loaded(3),
            player0: [5, -1, -1, -1, -1, -1, -1],
            player1: [8, -1, -1, -1, -1, -1, -1]
        )
        let (moved, events) = try TestSupport.rollAndMove(start, diceSeed: 3)
        let captured = moved.pieces.first { $0.owner == .player1 && $0.id == 0 }
        XCTAssertEqual(captured?.position, -1, "captured piece returns off-board to start")
        XCTAssertTrue(events.contains(Event.pieceCaptured(piece: 0, by: .player0)))
    }

    func testR5_CaptureOnCentralRosetteIsIllegal() throws {
        let start = TestSupport.state(
            player0: [5, -1, -1, -1, -1, -1, -1],
            player1: [7, -1, -1, -1, -1, -1, -1]
        )
        // A move onto the safe rosette held by the opponent must not be generated.
        let moves = MoveGen.legalMoves(
            for: .player0, amount: 2, pieces: start.pieces, track: start.track, rules: start.ruleset
        )
        XCTAssertFalse(moves.contains { $0.destination == 7 })
        // Forcing the move through the reducer still fails (R-5).
        var forced = start
        forced.diceValue = 2
        forced.hasRolled = true
        forced.movablePieceIds = [0]
        XCTAssertThrowsError(try TestSupport.apply(.move(0), to: forced)) { error in
            guard case RuleError.illegalAction = error else {
                return XCTFail("expected illegalAction, got \(error)")
            }
        }
    }

    func testR5_CapturedPieceReentersAtRollMinusOne() throws {
        var state = TestSupport.state(
            dice: TestSupport.loaded(3),
            player0: [5, -1, -1, -1, -1, -1, -1],
            player1: [8, -1, -1, -1, -1, -1, -1],
            currentPlayer: .player0
        )
        (state, _) = try TestSupport.rollAndMove(state, diceSeed: 3)
        // Player 0 captures player 1's piece at square 8.
        // Player 1 enters with a roll of 3 → step roll−1 = 2.
        let (entered, _) = try TestSupport.apply(.roll, to: state, diceSeed: 11)
        let (afterMove, _) = try TestSupport.apply(.move(0), to: entered, diceSeed: 11)
        let entering = afterMove.pieces.first { $0.owner == .player1 && $0.id == 0 }
        XCTAssertEqual(entering?.position, 2)
    }

    // MARK: R-6

    func testR6_LandingOnRosetteGrantsExtraRoll() throws {
        let start = TestSupport.state(
            dice: TestSupport.loaded(1),
            player0: [2, -1, -1, -1, -1, -1, -1],
            player1: Array(repeating: -1, count: 7)
        )
        let (moved, events) = try TestSupport.rollAndMove(start, diceSeed: 3)
        XCTAssertEqual(moved.currentPlayer, .player0, "rosette keeps the turn")
        XCTAssertFalse(moved.hasRolled, "the extra roll has not happened yet")
        XCTAssertTrue(events.contains(Event.rosetteLanded(player: .player0)))
    }

    func testR19_RosetteExtraRollChains() throws {
        // A variant with adjacent rosettes (indices 3 and 4) proves the extra
        // roll chains without a one-time limiter.
        var ruleset = TestSupport.finkelRuleset
        ruleset = RuleSet(
            id: ruleset.id,
            label: ruleset.label,
            trackLength: ruleset.trackLength,
            pieces: ruleset.pieces,
            rosettes: [3, 4, 13],
            safeRosettes: ruleset.safeRosettes,
            diceModel: ruleset.diceModel,
            exactBearOff: ruleset.exactBearOff,
            extraRollOnRosette: true,
            captureRule: ruleset.captureRule,
            moveGenerator: ruleset.moveGenerator,
            source: ruleset.source,
            historyLabel: ruleset.historyLabel
        )
        var state = TestSupport.state(
            ruleset: ruleset,
            dice: TestSupport.loaded(1),
            player0: [2, -1, -1, -1, -1, -1, -1],
            player1: Array(repeating: -1, count: 7)
        )
        // Move 2->3 (rosette), extra roll, move 3->4 (rosette), extra roll,
        // move 4->5. The player keeps the turn throughout.
        for expectedPosition in [3, 4, 5] {
            state = try TestSupport.rollAndMove(state, diceSeed: 3).state
            let mover = state.pieces.first { $0.owner == .player0 && $0.id == 0 }
            XCTAssertEqual(mover?.position, expectedPosition)
            if expectedPosition != 5 {
                XCTAssertEqual(state.currentPlayer, .player0)
                XCTAssertFalse(state.hasRolled)
            }
        }
        XCTAssertEqual(state.currentPlayer, .player1, "turn passes after the non-rosette landing")
    }

    // MARK: R-20

    func testR20_RosetteCaptureLegalityFollowsSafeRosettesData() {
        // A ruleset whose safeRosettes excludes a rosette allows capturing there.
        let ruleset = RuleSet(
            id: "finkel-unsafe-edge",
            label: "Variant with unsafe edge rosette",
            trackLength: 14,
            pieces: 7,
            rosettes: [3, 7, 13],
            safeRosettes: [],
            diceModel: "tetra4",
            exactBearOff: true,
            extraRollOnRosette: true,
            captureRule: .standard,
            moveGenerator: "ur",
            source: "Variant table",
            historyLabel: .invented
        )
        let state = TestSupport.state(
            ruleset: ruleset,
            player0: [2, -1, -1, -1, -1, -1, -1],
            player1: [3, -1, -1, -1, -1, -1, -1]
        )
        let moves = MoveGen.legalMoves(
            for: .player0, amount: 1, pieces: state.pieces, track: state.track, rules: ruleset)
        XCTAssertTrue(
            moves.contains { $0.destination == 3 },
            "rosette capture is legal when safeRosettes excludes it")
        let capture = Capture.check(
            landingOn: 3,
            targetPiece: state.pieces.first { $0.owner == .player1 },
            track: state.track,
            rules: ruleset
        )
        guard case .captured = capture else {
            return XCTFail("expected a capture, got \(capture)")
        }
    }
}
