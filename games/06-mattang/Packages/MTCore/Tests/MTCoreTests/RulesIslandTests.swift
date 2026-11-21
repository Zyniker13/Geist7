// RulesIslandTests.swift — R-7 island placement, R-21 enclosure, R-22
// pre-placed islands, and the pool.

import XCTest

@testable import MTCore

final class RulesIslandTests: XCTestCase {
    private var chart: Chart { TestCharts.validated(TestCharts.eastOnly()) }

    // MARK: R-7 — a legal placement

    func test_R7_legalPlacement_decrementsPoolAndTraces() {
        var state = Reducer.initial(chart: chart)
        let cell = Hex(2, -3)  // open sea, clear of islands and atolls
        XCTAssertEqual(Reducer.reason(.placeIsland(cell), in: state), nil)

        let (next, events) = TestStates.apply(.placeIsland(cell), to: state)
        XCTAssertEqual(next.islands, state.islands.union([cell]))
        XCTAssertEqual(next.poolRemaining, state.poolRemaining - 1)
        XCTAssertEqual(events, [.islandPlaced(cell)])
        XCTAssertEqual(next.toMove, .p2)
        // The field changed: the placed island's neighbourhood is
        // re-traced, and the result equals a full recompute (INV-2).
        XCTAssertEqual(
            next.field,
            Field.compute(
                ocean: chart.ocean, swells: chart.swells,
                islands: next.islands, atollCells: chart.atollCells))
        state = next
    }

    func test_R7_illegalReasons() {
        let state = Reducer.initial(chart: chart)
        // Outside the ocean.
        XCTAssertEqual(
            Reducer.reason(.placeIsland(Hex(9, 9)), in: state), .cellNotInOcean(Hex(9, 9)))
        // On an atoll cell.
        let atollCell = require(chart.atoll(for: .p2).cells.first, "empty atoll")
        XCTAssertEqual(
            Reducer.reason(.placeIsland(atollCell), in: state), .cellOccupied(atollCell))
        // Adjacent to an atoll (the reason names whichever atoll cell
        // the neighbour scan meets first).
        let nearAtoll = require(
            atollCell.neighbors().first {
                chart.ocean.contains($0) && !chart.atollCells.contains($0)
            },
            "atoll with no free neighbour")
        let atollReason = Reducer.reason(.placeIsland(nearAtoll), in: state)
        guard case .adjacentToAtoll(let blocked)? = atollReason else {
            XCTFail("expected adjacentToAtoll, got \(String(describing: atollReason))")
            return
        }
        XCTAssertTrue(chart.atollCells.contains(blocked))
        // Adjacent to a pre-placed island (R-22 keeps them permanent).
        if let pre = chart.preIslands.first {
            let neighbor = require(
                pre.neighbors().first {
                    chart.ocean.contains($0) && !chart.atollCells.contains($0)
                },
                "pre-island with no free neighbour")
            XCTAssertEqual(
                Reducer.reason(.placeIsland(neighbor), in: state),
                .adjacentToIsland(pre))
        }
        // On a canoe.
        let occupied = TestStates.state(
            chart, islands: [],
            canoes: TestStates.canoes(sea: [(.p2, 0, Hex(2, -3))]))
        XCTAssertEqual(
            Reducer.reason(.placeIsland(Hex(2, -3)), in: occupied),
            .cellHasCanoe(Hex(2, -3)))
    }

    func test_R7_poolEmptiesAfterTenPlacements() {
        var state = Reducer.initial(chart: chart)
        // Ten placements by alternating players on scattered open
        // cells (pairwise non-adjacent, clear of the atolls).
        let cells: [Hex] = [
            Hex(2, -3), Hex(-2, -2), Hex(0, -4), Hex(4, -4), Hex(-4, -1),
            Hex(2, 1), Hex(-3, 0), Hex(3, 2), Hex(0, 2), Hex(2, -5),
        ]
        for (index, cell) in cells.enumerated() {
            XCTAssertEqual(state.poolRemaining, Balance.islandPool - index)
            state = TestStates.apply(.placeIsland(cell), to: state).state
        }
        XCTAssertEqual(state.poolRemaining, 0)
        XCTAssertEqual(
            Reducer.reason(.placeIsland(Hex(0, -3)), in: state),
            .poolEmpty,
            "an eleventh placement is illegal")
        // The pool being empty also removes placements from the legal
        // list while other actions may remain.
        XCTAssertTrue(Reducer.legalActions(in: state).allSatisfy { !$0.isPass })
    }

    // MARK: R-21 — no fully enclosed canoes

    func test_R21_placementMayNotSealACanoesLastNeighbour() {
        // A P1 canoe at (2,-3) whose five other neighbours are held by
        // canoes (R-20: canoes block); the sixth, (3,-3), is its only
        // escape. Placing an island there would leave the canoe with no
        // adjacent enterable cell at all (R-21). Canoe blockers are the
        // constructible case: island blockers beside the escape cell
        // would trip the R-7 adjacency ban first.
        let canoes = TestStates.canoes(
            sea: [
                (.p1, 0, Hex(2, -3)),
                (.p2, 0, Hex(2, -2)), (.p2, 1, Hex(1, -2)),
                (.p2, 2, Hex(1, -3)), (.p2, 3, Hex(2, -4)),
                (.p1, 1, Hex(3, -4)),
            ])
        let state = TestStates.state(chart, islands: [], canoes: canoes)
        XCTAssertEqual(
            Reducer.reason(.placeIsland(Hex(3, -3)), in: state),
            .fullyEncloses(CanoeID(player: .p1, index: 0)))
        // A placement elsewhere is fine.
        XCTAssertEqual(Reducer.reason(.placeIsland(Hex(-2, -3)), in: state), nil)
    }

    func test_R21_homeCanoesKeepALaunchCell() {
        // Every launch cell of an atoll is, by R-17's definition,
        // adjacent to an atoll cell — so R-7's adjacentToAtoll ban
        // already forbids placing an island there, and the R-21
        // home-canoe clause can never fire through a placement. Assert
        // that ban for every candidate cell around both atolls (the
        // reason names whichever atoll cell the check meets first).
        let state = Reducer.initial(chart: chart)
        for player in PlayerID.allCases {
            let atollCells = chart.atoll(for: player).cells
            for atollCell in atollCells {
                for cell in atollCell.neighbors() {
                    guard chart.ocean.contains(cell), !chart.atollCells.contains(cell) else {
                        continue
                    }
                    let reason = Reducer.reason(.placeIsland(cell), in: state)
                    guard case .adjacentToAtoll(let blocked)? = reason else {
                        XCTFail(
                            "placement beside \(player)'s atoll not banned: \(String(describing: reason))"
                        )
                        continue
                    }
                    XCTAssertTrue(atollCells.contains(blocked), "banned by \(blocked)")
                }
            }
        }
        // INV-7 (Chart.validate): a chart whose atoll has no launchable
        // sea neighbour is rejected outright — here pre-placed islands
        // seal P2's atoll, and validation refuses the chart.
        let sealed = Chart(
            id: "test_sealed_atoll", radius: 5,
            swells: [Swell.major(id: "east_dom", entrySide: 0, direction: 3)],
            preIslands: [
                Hex(5, 0), Hex(4, 0), Hex(4, -1), Hex(5, -3),
                Hex(3, -1), Hex(3, -2), Hex(4, -3),
            ],
            atolls: TestCharts.atolls(radius: 5), symmetry: .rotate180)
        XCTAssertEqual(sealed.validate(), ["atoll for p2 has no launchable sea cell"])
    }

    // MARK: R-22 — pre-placed islands are permanent

    func test_R22_preIslandsArePermanentAndCounted() {
        let chart = TestCharts.validated(TestCharts.rotatePair())
        XCTAssertEqual(chart.preIslands.count, 3)
        let state = Reducer.initial(chart: chart)
        XCTAssertEqual(state.islands, chart.preIslands)
        // The pool still holds ten fresh islands (R-2); pre-islands do
        // not consume it.
        XCTAssertEqual(state.poolRemaining, Balance.islandPool)
        // R-22: pre-islands reflect rays like any island — the tracer
        // fixtures cover the optics; here assert the state never loses
        // them through play.
        var running = state
        for cell in [Hex(3, -3), Hex(-2, -3), Hex(1, -3)] {
            guard Reducer.isLegal(.placeIsland(cell), in: running) else {
                XCTFail("placement at \(cell) should be legal")
                return
            }
            running = TestStates.apply(.placeIsland(cell), to: running).state
        }
        XCTAssertTrue(chart.preIslands.isSubset(of: running.islands))
    }
}
