// EvaluatorTests.swift — §7/A.5's terms against hand-authored states.
//
// side = landed×100 + Σ best-3 (30 − distance) − 8·becalmed, with home
// canoes contributing 30 − (1 + best launch cell's distance).

import MTCore
import XCTest

@testable import MTAI

final class EvaluatorTests: XCTestCase {
    /// p1 canoes on the corridor at distances 5, 4, 3, 2; p2 all home
    /// with (2,0) — its only strong launch cell — empty.
    private func corridorState(landed p1Landed: Int = 0) -> (Chart, GameState) {
        let chart = Fixtures.chart()
        let state = Fixtures.state(
            chart: chart,
            field: Fixtures.corridor(),
            locations: [
                CanoeID(player: .p1, index: 0): .sea(Hex(-2, 0)),
                CanoeID(player: .p1, index: 1): .sea(Hex(-1, 0)),
                CanoeID(player: .p1, index: 2): .sea(Hex(0, 0)),
                CanoeID(player: .p1, index: 3): .sea(Hex(1, 0)),
            ],
            landed: [.p1: p1Landed, .p2: 0])
        return (chart, state)
    }

    func testBestThreeDistanceCredit() {
        let (_, state) = corridorState()
        // Best three of {25, 26, 27, 28} sum to 81. p2's home canoes
        // measure to the RIVAL (p1's) atoll across the corridor: the
        // launch into (2,0) plus 5 = 6, so 3 × (30 − 6) = 72.
        XCTAssertEqual(Evaluator.side(state: state, player: .p1), 81)
        XCTAssertEqual(Evaluator.side(state: state, player: .p2), 72)
        XCTAssertEqual(Evaluator.score(state: state, for: .p1), 9)
        XCTAssertEqual(Evaluator.score(state: state, for: .p2), -9)
    }

    func testLandedCanoeAddsItsHundred() {
        let (chart, _) = corridorState()
        // Three sea canoes (25 + 26 + 27 = 78) plus one landed: the
        // landed canoe is off the board, so only its 100 counts.
        let state = Fixtures.state(
            chart: chart,
            field: Fixtures.corridor(),
            locations: [
                CanoeID(player: .p1, index: 0): .sea(Hex(-2, 0)),
                CanoeID(player: .p1, index: 1): .sea(Hex(-1, 0)),
                CanoeID(player: .p1, index: 2): .sea(Hex(0, 0)),
                CanoeID(player: .p1, index: 3): .landed,
            ],
            landed: [.p1: 1, .p2: 0])
        XCTAssertEqual(Evaluator.side(state: state, player: .p1), 178)
    }

    func testBecalmedCanoeIsPenalisedAndExcluded() {
        let chart = Fixtures.chart()
        // p1/3 sits becalmed on the calm cell (3,0): excluded from the
        // distance sum, minus 8. The corridor's three canoes give 78.
        let state = Fixtures.state(
            chart: chart,
            field: Fixtures.corridor(),
            locations: [
                CanoeID(player: .p1, index: 0): .sea(Hex(-2, 0)),
                CanoeID(player: .p1, index: 1): .sea(Hex(-1, 0)),
                CanoeID(player: .p1, index: 2): .sea(Hex(0, 0)),
                CanoeID(player: .p1, index: 3): .sea(Hex(3, 0)),
            ],
            becalmed: [CanoeID(player: .p1, index: 3)])
        XCTAssertEqual(Evaluator.side(state: state, player: .p1), 70)
    }

    func testHomeCanoesPayTheLaunchAndShareTheBestLaunchCell() {
        let chart = Fixtures.chart()
        let field = Fixtures.corridor()
        // All four home: each shares the best launch cell (-2,0) at
        // distance 5, paying 1 for the launch → 24 each; best three
        // sum to 72.
        let allHome = Fixtures.state(chart: chart, field: field)
        XCTAssertEqual(Evaluator.side(state: allHome, player: .p1), 72)

        // p1/0 at sea on (2,0) (distance 1 → 29); the three home
        // canoes still share 24: best three of {29, 24, 24, 24} = 77.
        // p2's only strong launch cell (2,0) is now occupied, so its
        // home canoes contribute nothing.
        let oneAtSea = Fixtures.state(
            chart: chart,
            field: field,
            locations: [CanoeID(player: .p1, index: 0): .sea(Hex(2, 0))])
        XCTAssertEqual(Evaluator.side(state: oneAtSea, player: .p1), 77)
        XCTAssertEqual(Evaluator.side(state: oneAtSea, player: .p2), 0)
    }
}
