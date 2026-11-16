import XCTest

@testable import RSCore

/// R-3 entry regression tests: the roll carries the piece in, so it lands on
/// step roll−1 — sharing the normal landing rules (own-piece block at the
/// destination only, captures on non-safe rosettes, rosette extra roll).
///
/// These tests pin the corrected R-3 semantics (the solver, RoyalUr-verified,
/// enters at roll−1; see UrSolver and the P1 verification record). An earlier
/// reducer placed entries on step 0 and skipped capture/rosette handling
/// there; OddsTests' 200-state cross-check exposed the mismatch.
final class RulesEntryTests: XCTestCase {

    // MARK: - Landing square

    func testEntryLandsOnRollMinusOne() throws {
        // Loaded dice always roll 2: the entering piece lands on step 1.
        let state = TestSupport.state(
            dice: TestSupport.loaded(2),
            player0: [-1, -1, -1, -1, -1, -1, -1],
            player1: [-1, -1, -1, -1, -1, -1, -1]
        )
        let (rolled, _) = try TestSupport.apply(.roll, to: state)
        XCTAssertTrue(rolled.movablePieceIds.contains(0), "a waiting piece must be movable")
        let (moved, events) = try TestSupport.apply(.move(0), to: rolled)

        let piece = moved.pieces.first { $0.id == 0 && $0.owner == .player0 }
        XCTAssertEqual(piece?.position, 1, "entry must land on step roll−1 (=1 for a roll of 2)")
        XCTAssertTrue(
            events.contains {
                if case .pieceMoved(let id, let from, let to) = $0 {
                    return id == 0 && from == -1 && to == 1
                }
                return false
            })
    }

    func testRollOfOneEntersOnStepZero() throws {
        let state = TestSupport.state(
            dice: TestSupport.loaded(1),
            player0: [-1, -1, -1, -1, -1, -1, -1],
            player1: [-1, -1, -1, -1, -1, -1, -1]
        )
        let (rolled, _) = try TestSupport.apply(.roll, to: state)
        let (moved, _) = try TestSupport.apply(.move(0), to: rolled)
        XCTAssertEqual(
            moved.pieces.first { $0.id == 0 && $0.owner == .player0 }?.position, 0
        )
    }

    // MARK: - Entry captures (R-5)

    func testEntryCapturesOpponentOnEntrySquare() throws {
        // Opponent holds step 1; a roll of 2 carries the piece in onto it.
        let state = TestSupport.state(
            dice: TestSupport.loaded(2),
            player0: [-1, -1, -1, -1, -1, -1, -1],
            player1: [1, -1, -1, -1, -1, -1, -1]
        )
        let (rolled, _) = try TestSupport.apply(.roll, to: state)
        let (moved, events) = try TestSupport.apply(.move(0), to: rolled)

        XCTAssertTrue(
            events.contains {
                if case .pieceCaptured(let piece, let by) = $0 {
                    return piece == 0 && by == .player0
                }
                return false
            }, "entering onto an opponent-occupied square must capture")
        let captured = moved.pieces.first { $0.id == 0 && $0.owner == .player1 }
        XCTAssertEqual(captured?.position, -1, "the captured piece returns to waiting")
        let entrant = moved.pieces.first { $0.id == 0 && $0.owner == .player0 }
        XCTAssertEqual(entrant?.position, 1)
    }

    func testEntryOntoUnsafeRosetteCapturesOpponent() throws {
        // Step 3 is an unsafe rosette (Finkel: squares 4, 8, 14 one-based).
        // Entering onto it with a roll of 4 captures an opponent piece there.
        let base = TestSupport.state(
            player0: [-1, -1, -1, -1, -1, -1, -1],
            player1: [-1, -1, -1, -1, -1, -1, -1]
        )
        guard base.track.rosetteIndices.contains(3) else {
            return XCTFail("Finkel track should have a rosette at step 3")
        }
        guard !base.track.safeRosetteIndices.contains(3) else {
            return XCTFail("Step 3 should not be a safe rosette for this test")
        }
        let state = TestSupport.state(
            dice: TestSupport.loaded(4),
            player0: [-1, -1, -1, -1, -1, -1, -1],
            player1: [3, -1, -1, -1, -1, -1, -1]
        )
        let (rolled, _) = try TestSupport.apply(.roll, to: state)
        let (moved, events) = try TestSupport.apply(.move(0), to: rolled)

        XCTAssertTrue(
            events.contains {
                if case .pieceCaptured(let piece, let by) = $0 {
                    return piece == 0 && by == .player0
                }
                return false
            }, "entering onto an unsafe rosette held by the opponent must capture")
        let captured = moved.pieces.first { $0.id == 0 && $0.owner == .player1 }
        XCTAssertEqual(captured?.position, -1)
        let entrant = moved.pieces.first { $0.id == 0 && $0.owner == .player0 }
        XCTAssertEqual(entrant?.position, 3)
    }

    // MARK: - Entry onto a rosette grants another roll (R-6, solver parity)

    func testEntryOntoRosetteGrantsExtraRoll() throws {
        // Step 3 is a rosette (Finkel: squares 4, 8, 14 one-based): entering
        // onto it with a roll of 4 grants another roll.  The reducer applies
        // .roll (computes moves) then .move (executes); extraRoll then
        // requires another .roll + .move pair.
        let base = TestSupport.state(
            player0: [-1, -1, -1, -1, -1, -1, -1],
            player1: [-1, -1, -1, -1, -1, -1, -1]
        )
        guard base.track.rosetteIndices.contains(3) else {
            return XCTFail("Finkel track should have a rosette at step 3")
        }
        let state = TestSupport.state(
            dice: TestSupport.loaded(4),
            player0: [-1, -1, -1, -1, -1, -1, -1],
            player1: [-1, -1, -1, -1, -1, -1, -1]
        )
        // First roll: entry to 3 (rosette), extraRoll = true.
        let (rolled, events1) = try TestSupport.apply(.roll, to: state)
        XCTAssertTrue(rolled.movablePieceIds.contains(0))
        let (moved, events2) = try TestSupport.apply(.move(0), to: rolled)
        // The engine resets extraRoll to false before returning (so the next
        // .roll doesn't see it), but leaves hasRolled = false and diceValue =
        // nil — the state is ready for another roll.
        XCTAssertFalse(moved.hasRolled, "extra-roll leaves hasRolled = false")
        XCTAssertNil(moved.diceValue, "extra-roll leaves diceValue = nil")
        XCTAssertEqual(
            moved.pieces.first { $0.id == 0 && $0.owner == .player0 }?.position, 3
        )
        XCTAssertTrue(
            events2.contains {
                if case .rosetteLanded(let player) = $0 { return player == .player0 }
                return false
            }, "entering onto a rosette must grant another roll (R-6)")

        // Second roll: piece at 3 + 4 = 7.
        let (rolled2, _) = try TestSupport.apply(.roll, to: moved)
        let (final, _) = try TestSupport.apply(.move(0), to: rolled2)
        XCTAssertEqual(
            final.pieces.first { $0.id == 0 && $0.owner == .player0 }?.position, 7
        )
    }

    // MARK: - Entry blocking (R-4)

    func testEntryBlockedByOwnPieceOnEntrySquare() throws {
        // Own piece holds step 1; a roll of 2 cannot enter (R-4: a piece
        // cannot land on a square held by its own piece).  The other pieces
        // are placed where they cannot move with a roll of 2 (position 13
        // bears off only on 1; roll 2 is illegal under exact bear-off).
        let state = TestSupport.state(
            dice: TestSupport.loaded(2),
            player0: [-1, 1, 13, -1, -1, -1, -1],
            player1: [-1, -1, -1, -1, -1, -1, -1]
        )
        let (rolled, _) = try TestSupport.apply(.roll, to: state)
        XCTAssertTrue(
            rolled.movablePieceIds.contains(1),
            "piece at square 1 can move to square 3")
        XCTAssertTrue(
            !rolled.movablePieceIds.contains(0),
            "entry move for piece 0 is blocked by own piece at square 1")
    }

    func testDebugRosetteExtraRoll() throws {
        let state = TestSupport.state(
            dice: TestSupport.loaded(4),
            player0: [-1, -1, -1, -1, -1, -1, -1],
            player1: [-1, -1, -1, -1, -1, -1, -1]
        )
        let (rolled, _) = try TestSupport.apply(.roll, to: state)
        let (moved, _) = try TestSupport.apply(.move(0), to: rolled)
        // Extra-roll leaves hasRolled = false and diceValue = nil so the
        // caller can issue a second .roll.
        XCTAssertFalse(moved.hasRolled, "extra-roll leaves hasRolled = false")
        XCTAssertNil(moved.diceValue, "extra-roll leaves diceValue = nil")
    }
}
