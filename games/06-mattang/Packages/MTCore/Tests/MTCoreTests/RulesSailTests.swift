// RulesSailTests.swift — R-8 sailing, R-18 node chains (ADR-0012's
// straight-line ride), R-10 landing, R-20 blocking, and the
// validatePath/paths agreement.

import XCTest

@testable import MTCore

final class RulesSailTests: XCTestCase {
    private var chart: Chart { TestCharts.validated(TestCharts.eastOnly()) }
    private var nodeChart: Chart { TestCharts.validated(TestCharts.eastAndDiagonal()) }

    /// A field with a three-cell node chain on row 0 at (0,0),(1,0),
    /// (2,0): every ocean cell carries swell "a" (strength 1) and the
    /// chain cells additionally "b" (strength 2, two distinct swells).
    private func patchedField() -> Field {
        let ocean = chart.ocean
        var swells: [Hex: Set<String>] = [:]
        var strength: [Hex: Int] = [:]
        for cell in ocean.allCells {
            swells[cell] = ["a"]
            strength[cell] = 1
        }
        for cell in [Hex(0, 0), Hex(1, 0), Hex(2, 0)] {
            swells[cell] = ["a", "b"]
            strength[cell] = 2
        }
        return Field(swells: swells, strength: strength, rays: [])
    }

    private func patchedState(canoeAt: Hex, toMove: PlayerID = .p1) -> GameState {
        let base = TestStates.state(
            chart, islands: [], canoes: TestStates.canoes(sea: [(.p1, 0, canoeAt)]))
        var state = base
        state.field = patchedField()
        return state
    }

    // MARK: R-8 — straight-line sailing within range

    func test_R8_sailWithinRange_alongRow() {
        // P1's canoe at (-4,1) sails three cells east along row 1.
        let state = TestStates.state(
            chart, islands: [], canoes: TestStates.canoes(sea: [(.p1, 0, Hex(-4, 1))]))
        let path = [Hex(-3, 1), Hex(-2, 1), Hex(-1, 1)]
        XCTAssertEqual(
            Movement.validatePath(path, for: CanoeID(player: .p1, index: 0), in: state), nil)
        // Four steps exceed sailRange (R-8).
        XCTAssertEqual(
            Movement.validatePath(
                path + [Hex(0, 1)], for: CanoeID(player: .p1, index: 0), in: state),
            .pathTooLong(cost: 4))
    }

    func test_R8_everyEnteredCellMustCarryASwell() {
        // Row -1 carries no east ray on this chart (its entry cell is
        // P2's atoll): strength 0 there (R-8).
        let state = TestStates.state(
            chart, islands: [], canoes: TestStates.canoes(sea: [(.p1, 0, Hex(-2, -2))]))
        XCTAssertEqual(
            Movement.validatePath([Hex(-2, -1)], for: CanoeID(player: .p1, index: 0), in: state),
            .pathCellCalm(Hex(-2, -1)))
    }

    func test_R8_R20_canoesBlockCells() {
        let state = TestStates.state(
            chart, islands: [],
            canoes: TestStates.canoes(sea: [(.p1, 0, Hex(-4, 1)), (.p2, 0, Hex(-2, 1))]))
        XCTAssertEqual(
            Movement.validatePath(
                [Hex(-3, 1), Hex(-2, 1)], for: CanoeID(player: .p1, index: 0), in: state),
            .cellHasCanoe(Hex(-2, 1)))
        // Islands and atoll cells block too.
        let withIsland = TestStates.state(
            chart, islands: [Hex(-3, 1)],
            canoes: TestStates.canoes(sea: [(.p1, 0, Hex(-4, 1))]))
        XCTAssertEqual(
            Movement.validatePath(
                [Hex(-3, 1)], for: CanoeID(player: .p1, index: 0), in: withIsland),
            .cellOccupied(Hex(-3, 1)))
    }

    func test_R8_pathsMustBeStraightAndContiguous() {
        let state = TestStates.state(
            chart, islands: [], canoes: TestStates.canoes(sea: [(.p1, 0, Hex(-4, 1))]))
        let id = CanoeID(player: .p1, index: 0)
        // A gap in the path.
        XCTAssertEqual(
            Movement.validatePath([Hex(-2, 1)], for: id, in: state),
            .badPathStep(Hex(-4, 1), Hex(-2, 1)))
        // A bend mid-path (ADR-0012: a sail is straight-line).
        XCTAssertEqual(
            Movement.validatePath([Hex(-3, 1), Hex(-3, 0)], for: id, in: state),
            .badPathStep(Hex(-3, 1), Hex(-3, 0)))
    }

    // MARK: R-18 — the straight-line node ride (ADR-0012)

    func test_R18_nodeChainStepsAreFree_andTheRideIsStraight() {
        // Canoe at (-2,0): (0,0),(1,0),(2,0) are nodes; the ride into
        // and along the chain costs 1 (into the first node) + 0 + 0.
        let state = patchedState(canoeAt: Hex(-2, 0))
        let id = CanoeID(player: .p1, index: 0)
        // Three cells for two paid steps is legal...
        XCTAssertEqual(
            Movement.validatePath([Hex(-1, 0), Hex(0, 0), Hex(1, 0)], for: id, in: state), nil)
        // ...and stopping mid-chain is legal (§4: entering a node ends
        // movement).
        XCTAssertEqual(
            Movement.validatePath([Hex(-1, 0), Hex(0, 0)], for: id, in: state), nil)
        // Leaving the chain sideways/back is not: after entering a node
        // the only continuation is straight ahead through nodes.
        XCTAssertEqual(
            Movement.validatePath(
                [Hex(-1, 0), Hex(0, 0), Hex(1, 0), Hex(2, 0), Hex(3, 0)],
                for: id, in: state),
            .nodeExit(Hex(2, 0)))
    }

    func test_R18_theStartCellNeverBinds() {
        // A canoe standing ON a node may step off in any direction.
        let state = patchedState(canoeAt: Hex(1, 0))  // a chain node
        let id = CanoeID(player: .p1, index: 0)
        XCTAssertEqual(
            Movement.validatePath([Hex(0, 1)], for: id, in: state), nil,
            "stepping south off a node is legal")
        XCTAssertEqual(
            Movement.validatePath([Hex(1, -1)], for: id, in: state), nil,
            "stepping north off a node is legal")
        // Riding the chain forward is legal and free.
        XCTAssertEqual(
            Movement.validatePath([Hex(2, 0)], for: id, in: state), nil)
        // And from the start node the canoe may ride INTO the chain
        // and onward: (2,0) node, (3,0) not a node — the ride must end
        // at (2,0).
        XCTAssertEqual(
            Movement.validatePath([Hex(2, 0), Hex(3, 0)], for: id, in: state),
            .nodeExit(Hex(2, 0)))
    }

    func test_R18_blockedChainEndIsAStoppablePoint() {
        // A canoe (not an island) on (2,0) blocks the ride; stopping at
        // (1,0) is legal because the further node step is blocked.
        let state0 = TestStates.state(
            chart, islands: [],
            canoes: TestStates.canoes(sea: [(.p1, 0, Hex(-2, 0)), (.p2, 0, Hex(2, 0))]))
        var state = state0
        state.field = patchedField()
        let id = CanoeID(player: .p1, index: 0)
        XCTAssertEqual(
            Movement.validatePath([Hex(-1, 0), Hex(0, 0), Hex(1, 0)], for: id, in: state), nil,
            "the blocked chain end is a legitimate stop")
        // Riding into the blocker is still illegal.
        XCTAssertEqual(
            Movement.validatePath(
                [Hex(-1, 0), Hex(0, 0), Hex(1, 0), Hex(2, 0)], for: id, in: state),
            .cellHasCanoe(Hex(2, 0)))
    }

    // MARK: R-10 — landing

    func test_R10_landingScoresAndRemovesTheCanoe() {
        // P1's canoe at (4,0) steps into P2's atoll cell (5,-1).
        let state = TestStates.state(
            chart, islands: [], canoes: TestStates.canoes(sea: [(.p1, 0, Hex(4, 0))]))
        let id = CanoeID(player: .p1, index: 0)
        XCTAssertEqual(Movement.validatePath([Hex(5, -1)], for: id, in: state), nil)
        let (next, events) = TestStates.apply(.sail(id, [Hex(5, -1)]), to: state)
        XCTAssertEqual(events, [.sailed(id, [Hex(5, -1)]), .landed(id)])
        XCTAssertEqual(next.canoe(id).location, .landed)
        XCTAssertEqual(next.landed[.p1], 1)
        XCTAssertEqual(next.seaCanoeIDs(owner: .p1).count, 0)
    }

    func test_R10_landingIsBarredAfterRidingAChain() {
        // With a node at (4,-1) (two fresh swells make it one), the
        // canoe riding into it may not step on into the atoll (5,-1).
        var state = TestStates.state(
            chart, islands: [], canoes: TestStates.canoes(sea: [(.p1, 0, Hex(3, -1))]))
        var swells = state.field.swells
        var strength = state.field.strength
        swells[Hex(4, -1)] = (swells[Hex(4, -1)] ?? []).union(["z", "w"])
        strength[Hex(4, -1)] = (strength[Hex(4, -1)] ?? 0) + 2
        state.field = Field(swells: swells, strength: strength, rays: state.field.rays)
        let id = CanoeID(player: .p1, index: 0)
        XCTAssertEqual(
            Movement.validatePath([Hex(4, -1), Hex(5, -1)], for: id, in: state),
            .landingFromNode(Hex(4, -1)))
        // Landing straight from ordinary water is fine.
        XCTAssertEqual(
            Movement.validatePath([Hex(4, -1)], for: id, in: state), nil)
    }

    func test_R10_landingMidPathIsIllegal() {
        let state = TestStates.state(
            chart, islands: [], canoes: TestStates.canoes(sea: [(.p1, 0, Hex(3, 0))]))
        let id = CanoeID(player: .p1, index: 0)
        // A sail is straight-line (ADR-0012): the path bends at (4,0).
        XCTAssertEqual(
            Movement.validatePath([Hex(4, 0), Hex(5, -1)], for: id, in: state),
            .badPathStep(Hex(4, 0), Hex(5, -1)))
    }

    // MARK: Enumeration (ADR-0007/ADR-0012)

    func test_paths_agreesWithValidatePath_andStaysBounded() {
        // On the all-node diagonal chart, enumeration stays bounded and
        // every enumerated path validates (the regression for the
        // enumeration explosion ADR-0012 records).
        let state = TestStates.state(
            nodeChart, islands: [],
            canoes: TestStates.canoes(sea: [(.p1, 0, Hex(-4, 0))]))
        let id = CanoeID(player: .p1, index: 0)
        let paths = Movement.paths(for: id, in: state)
        XCTAssertLessThanOrEqual(paths.count, 6 * Balance.maxPathCells)
        for path in paths {
            XCTAssertEqual(Movement.validatePath(path, for: id, in: state), nil)
            // Every legal path's every prefix is legal (ADR-0012).
            for length in 1...path.count {
                XCTAssertEqual(
                    Movement.validatePath(Array(path.prefix(length)), for: id, in: state),
                    nil,
                    "prefix \(length) of \(path)")
            }
        }
        // On the node-free east chart, enumeration from (-4,1) yields
        // exactly the straight walks the field allows: the row-1 rays
        // give three stops east; the atoll refractions leave every
        // other direction blocked or calm. Assert the row-1 walks and
        // that everything enumerated validates.
        let plain = TestStates.state(
            chart, islands: [], canoes: TestStates.canoes(sea: [(.p1, 0, Hex(-4, 1))]))
        let plainPaths = Movement.paths(for: CanoeID(player: .p1, index: 0), in: plain)
        XCTAssertTrue(plainPaths.contains([Hex(-3, 1), Hex(-2, 1), Hex(-1, 1)]))
        XCTAssertTrue(plainPaths.contains([Hex(-3, 1), Hex(-2, 1)]))
        XCTAssertTrue(plainPaths.contains([Hex(-3, 1)]))
        XCTAssertLessThanOrEqual(plainPaths.count, 6 * Balance.sailRange)
    }

    func test_R8_sailingABecalmedCanoeIsIllegal() {
        let state = TestStates.state(
            chart, islands: [],
            canoes: TestStates.canoes(
                sea: [(.p1, 0, Hex(-2, -1))], becalmed: [CanoeID(player: .p1, index: 0)]))
        XCTAssertEqual(
            Reducer.reason(
                .sail(CanoeID(player: .p1, index: 0), [Hex(-1, -1)]), in: state),
            .becalmedCanoe(CanoeID(player: .p1, index: 0)))
    }
}
