// SailorTests.swift — the 1-ply tier: landing preference, seeded
// tie-break, and full self-play through the real reducer.

import XCTest
@testable import MTAI
import MTCore

final class SailorTests: XCTestCase {
    func testSailorTakesTheLanding() {
        let chart = Fixtures.chart()
        let id = CanoeID(player: .p1, index: 0)
        let state = Fixtures.state(
            chart: chart,
            field: Fixtures.corridor(),
            locations: [id: .sea(Hex(2, 0))])
        let landing = Action.sail(id, [Hex(3, -1)])
        XCTAssertTrue(
            Reducer.legalActions(in: state).contains(landing),
            "the landing path is legal in the fixture state")

        // Landing is the strict maximum (its successor scores 172
        // against at most 100 for the corridor sails), so the choice
        // must not depend on the seed.
        var rng = SeededRNG(seed: 7)
        let chosen = Sailor().chooseAction(in: state, rng: &rng)
        XCTAssertEqual(chosen, landing)
        for seed: UInt64 in 0..<10 {
            var seeded = SeededRNG(seed: seed)
            XCTAssertEqual(
                Sailor().chooseAction(in: state, rng: &seeded), chosen,
                "landing stays the strict maximum for seed \(seed)")
        }
    }

    func testTieBreakIsSeededAndDeterministic() {
        let chart = Fixtures.chart()
        let x = CanoeID(player: .p1, index: 0)
        let y = CanoeID(player: .p1, index: 1)
        // Only (0,1) is strong: x is becalmed on the calm cell (1,0)
        // with y alongside to tow. Every tow target is calm, so x
        // stays becalmed (-8) and the field never changes: all five
        // tows evaluate identically and the rng must break the tie.
        let state = Fixtures.state(
            chart: chart,
            field: Fixtures.field(strong: [Hex(0, 1): 1]),
            locations: [x: .sea(Hex(1, 0)), y: .sea(Hex(0, 1))],
            becalmed: [x])
        let expected: Set<Action> = [
            .tow(x, Hex(0, 0)),
            .tow(x, Hex(1, -1)),
            .tow(x, Hex(1, 1)),
            .tow(x, Hex(2, -1)),
            .tow(x, Hex(2, 0)),
        ]
        let actions = Reducer.legalActions(in: state)
        XCTAssertEqual(Set(actions), expected, "the five tows are the only legal actions")

        var first = SeededRNG(seed: 7)
        let a = Sailor().chooseAction(in: state, rng: &first)
        var second = SeededRNG(seed: 7)
        let b = Sailor().chooseAction(in: state, rng: &second)
        XCTAssertEqual(a, b, "same seed, same choice")
        XCTAssertTrue(expected.contains(a), "the choice is one of the tied tows")

        var distinct: Set<Action> = []
        for seed: UInt64 in 0..<60 {
            var rng = SeededRNG(seed: seed)
            distinct.insert(Sailor().chooseAction(in: state, rng: &rng))
        }
        XCTAssertGreaterThanOrEqual(
            distinct.count, 2, "the tie-break varies with the seed")
    }

    func testSelfPlayCompletesAndConservesCanoes() throws {
        // One full game on the real slice chart (the integration
        // case), then breadth on a small chart: radius-3 games are
        // ~100× cheaper per ply than the radius-7 slice, and the
        // engine surface under test is the same.
        let slice = Fixtures.sliceChart()
        for seed: UInt64 in [3] {
            var rng = SeededRNG(seed: seed)
            var state = Reducer.initial(chart: slice)
            var plies = 0
            while !state.status.isOver {
                plies += 1
                XCTAssertLessThan(plies, 800, "seed \(seed) did not finish")
                let action = Sailor().chooseAction(in: state, rng: &rng)
                state = try Reducer.apply(action, to: state).state
            }
            for player in PlayerID.allCases {
                var count = state.landed[player] ?? 0
                for id in CanoeID.allCanoeIDs where id.player == player {
                    if case .landed = state.canoe(id).location {} else { count += 1 }
                }
                XCTAssertEqual(count, 4, "INV-3 for \(player) at seed \(seed)")
            }
        }

        let small = Fixtures.chart(
            swells: [
                Swell.major(id: "e", entrySide: 0, direction: 3),
                Swell.minor(id: "n", entrySide: 4, direction: 1),
            ])
        for seed: UInt64 in 1...10 {
            var rng = SeededRNG(seed: seed)
            var state = Reducer.initial(chart: small)
            var plies = 0
            while !state.status.isOver {
                plies += 1
                XCTAssertLessThan(plies, 400, "seed \(seed) did not finish")
                let action = Sailor().chooseAction(in: state, rng: &rng)
                state = try Reducer.apply(action, to: state).state
            }
            for player in PlayerID.allCases {
                var count = state.landed[player] ?? 0
                for id in CanoeID.allCanoeIDs where id.player == player {
                    if case .landed = state.canoe(id).location {} else { count += 1 }
                }
                XCTAssertEqual(count, 4, "INV-3 for \(player) at seed \(seed)")
            }
        }
    }

    func testSelfPlayIsReproducibleUnderSeed() throws {
        // Determinism is a property of the engine+AI pair, not of the
        // board size: the small chart keeps this test cheap.
        let small = Fixtures.chart(
            swells: [
                Swell.major(id: "e", entrySide: 0, direction: 3),
                Swell.minor(id: "n", entrySide: 4, direction: 1),
            ])
        func play(_ seed: UInt64) throws -> GameStatus {
            var rng = SeededRNG(seed: seed)
            var state = Reducer.initial(chart: small)
            while !state.status.isOver {
                let action = Sailor().chooseAction(in: state, rng: &rng)
                state = try Reducer.apply(action, to: state).state
            }
            return state.status
        }
        XCTAssertEqual(try play(3), try play(3), "same seed, same game")
    }
}
