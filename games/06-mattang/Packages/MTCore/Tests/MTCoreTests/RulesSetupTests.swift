// RulesSetupTests.swift — R-1/R-2 setup, chart validation, and the
// byte-stable Codable of GameState (ADR-0009).

import XCTest

@testable import MTCore

final class RulesSetupTests: XCTestCase {
    // MARK: R-1/R-2 — the initial state

    func test_R1_R2_initialState() {
        let chart = TestCharts.validated(TestCharts.eastOnly())
        let state = Reducer.initial(chart: chart)
        // R-2: ten islands in the pool, four canoes per player at home.
        XCTAssertEqual(state.poolRemaining, Balance.islandPool)
        for player in PlayerID.allCases {
            XCTAssertEqual(state.homeCanoeIDs(owner: player).count, Balance.canoesPerPlayer)
            XCTAssertEqual(state.seaCanoeIDs(owner: player).count, 0)
            XCTAssertEqual(state.landed[player], 0)
            for id in state.homeCanoeIDs(owner: player) {
                XCTAssertEqual(state.canoe(id).owner, player)
                XCTAssertEqual(state.canoe(id).location, .home)
                XCTAssertEqual(state.canoe(id).becalmed, false)
            }
        }
        // R-1: the chart's pre-islands are on the board; the field is
        // the traced field of that board.
        XCTAssertEqual(state.islands, chart.preIslands)
        XCTAssertEqual(
            state.field,
            Field.compute(
                ocean: chart.ocean, swells: chart.swells,
                islands: chart.preIslands, atollCells: chart.atollCells))
        // R-11: player 1 moves first; the game is ongoing.
        XCTAssertEqual(state.toMove, .p1)
        XCTAssertEqual(state.status, .ongoing)
        XCTAssertEqual(state.stuckTurns, 0)
        // R-23 (ADR-0013): the starting position is counted once.
        XCTAssertEqual(state.visited, [Zobrist.positionKey(of: state): 1])
    }

    // MARK: Chart validation (§5 ChartDef guard)

    func test_chartValidation_rejectsBrokenCharts() {
        let good = TestCharts.eastOnly()
        XCTAssertEqual(good.validate(), [])

        func variant(_ mutate: (inout Chart) -> Void) -> [String] {
            var chart = good
            mutate(&chart)
            return chart.validate()
        }
        // Chart's properties are lets; rebuild broken variants.
        func broken(
            id: String? = nil, radius: Int? = nil, swells: [Swell]? = nil,
            preIslands: Set<Hex>? = nil, atolls: [Atoll]? = nil
        ) -> [String] {
            let chart = Chart(
                id: id ?? good.id, radius: radius ?? good.radius,
                swells: swells ?? good.swells, preIslands: preIslands ?? good.preIslands,
                atolls: atolls ?? good.atolls, symmetry: good.symmetry)
            return chart.validate()
        }
        XCTAssertFalse(broken(radius: 1).isEmpty, "radius too small")
        XCTAssertFalse(broken(swells: []).isEmpty, "no swells")
        XCTAssertFalse(
            broken(swells: [
                Swell.major(id: "east_dom", entrySide: 0, direction: 3),
                Swell.major(id: "east_dom", entrySide: 3, direction: 0),
            ]).isEmpty,
            "duplicate swell ids")
        XCTAssertFalse(broken(atolls: []).isEmpty, "missing atolls")
        XCTAssertFalse(
            broken(atolls: [
                Atoll(player: .p1, cells: good.atoll(for: .p1).cells),
                Atoll(player: .p1, cells: good.atoll(for: .p2).cells),
            ]).isEmpty,
            "both atolls for one player")
        XCTAssertFalse(
            broken(atolls: [
                Atoll(player: .p1, cells: [Hex(9, 9), Hex(9, 8), Hex(8, 9)]),
                good.atoll(for: .p2),
            ]).isEmpty,
            "atoll outside the ocean")
        XCTAssertFalse(
            broken(preIslands: [Hex(9, 9)]).isEmpty,
            "pre-island outside the ocean")
        XCTAssertFalse(
            broken(preIslands: good.atoll(for: .p2).cells).isEmpty,
            "pre-island overlapping an atoll")
    }

    // MARK: ADR-0009 — byte-stable Codable

    func test_ADR0009_encodingIsByteStable() throws {
        let chart = TestCharts.validated(TestCharts.eastAndDiagonal())
        let state = Reducer.initial(chart: chart)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let first = try encoder.encode(state)
        let second = try encoder.encode(state)
        XCTAssertEqual(first, second, "two encodings of one state differ")

        let decoded = try JSONDecoder().decode(GameState.self, from: first)
        XCTAssertEqual(decoded, state, "decode(encode(state)) != state")
        XCTAssertEqual(try encoder.encode(decoded), first, "re-encoding differs")

        // Two structurally equal states built independently encode
        // identically.
        let twin = Reducer.initial(chart: chart)
        XCTAssertEqual(try encoder.encode(twin), first)
    }

    func test_ADR0009_landedAndSeaCanoeStatesRoundTrip() throws {
        let chart = TestCharts.validated(TestCharts.eastOnly())
        let state = TestStates.state(
            chart,
            islands: [Hex(0, 1)],
            canoes: TestStates.canoes(
                sea: [(.p1, 0, Hex(-3, 1)), (.p2, 1, Hex(3, 0))],
                landed: [(.p1, 3)],
                becalmed: [CanoeID(player: .p1, index: 0)]))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(decoded, state)
        XCTAssertEqual(decoded.landed[.p1], 1)
        XCTAssertTrue(decoded.canoe(CanoeID(player: .p1, index: 0)).becalmed)
    }
}
