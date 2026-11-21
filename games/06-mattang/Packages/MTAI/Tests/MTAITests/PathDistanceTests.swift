// PathDistanceTests.swift — the turn-metric over hand-authored fields.
//
// Every expected value is derived by hand from the fixture's cell
// list: adjacent strong cells cost 1, node-to-node steps cost 0, and
// entering a rival atoll cell (the landing step, R-10) counts 1.

import XCTest
@testable import MTAI
import MTCore

final class PathDistanceTests: XCTestCase {
    func testStraightCorridorCostsOneStepPerCell() {
        let chart = Fixtures.chart()
        let state = Fixtures.state(chart: chart, field: Fixtures.corridor())
        let rival = chart.atoll(for: .p2).cells
        // Four corridor steps (-2,0)…(2,0) plus the landing on (3,-1).
        XCTAssertEqual(PathDistance.distance(from: Hex(-2, 0), to: rival, in: state), 5)
        XCTAssertEqual(PathDistance.distance(from: Hex(2, 0), to: rival, in: state), 1)
    }

    func testNodeChainStepsCostNothing() {
        let chart = Fixtures.chart()
        let field = Fixtures.corridor(nodes: [Hex(-1, 0), Hex(0, 0), Hex(1, 0)])
        let state = Fixtures.state(chart: chart, field: field)
        let rival = chart.atoll(for: .p2).cells
        // (-2,0)→(-1,0) costs 1, the chain (-1,0)→(0,0)→(1,0) rides
        // free, then (1,0)→(2,0) and the landing cost 1 each: 1 + 0 +
        // 0 + 1 + 1 = 3.
        XCTAssertEqual(PathDistance.distance(from: Hex(-2, 0), to: rival, in: state), 3)
        // Already on the chain: two cost-1 steps remain.
        XCTAssertEqual(PathDistance.distance(from: Hex(-1, 0), to: rival, in: state), 2)
    }

    func testCalmGapBlocksTheRoute() {
        let chart = Fixtures.chart()
        let state = Fixtures.state(chart: chart, field: Fixtures.corridor(gaps: [Hex(1, 0)]))
        let rival = chart.atoll(for: .p2).cells
        // The gap splits the corridor: nothing west of it reaches the
        // rival atoll, the east end still lands in one step.
        XCTAssertNil(PathDistance.distance(from: Hex(-2, 0), to: rival, in: state))
        XCTAssertNil(PathDistance.distance(from: Hex(0, 0), to: rival, in: state))
        XCTAssertEqual(PathDistance.distance(from: Hex(2, 0), to: rival, in: state), 1)
    }

    func testDetourAroundGapRoutesThroughNodeChain() {
        let chart = Fixtures.chart()
        var strong: [Hex: Int] = [:]
        for cell in [Hex(-2, 0), Hex(-1, 0), Hex(2, 0)] {
            strong[cell] = 1
        }
        for cell in [Hex(-1, 1), Hex(0, 1), Hex(1, 1)] {
            strong[cell] = 2
        }
        let nodes: Set<Hex> = [Hex(-1, 1), Hex(0, 1), Hex(1, 1)]
        let state = Fixtures.state(
            chart: chart, field: Fixtures.field(strong: strong, nodes: nodes))
        let rival = chart.atoll(for: .p2).cells
        // (-2,0)→(-1,0) costs 1, (-1,0)→(-1,1) enters the chain for
        // 1, the chain (-1,1)→(0,1)→(1,1) rides free, then (1,1)→(2,0)
        // and the landing cost 1 each: 1 + 1 + 0 + 0 + 1 + 1 = 4.
        XCTAssertEqual(PathDistance.distance(from: Hex(-2, 0), to: rival, in: state), 4)
    }

    func testStartOnATargetCellCostsNothing() {
        let chart = Fixtures.chart()
        let state = Fixtures.state(chart: chart, field: Fixtures.corridor())
        let rival = chart.atoll(for: .p2).cells
        XCTAssertEqual(PathDistance.distance(from: Hex(3, -1), to: rival, in: state), 0)
    }
}
