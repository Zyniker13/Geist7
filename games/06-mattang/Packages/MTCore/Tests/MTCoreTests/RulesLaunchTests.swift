// RulesLaunchTests.swift — R-17 launching.

import XCTest

@testable import MTCore

final class RulesLaunchTests: XCTestCase {
    private var chart: Chart { TestCharts.validated(TestCharts.eastOnly()) }

    func test_R17_launchPutsTheLowestHomeCanoeOnAStrengthCell() {
        let state = Reducer.initial(chart: chart)
        // (-3,1): adjacent to P1's atoll cell (-4,2) and strength 2
        // (the row-1 ray covers it).
        let cell = Hex(-3, 1)
        XCTAssertEqual(Reducer.reason(.launch(cell), in: state), nil)
        let (next, events) = TestStates.apply(.launch(cell), to: state)
        XCTAssertEqual(events, [.launched(CanoeID(player: .p1, index: 0), cell)])
        let canoe = next.canoe(CanoeID(player: .p1, index: 0))
        XCTAssertEqual(canoe.location, .sea(cell))
        XCTAssertEqual(canoe.becalmed, false)
        XCTAssertEqual(next.homeCanoeIDs(owner: .p1).count, Balance.canoesPerPlayer - 1)
        XCTAssertEqual(next.toMove, .p2)
        // R-17: launching spends the turn; the launched canoe cannot
        // also sail this turn (one action per turn, R-11).
        XCTAssertEqual(
            Reducer.reason(.sail(CanoeID(player: .p1, index: 0), [Hex(-2, 1)]), in: next),
            .notOwnedByMover(CanoeID(player: .p1, index: 0)))
    }

    func test_R17_illegalReasons() {
        let state = Reducer.initial(chart: chart)
        // Not adjacent to the mover's home atoll.
        XCTAssertEqual(
            Reducer.reason(.launch(Hex(4, 0)), in: state),
            .notAdjacentToHomeAtoll(Hex(4, 0)))
        // On an atoll cell.
        let atollCell = require(chart.atoll(for: .p1).cells.first, "empty atoll")
        XCTAssertEqual(
            Reducer.reason(.launch(atollCell), in: state), .cellOccupied(atollCell))
        // A strength-0 neighbour of the atoll: (-5,3) sits beside
        // (-5,2), and no swell reaches it (row 1's ray refracts away
        // at (-3,1), row 3's at (-3,3)).
        XCTAssertEqual(
            Reducer.reason(.launch(Hex(-5, 3)), in: state),
            .cellStrengthZero(Hex(-5, 3)))
        // A cell holding another canoe: (-3,1) occupied by P2.
        let blocked = TestStates.state(
            chart, islands: [],
            canoes: TestStates.canoes(sea: [(.p2, 0, Hex(-3, 1))]))
        XCTAssertEqual(
            Reducer.reason(.launch(Hex(-3, 1)), in: blocked),
            .cellHasCanoe(Hex(-3, 1)))
    }

    func test_R17_noHomeCanoeLeft() {
        // Three home canoes remain for P1 — a launch is still legal.
        let state = TestStates.state(
            chart, islands: [],
            canoes: TestStates.canoes(sea: [(.p1, 0, Hex(-3, 1))]))
        XCTAssertEqual(Reducer.reason(.launch(Hex(-3, 2)), in: state), nil)
        // All four at sea: no launch is possible.
        let allSea = TestStates.state(
            chart, islands: [],
            canoes: TestStates.canoes(
                sea: [
                    (.p1, 0, Hex(-3, 1)), (.p1, 1, Hex(-3, 2)),
                    (.p1, 2, Hex(-2, 1)), (.p1, 3, Hex(-2, 2)),
                ]))
        XCTAssertEqual(
            Reducer.reason(.launch(Hex(-3, 2)), in: allSea),
            .noHomeCanoe(.p1))
    }

    func test_R17_becalmedLaunchTargetBecalmsTheCanoe() {
        // A launch onto strength ≥ 1 stands; the R-9 recompute becalms
        // a canoe only when its cell drops later.
        var state = Reducer.initial(chart: chart)
        state = TestStates.apply(.launch(Hex(-3, 1)), to: state).state
        // P2 places at (-2,1): the row-1 ray refracts away at (-1,1),
        // so (-3,1) loses the east swell and drops to strength 0.
        state = TestStates.apply(.placeIsland(Hex(-2, 1)), to: state).state
        let canoe = state.canoe(CanoeID(player: .p1, index: 0))
        XCTAssertEqual(canoe.location, .sea(Hex(-3, 1)))
        XCTAssertTrue(canoe.becalmed, "R-9: the canoe on a calmed cell is becalmed")
    }
}
