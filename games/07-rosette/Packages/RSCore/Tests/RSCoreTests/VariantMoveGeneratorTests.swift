import XCTest

@testable import RSCore

/// RS-P1.3: the ruleset data model drives variant move generation. The
/// Senet-like generator blocks on any occupied square and forbids jumping;
/// the Patolli-like generator allows own-piece stacking and captures.
final class VariantMoveGeneratorTests: XCTestCase {
    private func senetRuleset() -> RuleSet {
        RuleSet(
            id: "senet-like",
            label: "Senet-like variant",
            trackLength: 14,
            pieces: 7,
            rosettes: [3, 7, 13],
            safeRosettes: [7],
            diceModel: "tetra4",
            exactBearOff: true,
            extraRollOnRosette: false,
            captureRule: .none,
            moveGenerator: "senet-like",
            source: "Variant table",
            historyLabel: .invented
        )
    }

    private func patolliRuleset() -> RuleSet {
        RuleSet(
            id: "patolli-like",
            label: "Patolli-like variant",
            trackLength: 14,
            pieces: 7,
            rosettes: [3, 7, 13],
            safeRosettes: [7],
            diceModel: "tetra4",
            exactBearOff: true,
            extraRollOnRosette: true,
            captureRule: .standard,
            moveGenerator: "patolli-like",
            source: "Variant table",
            historyLabel: .invented
        )
    }

    func testRS13_GeneratorDispatchFollowsTheRuleset() {
        XCTAssertTrue(MoveGen.generator(for: "ur") is UrMoveGenerator)
        XCTAssertTrue(MoveGen.generator(for: "senet-like") is SenetLikeMoveGenerator)
        XCTAssertTrue(MoveGen.generator(for: "patolli-like") is PatolliLikeMoveGenerator)
        XCTAssertTrue(
            MoveGen.generator(for: "unknown-id") is UrMoveGenerator, "unknown ids fall back to Ur")
    }

    func testRS13_SenetLikeCannotLandOnAnyOccupiedSquare() {
        let ruleset = senetRuleset()
        let state = TestSupport.state(
            ruleset: ruleset,
            player0: [5, -2, -2, -2, -2, -2, -2],
            player1: [6, -1, -1, -1, -1, -1, -1]
        )
        // Roll of 1: square 6 is occupied by the opponent — Senet-like forbids
        // the move entirely (no captures).
        let moves = MoveGen.legalMoves(
            for: .player0, amount: 1, pieces: state.pieces, track: state.track, rules: ruleset)
        XCTAssertTrue(moves.isEmpty)
    }

    func testRS13_SenetLikeCannotJumpOverPieces() {
        let ruleset = senetRuleset()
        let state = TestSupport.state(
            ruleset: ruleset,
            player0: [4, -2, -2, -2, -2, -2, -2],
            player1: [5, -1, -1, -1, -1, -1, -1]
        )
        // Roll of 2: the destination 6 is free but the path crosses 5, which is
        // occupied — Senet-like forbids the jump.
        let moves = MoveGen.legalMoves(
            for: .player0, amount: 2, pieces: state.pieces, track: state.track, rules: ruleset)
        XCTAssertTrue(moves.isEmpty)
    }

    func testRS13_SenetLikeMovesThroughClearPath() {
        let ruleset = senetRuleset()
        let state = TestSupport.state(
            ruleset: ruleset,
            player0: [4, -2, -2, -2, -2, -2, -2],
            player1: [9, -1, -1, -1, -1, -1, -1]
        )
        let moves = MoveGen.legalMoves(
            for: .player0, amount: 2, pieces: state.pieces, track: state.track, rules: ruleset)
        XCTAssertEqual(moves, [Move(piece: 0, destination: 6)])
    }

    func testRS13_PatolliLikeStacksOwnPieces() {
        let ruleset = patolliRuleset()
        let state = TestSupport.state(
            ruleset: ruleset,
            player0: [5, 6, -2, -2, -2, -2, -2],
            player1: Array(repeating: -1, count: 7)
        )
        // Roll of 1: landing on the own piece at 6 is legal (stacking).
        let moves = MoveGen.legalMoves(
            for: .player0, amount: 1, pieces: state.pieces, track: state.track, rules: ruleset)
        XCTAssertTrue(moves.contains(Move(piece: 0, destination: 6)))
    }

    func testRS13_PatolliLikeCapturesOpponent() {
        let ruleset = patolliRuleset()
        let state = TestSupport.state(
            ruleset: ruleset,
            player0: [5, -2, -2, -2, -2, -2, -2],
            player1: [6, -1, -1, -1, -1, -1, -1]
        )
        let moves = MoveGen.legalMoves(
            for: .player0, amount: 1, pieces: state.pieces, track: state.track, rules: ruleset)
        XCTAssertTrue(moves.contains(Move(piece: 0, destination: 6)))
        let capture = Capture.check(
            landingOn: 6,
            targetPiece: state.pieces.first { $0.owner == .player1 },
            track: state.track,
            rules: ruleset
        )
        guard case .captured = capture else {
            return XCTFail("expected a capture, got \(capture)")
        }
    }

    func testRS13_PatolliLikeMatchPlaysToCompletion() throws {
        // The data model drives a full variant match through the same reducer.
        let record = try RandomMatch.play(
            seed: 77,
            ruleset: patolliRuleset(),
            dice: .tetra4,
            stake: 2
        )
        XCTAssertTrue(record.finalState.isComplete)
        XCTAssertTrue(record.finalState.pieceConservationValid)
    }
}
