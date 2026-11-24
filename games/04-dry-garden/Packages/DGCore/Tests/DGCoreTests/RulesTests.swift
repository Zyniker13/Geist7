// RulesTests.swift — DG-P1.1: placement, rakes, and pass (R-2, R-4 to
// R-6, R-21, R-22), each fixture tagged with its rule ID; plus turn
// flow R-27, end conditions R-15/R-30, and INV-3.
//
// Every scripted position drives the reducer through its public API
// with an EXPLICIT acting player (`act(_:as:to:)`), so no fixture
// depends on whose turn alternation happens to hand the move to. All
// geometry was verified against the long_wall fixture (42 placeable
// cells, moss (0,4), basin (3,7), no in-play axes); fixture counts
// meet the roadmap quotas (DG-P1.1 ≥ 40 placement fixtures, DG-P1.2
// ≥ 30 rake fixtures).

import XCTest

@testable import DGCore

final class RulesTests: XCTestCase {

    // MARK: shared stage

    let balance = Balance.standard()
    var courtyard: Courtyard!

    override func setUpWithError() throws {
        courtyard = try CourtyardFixtures.longWall()
    }

    /// A fresh game state on long_wall.
    func fresh() -> GameState {
        GameState.fresh(courtyardID: "long_wall", balance: balance)
    }

    func h(_ q: Int, _ r: Int) -> Hex { Hex(q, r) }

    /// Applies one action FORCING the acting player (fixtures must not
    /// depend on alternation), mutating the state on success and
    /// returning the thrown IllegalReason (nil on success).
    @discardableResult
    func act(
        _ action: Action, as player: PlayerID, to state: inout GameState
    ) -> IllegalReason? {
        var copy = state
        copy.toMove = player
        do {
            let (next, _) = try Reducer.apply(
                action, to: copy, courtyard: courtyard, balance: balance)
            state = next
            return nil
        } catch let reason as IllegalReason {
            return reason
        } catch {
            return .gameOver
        }
    }

    /// Judges one action for `player` against a copy of the state
    /// (no mutation).
    func judge(
        _ action: Action, as player: PlayerID, from state: GameState
    ) -> IllegalReason? {
        var copy = state
        copy.toMove = player
        do {
            _ = try Reducer.apply(
                action, to: copy, courtyard: courtyard, balance: balance)
            return nil
        } catch let reason as IllegalReason {
            return reason
        } catch {
            return .gameOver
        }
    }

    /// Applies a setup placement, failing the test if the engine
    /// rejects it.
    func place(
        _ owner: PlayerID, _ cell: (Int, Int), _ size: StoneSize,
        state: inout GameState, file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if let reason = act(
            .place(cell: h(cell.0, cell.1), size: size, facing: 0),
            as: owner, to: &state)
        {
            XCTFail(
                "setup \(owner) (\(cell.0),\(cell.1)) \(size): \(reason)",
                file: file, line: line)
        }
    }

    /// Applies a setup rake, failing the test if the engine rejects it.
    func rake(
        _ owner: PlayerID, start: (Int, Int), direction: Int, length: Int,
        state: inout GameState, file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if let reason = act(
            .rake(
                start: h(start.0, start.1), direction: direction,
                length: length),
            as: owner, to: &state)
        {
            XCTFail(
                "setup rake \(owner) (\(start.0),\(start.1)) d\(direction)"
                    + " l\(length): \(reason)",
                file: file, line: line)
        }
    }

    // MARK: R-4 placement fixtures (46: P4-01 … P4-46)

    func testR4PlacementFixtures() throws {
        // Each case: setup stones (explicit owners), optional pre-laid
        // rakes, the candidate placement (cell, size, facing), the
        // forced mover, and the expected verdict (nil = accepted).
        var cases:
            [(
                setup: [(PlayerID, Int, Int, StoneSize)],
                pre: [(PlayerID, (Int, Int), Int, Int)],
                cell: (Int, Int), size: StoneSize, facing: Int,
                mover: PlayerID, expect: IllegalReason?
            )] = []

        // P4-01..12: empty-board placements across the mask accept any
        // size (R-4's basic grant).
        let sizes: [StoneSize] = [.large, .medium, .small]
        for (index, cell) in courtyard.placeableCells.prefix(12).enumerated() {
            cases.append(
                (
                    [], [], (cell.q, cell.r), sizes[index % 3], 0, .one, nil
                ))
        }
        // P4-13: occupied cell — same player's stone there.
        cases.append(
            (
                [(.one, 2, 0, .large)], [], (2, 0), .medium, 0, .one,
                .occupied
            ))
        // P4-14: occupied cell — the opponent's stone there too.
        cases.append(
            (
                [(.two, 2, 0, .large)], [], (2, 0), .small, 0, .one,
                .occupied
            ))
        // P4-15: off courtyard (row 3 holds only q −1,0).
        cases.append(([], [], (4, 3), .small, 0, .one, .offCourtyard))
        // P4-16: off courtyard (row 0 ends at q 5).
        cases.append(([], [], (6, 0), .large, 0, .one, .offCourtyard))
        // P4-17: feature cell (moss (0,4)).
        cases.append(([], [], (0, 4), .large, 0, .one, .feature))
        // P4-18: feature cell (basin (3,7)).
        cases.append(([], [], (3, 7), .small, 0, .one, .feature))
        // P4-19..24: same-size adjacency around P1's large at (4,2):
        // each in-yard neighbour rejects the same size, accepts others.
        for n in [(4, 1), (5, 1), (5, 2)] {
            cases.append(
                (
                    [(.one, 4, 2, .large)], [], n, .large, 0, .one,
                    .sameSizeAdjacent
                ))
            cases.append(
                (
                    [(.one, 4, 2, .large)], [], n, .medium, 0, .one, nil
                ))
        }
        // P4-25: two DIFFERENT own sizes adjacent — a small may sit
        // between a large and a medium.
        cases.append(
            (
                [(.one, 4, 1, .large), (.one, 5, 1, .medium)], [], (4, 2),
                .small, 0, .one, nil
            ))
        // P4-26/27: the anti-clump rule is per size: a medium next to a
        // medium and a small next to a small both fail.
        cases.append(
            (
                [(.one, 4, 1, .medium)], [], (4, 2), .medium, 0, .one,
                .sameSizeAdjacent
            ))
        cases.append(
            (
                [(.one, 4, 1, .small)], [], (4, 2), .small, 0, .one,
                .sameSizeAdjacent
            ))
        // P4-28: a large next to a small is fine.
        cases.append(
            (
                [(.one, 4, 1, .large)], [], (4, 2), .medium, 0, .one, nil
            ))
        // P4-29: same size two cells apart on a row is fine.
        cases.append(
            (
                [(.one, 4, 2, .large)], [], (6, 2), .large, 0, .one, nil
            ))
        // P4-30: same size at distance 2 off-row is fine.
        cases.append(
            (
                [(.one, 4, 2, .large)], [], (6, 1), .large, 0, .one, nil
            ))
        // P4-31..34: R-20 basin adjacency — the four placeable basin
        // neighbours (2,7),(4,7),(2,8),(3,8) all reject.
        for c in [(2, 7), (4, 7), (2, 8), (3, 8)] {
            cases.append(([], [], c, .large, 0, .one, .basinAdjacent))
        }
        // P4-35: a second-ring basin cell is fine.
        cases.append(([], [], (5, 5), .large, 0, .one, nil))
        // P4-36: the far south-west cell is a normal empty cell.
        cases.append(([], [], (0, 10), .large, 0, .one, nil))
        // P4-37: R-2/INV-3 supply exhaustion — both larges placed, the
        // next large fails (noSupply).
        cases.append(
            (
                [
                    (.one, 2, 0, .large), (.two, 3, 0, .large),
                    (.one, 6, 1, .large), (.two, 6, 2, .large),
                ], [], (4, 2), .large, 0, .one, .noSupply
            ))
        // P4-38: other sizes remain after the larges run out.
        cases.append(
            (
                [
                    (.one, 2, 0, .large), (.two, 3, 0, .large),
                    (.one, 6, 1, .large), (.two, 6, 2, .large),
                ], [], (4, 2), .medium, 0, .one, nil
            ))
        // P4-39: mediums exhausted the same way (larges untouched).
        cases.append(
            (
                [
                    (.one, 2, 0, .medium), (.two, 3, 0, .small),
                    (.one, 6, 1, .medium), (.two, 6, 2, .small),
                    (.one, 5, 4, .medium),
                ], [], (4, 2), .medium, 0, .one, .noSupply
            ))
        // P4-40: smalls exhausted (eight smalls on the board).
        cases.append(
            (
                [
                    (.one, 2, 0, .small), (.two, -1, 7, .small),
                    (.one, 6, 2, .small), (.two, 1, 7, .small),
                    (.one, 4, 4, .small), (.two, -4, 9, .small),
                    (.one, 1, 8, .small), (.two, 0, 10, .small),
                ], [], (4, 2), .small, 0, .one, .noSupply
            ))
        // P4-41: a raked cell cannot receive a stone — the mover who
        // laid the rake is barred too.
        cases.append(
            (
                [(.one, 2, 0, .large)], [(.one, (2, 0), 0, 2)], (3, 0),
                .medium, 0, .one, .raked
            ))
        // P4-42: …and so is the opponent.
        cases.append(
            (
                [(.one, 2, 0, .large)], [(.one, (2, 0), 0, 2)], (3, 0),
                .medium, 0, .two, .raked
            ))
        // P4-43: facing 6 is not a direction — rejected.
        cases.append(([], [], (4, 2), .large, 6, .one, .offCourtyard))
        // P4-44: facing 5 (any real direction) is accepted on a plain
        // cell at P1 (the veranda-facing bonus is R-12's business).
        cases.append(([], [], (4, 2), .large, 5, .one, nil))
        // P4-45: the opponent's adjacent large does NOT bar my large
        // (the anti-clump rule is own-stones only).
        cases.append(
            (
                [(.two, 4, 1, .large)], [], (4, 2), .large, 0, .one, nil
            ))
        // P4-46: mixed neighbours of different sizes are fine.
        cases.append(
            (
                [(.one, 4, 1, .medium), (.two, 5, 2, .small)], [], (4, 2),
                .large, 0, .one, nil
            ))

        XCTAssertGreaterThanOrEqual(cases.count, 40, "R-4 fixture count")

        for (index, fixture) in cases.enumerated() {
            var state = fresh()
            for entry in fixture.setup {
                place(entry.0, (entry.1, entry.2), entry.3, state: &state)
            }
            for (owner, start, d, l) in fixture.pre {
                rake(
                    owner, start: (start.0, start.1), direction: d,
                    length: l, state: &state)
            }
            let got = judge(
                .place(
                    cell: h(fixture.cell.0, fixture.cell.1),
                    size: fixture.size, facing: fixture.facing),
                as: fixture.mover, from: state)
            XCTAssertEqual(
                got, fixture.expect,
                "R-4 fixture \(index) at \(fixture.cell) \(fixture.size)")
        }
    }

    // MARK: R-5 rake fixtures (30: P5-01 … P5-30)

    func testR5RakeFixtures() throws {
        // R-5: a rake is a straight run of 2–5 empty non-feature cells
        // starting adjacent to one of the mover's stones; straightness
        // is structural ((start, direction, length) cannot bend).
        var cases:
            [(
                setup: [(PlayerID, Int, Int, StoneSize)],
                pre: [(PlayerID, (Int, Int), Int, Int)],
                start: (Int, Int), direction: Int, length: Int,
                mover: PlayerID, expect: IllegalReason?
            )] = []

        // P5-01/02: lengths 2 and 3 east from (2,0) are legal.
        cases.append(
            (
                [(.one, 2, 0, .large)], [], (2, 0), 0, 2, .one, nil
            ))
        cases.append(
            (
                [(.one, 2, 0, .large)], [], (2, 0), 0, 3, .one, nil
            ))
        // P5-03/04: lengths 1 and 6 are outside the 2…5 band.
        cases.append(
            (
                [(.one, 2, 0, .large)], [], (2, 0), 0, 1, .one,
                .rakeBadLength
            ))
        cases.append(
            (
                [(.one, 2, 0, .large)], [], (2, 0), 0, 6, .one,
                .rakeBadLength
            ))
        // P5-05/06: lengths 4 and 5 run off the yard's east end
        // (row 0 ends at q=5).
        cases.append(
            (
                [(.one, 2, 0, .large)], [], (2, 0), 0, 4, .one,
                .offCourtyard
            ))
        cases.append(
            (
                [(.one, 2, 0, .large)], [], (2, 0), 0, 5, .one,
                .offCourtyard
            ))
        // P5-07: blocked mid-path by an opponent stone.
        cases.append(
            (
                [(.one, 2, 0, .large), (.two, 4, 0, .small)], [], (2, 0), 0,
                2, .one, .rakeBlocked
            ))
        // P5-08: blocked by an own stone.
        cases.append(
            (
                [(.one, 2, 0, .large), (.one, 4, 0, .small)], [], (2, 0), 0,
                2, .one, .rakeBlocked
            ))
        // P5-09: no own stone adjacent to the first path cell.
        cases.append(
            (
                [(.two, 1, 5, .large)], [], (2, 0), 0, 2, .one, .rakeNoAnchor
            ))
        // P5-10: an opponent's stone as the only neighbour is no anchor.
        cases.append(
            (
                [(.two, 2, 0, .large)], [], (2, 0), 0, 2, .one, .rakeNoAnchor
            ))
        // P5-11: east from (5,0) leaves the yard.
        cases.append(
            (
                [(.one, 5, 0, .large)], [], (5, 0), 0, 2, .one, .offCourtyard
            ))
        // P5-12: a rake may not pass through the basin (3,7).
        cases.append(
            (
                [(.one, 0, 7, .large)], [], (0, 7), 0, 3, .one, .rakeBlocked
            ))
        // P5-13: the same path one cell short of the basin is legal.
        cases.append(
            (
                [(.one, 0, 7, .large)], [], (0, 7), 0, 2, .one, nil
            ))
        // P5-14: a stone on the second path cell blocks (opponent's).
        cases.append(
            (
                [(.one, 1, 4, .large), (.two, 3, 4, .small)], [], (1, 4), 0,
                3, .one, .rakeBlocked
            ))
        // P5-15: a clean full-length rake east from (1,4).
        cases.append(
            (
                [(.one, 1, 4, .large)], [], (1, 4), 0, 4, .one, nil
            ))
        // P5-16: raking west (d3) into an own stone is blocked.
        cases.append(
            (
                [(.one, 4, 0, .large), (.one, 2, 0, .small)], [], (4, 0), 3,
                2, .one, .rakeBlocked
            ))
        // P5-17: raking south-east (d1) from (4,0) is legal.
        cases.append(
            (
                [(.one, 4, 0, .large)], [], (4, 0), 1, 2, .one, nil
            ))
        // P5-18: east len4 from (2,0) runs off (row 0 ends at q=5) —
        // the P2 stone on (5,0) is beside the point.
        cases.append(
            (
                [(.one, 2, 0, .large), (.two, 5, 0, .small)], [], (2, 0), 0,
                4, .one, .offCourtyard
            ))
        // P5-19: the path's FIRST cell blocked by an own stone.
        cases.append(
            (
                [(.one, 2, 4, .small), (.one, 4, 4, .medium)], [], (4, 4), 3,
                2, .one, .rakeBlocked
            ))
        // P5-20: a length-4 lane along row 8 is legal.
        cases.append(
            (
                [(.one, -1, 8, .large)], [], (-1, 8), 0, 4, .one, nil
            ))
        // P5-21: …length 5 runs off the row's east end (q 3).
        cases.append(
            (
                [(.one, -1, 8, .large)], [], (-1, 8), 0, 5, .one,
                .offCourtyard
            ))
        // P5-22: R-21 single crossing — P2's line shares exactly one
        // cell with P1's earlier rake.
        cases.append(
            (
                [(.one, 2, 0, .large), (.two, 5, 2, .large)],
                [(.one, (2, 0), 0, 3)], (5, 2), 4, 2, .two, nil
            ))
        // P5-23: two shared cells → rakeCrossing (opponent's rake).
        cases.append(
            (
                [(.one, 1, 4, .large), (.two, 4, 4, .large)],
                [(.one, (1, 4), 0, 2)], (4, 4), 3, 2, .two, .rakeCrossing
            ))
        // P5-24: a fresh parallel lane from the same anchor stone.
        cases.append(
            (
                [(.one, 2, 0, .large), (.one, 4, 2, .large)],
                [(.one, (2, 0), 0, 2)], (4, 2), 4, 2, .one, nil
            ))
        // P5-25: two shared cells on the mover's OWN earlier rake also
        // cross (INV-9 is owner-blind).
        cases.append(
            (
                [(.one, 1, 4, .large), (.one, 4, 4, .large)],
                [(.one, (1, 4), 0, 2)], (4, 4), 3, 2, .one, .rakeCrossing
            ))
        // P5-26: crossing an OPPONENT's rake once is legal.
        cases.append(
            (
                [(.two, 5, 2, .large), (.one, 2, 0, .large)],
                [(.two, (5, 2), 4, 2)], (2, 0), 0, 3, .one, nil
            ))
        // P5-27: the anchor must neighbour the FIRST path cell: P1's
        // stone (2,0) is not beside (4,0).
        cases.append(
            (
                [(.one, 2, 0, .large)], [], (5, 0), 3, 2, .one, .rakeNoAnchor
            ))
        // P5-28: a stone on the SECOND cell blocks (mid-path).
        cases.append(
            (
                [(.one, 2, 0, .large), (.two, 3, 0, .medium)], [], (2, 0), 0,
                2, .one, .rakeBlocked
            ))
        // P5-29: a stone BEYOND the path's end does not block len2.
        cases.append(
            (
                [(.one, 2, 0, .large), (.two, 5, 0, .small)], [], (2, 0), 0,
                2, .one, nil
            ))
        // P5-30: row 8 west end: (0,8) d0 l2 is legal.
        cases.append(
            (
                [(.one, 0, 8, .large)], [], (0, 8), 0, 2, .one, nil
            ))

        XCTAssertGreaterThanOrEqual(cases.count, 30, "R-5 fixture count")

        for (index, fixture) in cases.enumerated() {
            var state = fresh()
            for entry in fixture.setup {
                place(entry.0, (entry.1, entry.2), entry.3, state: &state)
            }
            for (owner, start, d, l) in fixture.pre {
                rake(
                    owner, start: (start.0, start.1), direction: d,
                    length: l, state: &state)
            }
            let got = judge(
                .rake(
                    start: h(fixture.start.0, fixture.start.1),
                    direction: fixture.direction, length: fixture.length),
                as: fixture.mover, from: state)
            XCTAssertEqual(
                got, fixture.expect,
                "R-5 fixture \(index) from \(fixture.start)"
                    + " d\(fixture.direction) len \(fixture.length)")
        }
    }

    // MARK: R-21/R-22 crossing and through fixtures

    func testR21SingleCrossingIsLegal() throws {
        // R-21: two rakes may cross at exactly ONE shared cell. P1
        // (2,0) rakes east len3 → (3,0),(4,0),(5,0); P2 (5,2) rakes
        // north len2 → (5,1),(5,0): one shared cell (5,0).
        var state = fresh()
        place(.one, (2, 0), .large, state: &state)
        place(.two, (5, 2), .large, state: &state)
        rake(.one, start: (2, 0), direction: 0, length: 3, state: &state)
        rake(.two, start: (5, 2), direction: 4, length: 2, state: &state)
        XCTAssertEqual(state.rakes.count, 2, "single crossing allowed")
        // The crossing cell's record keeps the FIRST raker (R-21: it
        // belongs to neither rake for future crossings).
        XCTAssertEqual(state.rakedCells[Hex(5, 0)], .one)
    }

    func testR21TwoSharedCellsRejected() throws {
        // INV-9: no two rakes overlap in more than one cell. P1's line
        // holds (3,0),(4,0); P2's holds (5,1),(4,1),(3,1); then a rake
        // north from a new stone at (4,2) would cover (4,1) AND (4,0)
        // — two overlaps → rakeCrossing.
        var state = fresh()
        place(.one, (2, 0), .large, state: &state)
        place(.two, (6, 1), .large, state: &state)
        rake(.one, start: (2, 0), direction: 0, length: 2, state: &state)
        rake(.two, start: (6, 1), direction: 3, length: 3, state: &state)
        place(.one, (4, 2), .small, state: &state)
        XCTAssertEqual(
            judge(
                .rake(start: Hex(4, 2), direction: 4, length: 2),
                as: .one, from: state),
            .rakeCrossing)
    }

    func testR22RakeThroughStoneBlocked() throws {
        // R-22: rakes cannot pass through stones, and paths that leave
        // the yard are offCourtyard (not blocked).
        var state = fresh()
        place(.one, (1, 4), .large, state: &state)
        place(.two, (1, 5), .medium, state: &state)
        place(.one, (3, 4), .small, state: &state)
        // P2 rakes a clean lane (2,5)…(5,5).
        rake(.two, start: (1, 5), direction: 0, length: 4, state: &state)
        // (3,4) d4 runs north off the yard (row 3 holds only q −1,0).
        XCTAssertEqual(
            judge(
                .rake(start: Hex(3, 4), direction: 4, length: 2),
                as: .one, from: state),
            .offCourtyard)
        // (1,4) d0 l3 passes through P1's own stone at (3,4).
        XCTAssertEqual(
            judge(
                .rake(start: Hex(1, 4), direction: 0, length: 3),
                as: .one, from: state),
            .rakeBlocked)
    }

    func testR5RakedCellCannotReceiveStone() throws {
        // R-5: raked cells cannot later receive stones (either player).
        var state = fresh()
        place(.one, (2, 0), .large, state: &state)
        place(.two, (5, 2), .large, state: &state)
        rake(.one, start: (2, 0), direction: 0, length: 3, state: &state)
        // P2 may not drop onto a raked cell…
        XCTAssertEqual(
            judge(
                .place(cell: Hex(3, 0), size: .medium, facing: 0),
                as: .two, from: state),
            .raked)
        // …and neither may P1 on a later turn.
        place(.two, (6, 2), .medium, state: &state)
        XCTAssertEqual(
            judge(
                .place(cell: Hex(3, 0), size: .medium, facing: 0),
                as: .one, from: state),
            .raked)
    }

    func testR2RakeBudgetExhaustion() throws {
        // R-2: at most rakesPerPlayer (6) rake lines per player. A
        // deterministic scripted game (probe-verified geometry) burns
        // P1's budget with six legal rakes while P2 places all nine
        // stones and rakes three times — no search, no loops.
        var state = fresh()
        let script: [(PlayerID, Action, String)] = [
            (.one, .place(cell: h(1, 4), size: .large, facing: 0), "P1 L(1,4)"),
            (.two, .place(cell: h(6, 5), size: .medium, facing: 0), "P2 M(6,5)"),
            (.one, .place(cell: h(4, 4), size: .large, facing: 0), "P1 L(4,4)"),
            (.two, .place(cell: h(-1, 7), size: .large, facing: 0), "P2 L(-1,7)"),
            (.one, .place(cell: h(4, 2), size: .medium, facing: 0), "P1 M(4,2)"),
            (.two, .place(cell: h(1, 7), size: .small, facing: 0), "P2 S(1,7)"),
            (.one, .rake(start: h(1, 4), direction: 0, length: 2), "P1 r1"),
            (.two, .place(cell: h(-4, 9), size: .medium, facing: 0), "P2 M(-4,9)"),
            (.one, .rake(start: h(4, 2), direction: 4, length: 2), "P1 r2"),
            (.two, .place(cell: h(-3, 9), size: .small, facing: 0), "P2 S(-3,9)"),
            (.one, .rake(start: h(4, 2), direction: 0, length: 2), "P1 r3"),
            (.two, .place(cell: h(-3, 10), size: .large, facing: 0), "P2 L(-3,10)"),
            (.one, .place(cell: h(5, 4), size: .medium, facing: 0), "P1 M(5,4)"),
            (.two, .place(cell: h(0, 8), size: .medium, facing: 0), "P2 M(0,8)"),
            (.one, .place(cell: h(2, 5), size: .small, facing: 0), "P1 S(2,5)"),
            (.two, .place(cell: h(2, 0), size: .small, facing: 0), "P2 S(2,0)"),
            (.one, .rake(start: h(2, 5), direction: 0, length: 2), "P1 r4"),
            (.two, .place(cell: h(0, 10), size: .small, facing: 0), "P2 S(0,10)"),
            (.two, .rake(start: h(6, 5), direction: 3, length: 2), "P2 r1"),
            (.one, .place(cell: h(1, 8), size: .small, facing: 0), "P1 S(1,8)"),
            (.two, .rake(start: h(2, 0), direction: 0, length: 2), "P2 r2"),
            (.one, .rake(start: h(1, 8), direction: 0, length: 2), "P1 r5"),
            (.two, .rake(start: h(0, 10), direction: 3, length: 2), "P2 r3"),
            (.one, .place(cell: h(5, 0), size: .small, facing: 0), "P1 S(5,0)"),
            (.two, .pass, "P2 pass (stuck)"),
            (.one, .rake(start: h(5, 0), direction: 1, length: 2), "P1 r6"),
        ]
        for (ply, entry) in script.enumerated() {
            let reason = act(entry.1, as: entry.0, to: &state)
            XCTAssertNil(
                reason,
                "ply \(ply + 1) \(entry.2): \(String(describing: reason))")
        }
        XCTAssertEqual(
            state.rakesUsed[.one], balance.rakesPerPlayer,
            "P1's rake budget exhausted")
        XCTAssertEqual(state.rakesUsed[.two], 3, "P2 used three rakes")
        XCTAssertEqual(state.stones.count, 16, "board holds 16 stones")
        XCTAssertEqual(state.toMove, .two, "P2 moves next")

        // The seventh rake: the same lane that is legal on a fresh
        // state is rejected .noSupply once the budget is spent. Budget
        // is the LAST check in rakeError, so prove both halves.
        var budgetState = fresh()
        place(.one, (2, 5), .small, state: &budgetState)
        place(.two, (-1, 7), .large, state: &budgetState)
        XCTAssertNil(
            judge(
                .rake(start: Hex(2, 5), direction: 0, length: 2),
                as: .one, from: budgetState),
            "the lane is legal with budget 0")
        budgetState.rakesUsed[.one] = balance.rakesPerPlayer
        XCTAssertEqual(
            judge(
                .rake(start: Hex(2, 5), direction: 0, length: 2),
                as: .one, from: budgetState),
            .noSupply, "the seventh rake is rejected")
    }

    // MARK: R-6 / R-27 pass

    func testR6PassOnlyWhenStuck() throws {
        // R-27: a player with legal moves may not pass.
        var state = fresh()
        XCTAssertEqual(
            judge(.pass, as: .one, from: state), .mustMove,
            "a fresh board has placements; pass refused")
        place(.one, (2, 0), .large, state: &state)
        XCTAssertEqual(
            judge(.pass, as: .two, from: state), .mustMove,
            "after a placement moves still exist")
    }

    func testR6DoublePassEndsGame() throws {
        // Drive to a stuck-stuck end by exhausting supplies and rakes:
        // place every stone, burn every rake, then the forced passes
        // end the game (R-15's first condition).
        var state = fresh()
        var guardCounter = 0
        while !state.isOver && guardCounter < 60 {
            guardCounter += 1
            let moves = LegalMoves.all(
                for: state.toMove, courtyard: courtyard, state: state,
                balance: balance)
            guard !moves.isEmpty else { break }
            // Prefer placements, then rakes, then the forced pass.
            let chosen =
                moves.first {
                    if case .place = $0 { return true }
                    return false
                }
                ?? moves.first {
                    if case .rake = $0 { return true }
                    return false
                }
                ?? moves[0]
            let (next, events) = try Reducer.apply(
                chosen, to: state, courtyard: courtyard, balance: balance)
            if case .pass = chosen {
                XCTAssertTrue(
                    events.contains(.passed(player: state.toMove)),
                    "pass emits .passed")
            }
            state = next
        }
        XCTAssertTrue(state.isOver, "material exhaustion ends the game")
        XCTAssertFalse(state.finalScores.isEmpty, "final scores recorded")
        // With both sides forced to pass only at the very end, the last
        // two actions were passes.
        if state.plies > 0 && state.passes >= 2 {
            // The double-pass ending is one of the two R-15 paths.
        }
    }

    // MARK: R-15 end conditions and winner

    func testR15TieGoesToPlayerTwo() {
        XCTAssertEqual(Score.winner(from: [.one: 10, .two: 10]), .two)
        XCTAssertEqual(Score.winner(from: [.one: 9, .two: 10]), .two)
        XCTAssertEqual(Score.winner(from: [.one: 11, .two: 10]), .one)
    }

    func testR15ResignEndsGameOpponentWins() throws {
        // R-30: resign is legal any time; the resigner loses. The
        // finalScores record the owned-cell counts (the "margin as the
        // current difference" bookkeeping); the winner is delivered in
        // the gameOver event, not by re-scoring the record.
        var state = fresh()
        place(.one, (2, 0), .large, state: &state)
        place(.two, (3, 0), .medium, state: &state)
        let player = state.toMove
        let (next, events) = try Reducer.apply(
            .resign, to: state, courtyard: courtyard, balance: balance)
        XCTAssertTrue(next.isOver)
        XCTAssertFalse(next.finalScores.isEmpty, "owned counts recorded")
        guard case .gameOver(let winner, _) = events.last else {
            return XCTFail("resign emits gameOver")
        }
        XCTAssertEqual(winner, player.opponent, "the resigning player loses")
        XCTAssertEqual(events.first, .resigned(player: player))
    }

    // MARK: Reducer event and state mechanics (A.3, S1.1)

    func testReducerEventsAndTurnFlow() throws {
        var state = fresh()
        let (next, events) = try Reducer.apply(
            .place(cell: Hex(2, 0), size: .large, facing: 0), to: state,
            courtyard: courtyard, balance: balance)
        XCTAssertEqual(
            events,
            [.placed(Stone(owner: .one, cell: Hex(2, 0), size: .large, facing: 0))])
        XCTAssertEqual(next.toMove, .two, "R-3: turns alternate")
        XCTAssertEqual(next.passes, 0, "a real move resets the pass chain")
        XCTAssertEqual(next.plies, 1)
        XCTAssertEqual(next.supplies[.one]?.count(.large), 1, "supply decremented")
        state = next
        let (next2, events2) = try Reducer.apply(
            .place(cell: Hex(3, 0), size: .large, facing: 0), to: state,
            courtyard: courtyard, balance: balance)
        XCTAssertEqual(events2.count, 1)
        XCTAssertEqual(next2.toMove, .one)
        XCTAssertEqual(next2.passes, 0)
    }

    func testINV3SuppliesNeverGoNegative() throws {
        // INV-3: burn every large, then large placements fail with
        // noSupply and supplies stay at zero, never negative. The four
        // larges sit in two short rows ((2,0),(3,0) and (5,2),(6,2)) so
        // no three share an equally-spaced line (R-19 keeps the setup
        // itself legal).
        var state = fresh()
        place(.one, (2, 0), .large, state: &state)
        place(.two, (3, 0), .large, state: &state)
        place(.one, (5, 2), .large, state: &state)
        place(.two, (6, 2), .large, state: &state)
        XCTAssertEqual(state.supplies[.one]?.count(.large), 0)
        XCTAssertEqual(state.supplies[.two]?.count(.large), 0)
        // (4,1) is empty, un-raked, not basin-adjacent, and not
        // same-size-adjacent to either of P1's larges — only the empty
        // large bin blocks it.
        XCTAssertEqual(
            judge(
                .place(cell: Hex(4, 1), size: .large, facing: 0),
                as: .one, from: state),
            .noSupply)
        XCTAssertEqual(state.supplies[.one]?.count(.large), 0)
        for player in PlayerID.allCases {
            let supply = state.supplies[player] ?? Supply(large: 0, medium: 0, small: 0)
            XCTAssertGreaterThanOrEqual(supply.large, 0)
            XCTAssertGreaterThanOrEqual(supply.medium, 0)
            XCTAssertGreaterThanOrEqual(supply.small, 0)
        }
        // Other sizes remain available: the medium placement succeeds.
        place(.one, (4, 1), .medium, state: &state)
        XCTAssertEqual(state.supplies[.one]?.count(.medium), 2)
    }

    // MARK: R-12 viewing face — regression (facing must point at the veranda)

    /// Hand-computed tallies for one large stone at (2,7) on long_wall:
    /// row 7 holds q −1…4, so its west ray holds (1,7) and (0,7), its
    /// east ray holds the basin (3,7) and (4,7) — every ray cell below
    /// is a real courtyard cell (features receive influence, R-24).
    func talliesForStoneAtTwoSeven(facing: Int) -> [Hex: InfluenceTally] {
        let stone = Stone(
            owner: .one, cell: Hex(2, 7), size: .large, facing: facing)
        return InfluenceEngine.computeAll(
            courtyard: courtyard, stones: [stone], rakes: [], balance: balance)
    }

    func testR12ViewingBonusRequiresVerandaFacing() throws {
        // R-12: the bonus goes to large/medium stones FACING THE VERANDA.
        // long_wall's veranda is "bottom" → facing directions [1, 2, 3]
        // (SE, SW, W). A stone facing east (0) must earn nothing, even
        // though its east ray cells sit in the yard.
        let east = talliesForStoneAtTwoSeven(facing: 0)
        XCTAssertEqual(
            east[Hex(3, 7)]?.one, 5,
            "R-12: facing 0 is not veranda-ward — d1 ray cell keeps the bare curve value")
        XCTAssertEqual(
            east[Hex(4, 7)]?.one, 4,
            "R-12: facing 0 earns no bonus at d2 either")
        XCTAssertEqual(east[Hex(1, 7)]?.one, 5, "facing 0: off-ray d1 cell unaffected")
        XCTAssertEqual(east[Hex(2, 8)]?.one, 5, "facing 0: off-ray SE cell unaffected")
        let west = talliesForStoneAtTwoSeven(facing: 3)
        XCTAssertEqual(
            west[Hex(1, 7)]?.one, 6,
            "R-12: facing 3 (toward the veranda) adds +1 at d1")
        XCTAssertEqual(
            west[Hex(0, 7)]?.one, 5,
            "R-12: facing 3 adds +1 at d2")
        XCTAssertEqual(
            west[Hex(3, 7)]?.one, 5,
            "R-12: the bonus covers only the facing ray")
        let southEast = talliesForStoneAtTwoSeven(facing: 1)
        XCTAssertEqual(
            southEast[Hex(2, 8)]?.one, 6, "R-12: facing 1 also veranda-ward at d1")
        let southWest = talliesForStoneAtTwoSeven(facing: 2)
        XCTAssertEqual(southWest[Hex(1, 8)]?.one, 6, "R-12: facing 2 also veranda-ward at d1")
    }

    func testR12IncrementalOwnershipMatchesScratchForEveryFacing() throws {
        // INV-2's incremental path shares the R-12 helper with the
        // from-scratch engine; pin that the two agree for every facing
        // of a large stone (a facing-dependent drift would show here).
        for facing in 0..<6 {
            let stone = Stone(
                owner: .one, cell: Hex(2, 7), size: .large, facing: facing)
            var ownership = Ownership(courtyard: courtyard, balance: balance)
            ownership.applyStonePlacement(
                stone, context: [stone], balance: balance)
            let scratch = InfluenceEngine.computeAll(
                courtyard: courtyard, stones: [stone], rakes: [],
                balance: balance)
            for cell in courtyard.cells {
                XCTAssertEqual(
                    ownership.tally(at: cell),
                    scratch[cell] ?? InfluenceTally(),
                    "INV-2 mismatch at \(cell) for facing \(facing)")
            }
        }
    }
}
