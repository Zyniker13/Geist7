// RulesVictoryTests.swift — R-11 victory, the stuck rule and the
// tie-break ladder, R-23 threefold repetition, and forced passes.

import XCTest

@testable import MTCore

final class RulesVictoryTests: XCTestCase {
    private var chart: Chart { TestCharts.validated(TestCharts.eastOnly()) }

    // MARK: R-11 — outright win at three landings

    func test_R11_threeLandingsWin() {
        // Two canoes already landed; the third sails into the rival
        // atoll from (4,0).
        let state = TestStates.state(
            chart, islands: [],
            canoes: TestStates.canoes(
                sea: [(.p1, 2, Hex(4, 0))],
                landed: [(.p1, 0), (.p1, 1)]))
        let (next, events) = TestStates.apply(
            .sail(CanoeID(player: .p1, index: 2), [Hex(5, -1)]), to: state)
        XCTAssertEqual(next.status, .won(.p1))
        XCTAssertEqual(events.last, .gameEnded(.won(.p1)))
        XCTAssertEqual(next.landed[.p1], 3)
    }

    func test_R11_twoLandingsDoNotWin() {
        let state = TestStates.state(
            chart, islands: [],
            canoes: TestStates.canoes(
                sea: [(.p1, 1, Hex(4, 0))],
                landed: [(.p1, 0)]))
        let next = TestStates.apply(
            .sail(CanoeID(player: .p1, index: 1), [Hex(5, -1)]), to: state
        ).state
        XCTAssertEqual(next.status, .ongoing)
        XCTAssertEqual(next.landed[.p1], 2)
    }

    func test_R11_theGameCannotContinueAfterItEnds() {
        var ended = Reducer.initial(chart: chart)
        ended.status = .won(.p1)
        XCTAssertEqual(
            Reducer.reason(.placeIsland(Hex(2, -3)), in: ended), .gameAlreadyOver)
        XCTAssertTrue(Reducer.legalActions(in: ended).isEmpty)
    }

    // MARK: R-11 — the stuck rule and the tie-break ladder

    /// A dead position: the pool spent, every canoe becalmed on calm
    /// water, no two friendly canoes adjacent (no towers), so the only
    /// legal action for either side is a pass. The eight canoe cells
    /// are chosen programmatically from the chart's calm cells (this
    /// chart's wandering refracted rays leave scattered strength-0
    /// cells in every row), pairwise non-adjacent within a side.
    private func deadPosition(toMove: PlayerID, stuck: Int) -> GameState {
        let calm = chart.ocean.allCells.filter {
            !chart.atollCells.contains($0)
                && initialField.strength(at: $0) == Balance.becalmedStrength
        }
        func scatter(_ start: Int) -> [Hex] {
            var picked: [Hex] = []
            for cell in calm.dropFirst(start) where picked.count < Balance.canoesPerPlayer {
                if picked.allSatisfy({ $0.distance(to: cell) >= 2 }) {
                    picked.append(cell)
                }
            }
            precondition(picked.count == Balance.canoesPerPlayer, "not enough calm cells")
            return picked
        }
        let p1Cells = scatter(0)
        let p2Cells = scatter(4)
        var sea: [(PlayerID, Int, Hex)] = []
        for (index, cell) in p1Cells.enumerated() { sea.append((.p1, index, cell)) }
        for (index, cell) in p2Cells.enumerated() { sea.append((.p2, index, cell)) }
        let state = TestStates.state(
            chart,
            islands: [],
            canoes: TestStates.canoes(
                sea: sea, becalmed: Set(CanoeID.allCanoeIDs)),
            pool: 0, toMove: toMove, stuck: stuck)
        // INV-8 sanity: the flag matches the field everywhere.
        for id in CanoeID.allCanoeIDs {
            guard case .sea(let cell) = state.canoe(id).location else { continue }
            XCTAssertEqual(
                state.canoe(id).becalmed,
                state.field.strength(at: cell) == Balance.becalmedStrength,
                "INV-8 for \(id)")
        }
        // Sanity: only a pass is legal for the mover.
        for action in Reducer.legalActions(in: state) {
            XCTAssertTrue(action.isPass, "unexpected legal action \(action)")
        }
        return state
    }

    /// The empty-board field of the standard chart.
    private var initialField: Field {
        Field.compute(
            ocean: chart.ocean, swells: chart.swells, islands: [],
            atollCells: chart.atollCells)
    }

    func test_R11_stuckRuleEndsTheGameByTieBreak() {
        // P1 passes (stuck 1), P2 passes (stuck 2): with the pool empty
        // the game ends by the R-11 tie-break.
        let first = TestStates.apply(.pass, to: deadPosition(toMove: .p1, stuck: 0))
        XCTAssertEqual(first.state.stuckTurns, 1)
        XCTAssertFalse(first.state.status.isOver)
        let second = TestStates.apply(.pass, to: first.state)
        XCTAssertTrue(second.state.status.isOver)
        XCTAssertEqual(second.events.last, .gameEnded(second.state.status))
    }

    func test_R11_actionsResetTheStuckCounter() {
        var state = deadPosition(toMove: .p1, stuck: 0)
        state = TestStates.apply(.pass, to: state).state  // stuck 1
        var withPool = state
        withPool.poolRemaining = 1
        withPool.toMove = .p2
        // P2 can still place an island, which resets the counter.
        let place = require(
            Reducer.legalActions(in: withPool).first { action in
                if case .placeIsland = action { return true }
                return false
            },
            "no island placement action")
        let next = TestStates.apply(place, to: withPool).state
        XCTAssertEqual(next.stuckTurns, 0)
    }

    func test_R11_tieBreakLadder_moreLandedWins() {
        let state = TestStates.state(
            chart, islands: [],
            canoes: TestStates.canoes(
                sea: [(.p1, 0, Hex(2, 3)), (.p2, 0, Hex(-2, 4))],
                landed: [(.p1, 1)]),
            pool: 0, toMove: .p2, stuck: 1)
        XCTAssertEqual(Victory.tiebreakWinner(state), .p1)
    }

    func test_R11_tieBreakLadder_closerByPathDistanceWins() {
        // Landed counts equal; P1's canoe is one step from P2's atoll
        // (from (4,0) into (5,-1)), P2's is two from P1's; with the
        // home canoes factored in the sums are 17 vs 18.
        let near = TestStates.state(
            chart, islands: [],
            canoes: TestStates.canoes(
                sea: [(.p1, 0, Hex(4, 0)), (.p2, 0, Hex(-2, 1))]),
            pool: 0, toMove: .p2, stuck: 1)
        XCTAssertEqual(Victory.tiebreakWinner(near), .p1)
        // Reverse them: P1's canoe is sealed off from its launching
        // routes by the calm rows (unreachable → the side scores only
        // its home canoes, 24) while P2's is six steps out (22) —
        // Player 2 now wins the ladder.
        let mirrored = TestStates.state(
            chart, islands: [],
            canoes: TestStates.canoes(
                sea: [(.p1, 0, Hex(-4, 0)), (.p2, 0, Hex(2, 1))]),
            pool: 0, toMove: .p2, stuck: 1)
        XCTAssertEqual(Victory.tiebreakWinner(mirrored), .p2)
    }

    func test_R11_tieBreakLadder_equalScoresGoToPlayerTwo() {
        // Both canoes two... three steps out with equal sums (18 each:
        // (3,0) is two steps from P2's atoll, (-2,1) two from P1's) —
        // the ladder's final step gives it to Player 2.
        let state = TestStates.state(
            chart, islands: [],
            canoes: TestStates.canoes(
                sea: [(.p1, 0, Hex(3, 0)), (.p2, 0, Hex(-2, 1))]),
            pool: 0, toMove: .p2, stuck: 1)
        XCTAssertEqual(Victory.pathDistanceSum(state, .p1), 18)
        XCTAssertEqual(Victory.pathDistanceSum(state, .p2), 18)
        XCTAssertEqual(Victory.tiebreakWinner(state), .p2)
    }

    func test_R11_tieBreak_distancesArePerCanoe() {
        // Four reachable canoes on row 1 give the BFS distances to the
        // rival atoll (pure hex distance on this node-free chart);
        // becalmed canoes are excluded (they cannot reach a landing).
        let state = TestStates.state(
            chart, islands: [],
            canoes: TestStates.canoes(
                sea: [
                    (.p1, 0, Hex(-3, 1)), (.p1, 1, Hex(-2, 1)),
                    (.p1, 2, Hex(-1, 1)), (.p1, 3, Hex(0, 1)),
                ]))
        XCTAssertEqual(Victory.canoeDistances(state, .p1), [4, 5, 6, 7])
        // A becalmed sea canoe has no route at a tie-break; with the
        // other canoes landed, the side scores nothing.
        let stuck = TestStates.state(
            chart, islands: [],
            canoes: TestStates.canoes(
                sea: [(.p1, 0, Hex(-2, -1))],
                landed: [(.p1, 1), (.p1, 2), (.p1, 3)],
                becalmed: [CanoeID(player: .p1, index: 0)]))
        XCTAssertTrue(Victory.canoeDistances(stuck, .p1).isEmpty)
    }

    // MARK: R-11 — pass only when forced (ADR-0011)

    func test_R11_passIsIllegalWhenActionsRemain() {
        let state = Reducer.initial(chart: chart)
        XCTAssertEqual(Reducer.reason(.pass, in: state), .passNotForced)
    }

    // MARK: R-23 — threefold repetition

    func test_R23_threefoldRepetitionEndsByTieBreak() {
        // Two canoes dance back and forth; every four plies the full
        // position (islands, canoes, side to move) repeats. The third
        // occurrence ends the game by the R-11 tie-break.
        var state = Reducer.initial(chart: chart)
        state = TestStates.apply(.launch(Hex(-3, 1)), to: state).state  // P1
        state = TestStates.apply(.launch(Hex(4, 0)), to: state).state  // P2
        let id1 = CanoeID(player: .p1, index: 0)
        let id2 = CanoeID(player: .p2, index: 0)
        let cycle: [Action] = [
            .sail(id1, [Hex(-2, 1), Hex(-1, 1)]),
            .sail(id2, [Hex(3, 0)]),
            .sail(id1, [Hex(-2, 1), Hex(-3, 1)]),
            .sail(id2, [Hex(4, 0)]),
        ]
        var ended: GameStatus?
        for (index, action) in (cycle + cycle + cycle).enumerated() {
            if state.status.isOver {
                XCTFail("game ended early at ply \(index)")
                return
            }
            let (next, events) = TestStates.apply(action, to: state)
            state = next
            if state.status.isOver {
                ended = state.status
                XCTAssertEqual(events.last, .gameEnded(state.status))
                break
            }
        }
        // The post-launch position recurs two plies into each later
        // cycle; its third occurrence fires R-23.
        XCTAssertNotNil(ended)
        guard case .tiebreak = ended else {
            XCTFail("expected a tie-break end, got \(String(describing: ended))")
            return
        }
        XCTAssertNotEqual(ended, .won(.p1))
        XCTAssertNotEqual(ended, .won(.p2))
    }

    func test_R23_theStartingPositionCountsOnce() {
        let state = Reducer.initial(chart: chart)
        XCTAssertEqual(state.visited.count, 1)
        XCTAssertEqual(state.visited[Zobrist.positionKey(of: state)], 1)
    }

    func test_R23_keysAreStableAndDiscriminating() {
        // Structurally equal states built independently share a key;
        // any difference (an island, a canoe cell, the side to move)
        // changes it.
        let chart = TestCharts.validated(TestCharts.eastAndDiagonal())
        let a = Reducer.initial(chart: chart)
        let b = Reducer.initial(chart: chart)
        XCTAssertEqual(Zobrist.positionKey(of: a), Zobrist.positionKey(of: b))

        var moved = a
        moved.toMove = .p2
        XCTAssertNotEqual(Zobrist.positionKey(of: a), Zobrist.positionKey(of: moved))

        var islandMore = a
        islandMore.islands.insert(Hex(1, 1))
        islandMore.field = Field.compute(
            ocean: chart.ocean, swells: chart.swells, islands: islandMore.islands,
            atollCells: chart.atollCells)
        XCTAssertNotEqual(Zobrist.positionKey(of: a), Zobrist.positionKey(of: islandMore))

        var canoeMoved = a
        canoeMoved.canoes[CanoeID(player: .p1, index: 0)] = CanoeState(
            owner: .p1, location: .sea(Hex(-4, 1)), becalmed: false)
        XCTAssertNotEqual(Zobrist.positionKey(of: a), Zobrist.positionKey(of: canoeMoved))
    }
}
