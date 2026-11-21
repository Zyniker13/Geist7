// RulesBecalmTests.swift — R-9 becalming, R-19 towing, INV-8 (becalm
// is a pure function of field and position).

import XCTest

@testable import MTCore

final class RulesBecalmTests: XCTestCase {
    private var chart: Chart { TestCharts.validated(TestCharts.eastOnly()) }

    // MARK: R-9 — becalming

    func test_R9_islandPlacementBecalmsCanoesOnCalmedCells() {
        // P1's canoe at (-3,1) (the row-1 ray reaches it); P2 places at
        // (-2,1), which refracts the ray away one cell early: the
        // canoe's cell drops to strength 0.
        var state = Reducer.initial(chart: chart)
        state = TestStates.apply(.launch(Hex(-3, 1)), to: state).state
        let (next, events) = TestStates.apply(.placeIsland(Hex(-2, 1)), to: state)
        let id = CanoeID(player: .p1, index: 0)
        XCTAssertEqual(next.canoe(id).becalmed, true)
        XCTAssertEqual(events.last, .becameBecalmed(id))
        // INV-8: the flag equals the derived value.
        XCTAssertEqual(
            next.canoe(id).becalmed,
            next.field.strength(at: Hex(-3, 1)) == Balance.becalmedStrength)
    }

    func test_R9_becalmedCanoeCannotSail() {
        // (-2,-1) lies on row -1, whose east entry is P2's atoll cell:
        // the cell carries no swell, so a canoe there is becalmed (R-9).
        let state = TestStates.state(
            chart, islands: [],
            canoes: TestStates.canoes(
                sea: [(.p1, 0, Hex(-2, -1))],
                becalmed: [CanoeID(player: .p1, index: 0)]))
        let id = CanoeID(player: .p1, index: 0)
        XCTAssertEqual(state.field.strength(at: Hex(-2, -1)), 0)
        XCTAssertEqual(Reducer.reason(.sail(id, [Hex(-1, -1)]), in: state), .becalmedCanoe(id))
        XCTAssertEqual(Reducer.reason(.sail(id, [Hex(-2, -2)]), in: state), .becalmedCanoe(id))
    }

    // MARK: R-19 — towing

    func test_R19_towMovesABecalmedCanoeOneStep() {
        // P1's becalmed canoe at (-2,-1), a friendly tower at (-1,-1);
        // tow it south to (-2,-2) (also calm water — the recompute
        // keeps it becalmed, INV-8).
        let state = TestStates.state(
            chart, islands: [],
            canoes: TestStates.canoes(
                sea: [(.p1, 0, Hex(-2, -1)), (.p1, 1, Hex(-1, -1))],
                becalmed: [CanoeID(player: .p1, index: 0)]))
        let id = CanoeID(player: .p1, index: 0)
        XCTAssertEqual(Reducer.reason(.tow(id, Hex(-2, -2)), in: state), nil)
        let (next, events) = TestStates.apply(.tow(id, Hex(-2, -2)), to: state)
        XCTAssertEqual(events, [.towed(id, Hex(-2, -2)), .becameBecalmed(id)])
        XCTAssertEqual(next.canoe(id).location, .sea(Hex(-2, -2)))
        XCTAssertTrue(next.canoe(id).becalmed, "INV-8: a canoe parked on calm water")
    }

    func test_R19_towRequiresAnAdjacentFriendlyCanoe() {
        let alone = TestStates.state(
            chart, islands: [],
            canoes: TestStates.canoes(
                sea: [(.p1, 0, Hex(-2, -1))],
                becalmed: [CanoeID(player: .p1, index: 0)]))
        let id = CanoeID(player: .p1, index: 0)
        XCTAssertEqual(
            Reducer.reason(.tow(id, Hex(-2, -2)), in: alone),
            .noAdjacentTower(id))
        // A rival canoe alongside does not count (R-19: a FRIENDLY
        // canoe spends its turn).
        let rivalNear = TestStates.state(
            chart, islands: [],
            canoes: TestStates.canoes(
                sea: [(.p1, 0, Hex(-2, -1)), (.p2, 0, Hex(-1, -1))],
                becalmed: [CanoeID(player: .p1, index: 0)]))
        XCTAssertEqual(
            Reducer.reason(.tow(id, Hex(-2, -2)), in: rivalNear),
            .noAdjacentTower(id))
    }

    func test_R19_towTargetRules() {
        let state = TestStates.state(
            chart, islands: [],
            canoes: TestStates.canoes(
                sea: [(.p1, 0, Hex(-2, -1)), (.p1, 1, Hex(-1, -1))],
                becalmed: [CanoeID(player: .p1, index: 0)]))
        let id = CanoeID(player: .p1, index: 0)
        // Not adjacent.
        XCTAssertEqual(
            Reducer.reason(.tow(id, Hex(-2, 1)), in: state), .towTargetIllegal(Hex(-2, 1)))
        // Onto an island.
        let blocked = TestStates.state(
            chart, islands: [Hex(-2, -2)],
            canoes: TestStates.canoes(
                sea: [(.p1, 0, Hex(-2, -1)), (.p1, 1, Hex(-1, -1))],
                becalmed: [CanoeID(player: .p1, index: 0)]))
        XCTAssertEqual(
            Reducer.reason(.tow(id, Hex(-2, -2)), in: blocked), .cellOccupied(Hex(-2, -2)))
        // Onto another canoe.
        let crowded = TestStates.state(
            chart, islands: [],
            canoes: TestStates.canoes(
                sea: [(.p1, 0, Hex(-2, -1)), (.p1, 1, Hex(-1, -1)), (.p2, 0, Hex(-2, -2))],
                becalmed: [CanoeID(player: .p1, index: 0)]))
        XCTAssertEqual(
            Reducer.reason(.tow(id, Hex(-2, -2)), in: crowded), .cellHasCanoe(Hex(-2, -2)))
        // Towing a canoe that is not becalmed.
        XCTAssertEqual(
            Reducer.reason(
                .tow(CanoeID(player: .p1, index: 1), Hex(-1, -2)), in: state),
            .notBecalmed(CanoeID(player: .p1, index: 1)))
    }

    func test_R19_towToOpenWaterFreesTheCanoe() {
        // A hand-built field: (−3,1) is calm, (−3,2) two swells strong.
        // P1's becalmed canoe at (−3,1), a tower at (−2,1); the tow
        // south frees the canoe and it sails next turn.
        var state = TestStates.state(
            chart, islands: [],
            canoes: TestStates.canoes(
                sea: [(.p1, 0, Hex(-3, 1)), (.p1, 1, Hex(-2, 1))],
                becalmed: [CanoeID(player: .p1, index: 0)]))
        var swells = state.field.swells
        var strength = state.field.strength
        swells[Hex(-3, 1)] = []
        strength[Hex(-3, 1)] = 0
        swells[Hex(-3, 2)] = (swells[Hex(-3, 2)] ?? []).union(["z", "w"])
        strength[Hex(-3, 2)] = (strength[Hex(-3, 2)] ?? 0) + 2
        state.field = Field(swells: swells, strength: strength, rays: state.field.rays)
        // INV-8: the flag matches the field.
        XCTAssertEqual(state.field.strength(at: Hex(-3, 1)), 0)
        let id = CanoeID(player: .p1, index: 0)
        state = TestStates.apply(.tow(id, Hex(-3, 2)), to: state).state
        XCTAssertEqual(state.canoe(id).location, .sea(Hex(-3, 2)))
        XCTAssertFalse(state.canoe(id).becalmed, "the towed canoe sits on a swell again")
        // And it may sail on its side's next turn.
        var nextTurn = state
        nextTurn.toMove = .p1
        XCTAssertEqual(
            Reducer.reason(.sail(id, [Hex(-2, 2)]), in: nextTurn), nil)
    }
}
