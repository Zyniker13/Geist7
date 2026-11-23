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

    // MARK: A.5's node-control term — ships at weight 0 (ADR-0024)
    //
    // The BFS distance map already prices node chains as free, so any
    // adjacency weight ≥ ~2 makes hovering on node cells strictly
    // better than advancing (measured: the +4 term left seed-3
    // self-play at 22 506 plies without ending), and +1 degenerates to
    // no preference. These tests pin the zero weight from both sides.

    /// The corridor state with two nodes OFF the sail corridor (their
    /// strength-2 cells give no shorter route to either atoll, so the
    /// distance terms match the nodeless baseline exactly): (0,1)
    /// sits beside two p1 canoes — (0,0) and (1,0) — and (-1,-1)
    /// beside (-2,0) and (0,0).
    private func nodeControlPair() -> (without: GameState, with: GameState) {
        let chart = Fixtures.chart()
        let locations: [CanoeID: CanoeLocation] = [
            CanoeID(player: .p1, index: 0): .sea(Hex(-2, 0)),
            CanoeID(player: .p1, index: 1): .sea(Hex(0, 0)),
            CanoeID(player: .p1, index: 2): .sea(Hex(1, 0)),
        ]
        var baseStrong: [Hex: Int] = [:]
        for q in -2...2 { baseStrong[Hex(q, 0)] = 1 }
        let base = Fixtures.state(
            chart: chart, field: Fixtures.field(strong: baseStrong), locations: locations)
        var withStrong = baseStrong
        withStrong[Hex(0, 1)] = 2
        withStrong[Hex(-1, -1)] = 2
        let with = Fixtures.state(
            chart: chart,
            field: Fixtures.field(
                strong: withStrong, nodes: [Hex(0, 1), Hex(-1, -1)]),
            locations: locations)
        return (base, with)
    }

    func testNodeControlTermShipsAtWeightZero() {
        let (base, with) = nodeControlPair()
        // Two distinct nodes adjacent to p1's canoes change nothing:
        // the adjacency bonus is 0 (ADR-0024), and the distance terms
        // are identical by construction.
        XCTAssertEqual(Evaluator.side(state: with, player: .p1),
                       Evaluator.side(state: base, player: .p1))
        XCTAssertEqual(Evaluator.side(state: with, player: .p2),
                       Evaluator.side(state: base, player: .p2))
    }

    func testNodeAdjacencyContributesNothingEvenWhenAdjacencyChanges() {
        let (base, with) = nodeControlPair()
        // Sending the middle canoe home removes one canoe's adjacency
        // to node (0,1) and its whole distance credit (27 for (0,0)):
        // the score must move by EXACTLY −27. Any nonzero adjacency
        // weight would show up as an extra term here.
        var solo = with
        solo.canoes[CanoeID(player: .p1, index: 1)] = CanoeState(
            owner: .p1, location: .home, becalmed: false)
        XCTAssertEqual(
            Evaluator.side(state: solo, player: .p1)
                - Evaluator.side(state: with, player: .p1), -27)
    }

    func testRivalNodeAdjacencyLeavesTheScoreUnchanged() {
        let chart = Fixtures.chart()
        var strong: [Hex: Int] = [:]
        for q in -2...2 { strong[Hex(q, 0)] = 1 }
        strong[Hex(2, 1)] = 2  // beside p2's canoe at (2,0)
        let locations: [CanoeID: CanoeLocation] = [
            CanoeID(player: .p2, index: 0): .sea(Hex(2, 0))
        ]
        var baseStrong = strong
        baseStrong[Hex(2, 1)] = nil
        let base = Fixtures.state(
            chart: chart, field: Fixtures.field(strong: baseStrong), locations: locations)
        let with = Fixtures.state(
            chart: chart,
            field: Fixtures.field(strong: strong, nodes: [Hex(2, 1)]),
            locations: locations)
        // A node adjacent to the RIVAL's canoe changes nothing either:
        // the term is 0 from every side (ADR-0024).
        XCTAssertEqual(Evaluator.score(state: with, for: .p1),
                       Evaluator.score(state: base, for: .p1))
        XCTAssertEqual(Evaluator.score(state: with, for: .p2),
                       Evaluator.score(state: base, for: .p2))
    }

    // MARK: A.5's poolTempo term (+2 for the side to move on an odd pool)

    func testPoolTempoRewardsTheSideToMoveOnAnOddPool() {
        let chart = Fixtures.chart()
        let field = Fixtures.corridor()
        let even = Fixtures.state(chart: chart, field: field, pool: 4, toMove: .p1)
        let odd = Fixtures.state(chart: chart, field: field, pool: 5, toMove: .p1)
        // p1 to move on an odd pool: p1 takes the last island (+2/-2).
        XCTAssertEqual(
            Evaluator.score(state: odd, for: .p1)
                - Evaluator.score(state: even, for: .p1), 2)
        XCTAssertEqual(
            Evaluator.score(state: odd, for: .p2)
                - Evaluator.score(state: even, for: .p2), -2)
        // An even pool carries no tempo term for either side.
        XCTAssertEqual(
            Evaluator.score(state: even, for: .p1),
            Evaluator.score(state: even, for: .p2))
    }
}
