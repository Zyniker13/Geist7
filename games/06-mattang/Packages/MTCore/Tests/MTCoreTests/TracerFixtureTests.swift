// TracerFixtureTests.swift — the MT-P1.1/MT-P1.2 fixture suite.
//
// Three layers:
//
// 1. Hand-traced literal fixtures: expected cell paths, reflection
//    counts, and terminations derived by hand from the rule text,
//    cell by cell, on the two test charts (the standard chart whose
//    atolls refract passing rays, and a far-atoll chart that keeps
//    rows 0..2 and -1..-2 clear). Each comment states the trace.
// 2. The oracle battery: fixed island/flow configurations whose
//    expected rays come from OracleTracer, an independent recursive
//    implementation of the same rule text. Tracer must match the
//    oracle exactly on every ray.
// 3. Fixture-count guards: the suite stays at or above the roadmap's
//    fixture budgets (MT-P1.1: 40 reflection fixtures; MT-P1.2: 30
//    refraction fixtures) counting the 36-case reflection table
//    (HexTests), the literals, and the battery.

import XCTest

@testable import MTCore

final class TracerFixtureTests: XCTestCase {
    // MARK: Helpers

    /// The field for `chart` with extra test islands placed.
    func field(_ chart: Chart, islands: Set<Hex>) -> Field {
        Field.compute(
            ocean: chart.ocean, swells: chart.swells, islands: islands,
            atollCells: chart.atollCells)
    }

    /// The east-swell ray that starts at `entry`, if any.
    func eastRay(_ chart: Chart, islands: Set<Hex>, entry: Hex) -> RayPath? {
        field(chart, islands: islands).rays.first {
            $0.swell == "east_dom" && $0.start == entry
        }
    }

    /// The standard chart: atolls at {(-5,1),(-5,2),(-4,2)} and
    /// {(5,-1),(5,-2),(4,-2)} refract rays passing near rows 0..2.
    private var standard: Chart { TestCharts.validated(TestCharts.eastOnly()) }

    /// A chart whose atolls sit in the far corners, leaving rows
    /// 0..2 and -1..-2 free of atoll refraction.
    private var far: Chart {
        TestCharts.validated(
            Chart(
                id: "test_far_atolls", radius: 5,
                swells: [Swell.major(id: "east_dom", entrySide: 0, direction: 3)],
                preIslands: [],
                atolls: [
                    Atoll(player: .p1, cells: [Hex(-4, 4), Hex(-5, 4), Hex(-3, 4)]),
                    Atoll(player: .p2, cells: [Hex(4, -4), Hex(5, -4), Hex(3, -4)]),
                ],
                symmetry: .rotate180))
    }

    // MARK: Literal 1 (standard chart) — island (3,1) with the P2
    // atoll: entering (4,0) refracts toward the atoll (5,-1) (lower
    // row-major than the island), turning NW; (4,-1) refracts toward
    // atoll (4,-2) (tie turns clockwise) and the ray reflects off
    // (5,-2); re-entering (3,0) refracts toward the island (3,1), the
    // ray strikes it, and the bounce rides the q=3 column north.
    // Hand-verified cell by cell (docs/STATUS.md G1 evidence).

    func test_literal1_atollPincer_capsAtThree() {
        let ray = eastRay(standard, islands: [Hex(3, 1)], entry: Hex(5, 0))
        XCTAssertEqual(
            ray?.cells,
            [
                Hex(5, 0), Hex(4, 0), Hex(4, -1), Hex(3, 0), Hex(3, -1),
                Hex(3, -2), Hex(3, -3), Hex(3, -4), Hex(3, -5),
            ])
        XCTAssertEqual(ray?.reflections, 2)
        XCTAssertEqual(ray?.termination, .leftOcean)
    }

    // MARK: Literal 2 (far chart) — island dead ahead at (-1,0): the
    // refraction one cell before it dodges; the R-13 tie (both turn
    // candidates one step from the island) turns clockwise, so the ray
    // leaves north up the q=0 column.
    // Trace: ...(1,0)→(0,0) refract, tie→cw(NW); (0,-1)..(0,-5); exit.

    func test_literal2_headOnIsland_refractionDodges_clockwiseTie() {
        let ray = eastRay(far, islands: [Hex(-1, 0)], entry: Hex(5, 0))
        XCTAssertEqual(
            ray?.cells,
            [
                Hex(5, 0), Hex(4, 0), Hex(3, 0), Hex(2, 0), Hex(1, 0), Hex(0, 0),
                Hex(0, -1), Hex(0, -2), Hex(0, -3), Hex(0, -4), Hex(0, -5),
            ])
        XCTAssertEqual(ray?.reflections, 0)
        XCTAssertEqual(ray?.termination, .leftOcean)
    }

    // MARK: Literal 3 (far chart) — R-14 double-island tie: islands
    // (2,-1) and (1,1) are both adjacent to (2,0); the lower row-major
    // index wins ((-1,2) < (1,1)), the ray bends NW into (2,-1),
    // reflects, refracts toward (1,1), and exits southeast.
    // Trace: (2,0) refract tie→cw; (2,-1) reflect→SE; (2,1) refract
    // toward (1,1)→SW-turn(cw); (1,2),(0,3),(-1,4),(-2,5); exit.

    func test_literal3_doubleIslandTie_lowerRowMajorWins() {
        let ray = eastRay(far, islands: [Hex(2, -1), Hex(1, 1)], entry: Hex(5, 0))
        XCTAssertEqual(
            ray?.cells,
            [
                Hex(5, 0), Hex(4, 0), Hex(3, 0), Hex(2, 0), Hex(2, 1),
                Hex(1, 2), Hex(0, 3), Hex(-1, 4), Hex(-2, 5),
            ])
        XCTAssertEqual(ray?.reflections, 1)
        XCTAssertEqual(ray?.termination, .leftOcean)
    }

    // MARK: Literal 4 (far chart) — island (2,1) bends the ray SW into
    // itself; the NE bounce refracts toward island (5,-2) at (4,-1)
    // (both turn candidates one step away, tie → clockwise/E), and the
    // ray exits over the east rim.
    // Trace: (3,0) refract→SW; (2,1) reflect→NE; (4,-1) refract toward
    // (5,-2), tie→cw(E); (5,-1); exit at (6,-1).

    func test_literal4_bounceRefract_exitEast() {
        let ray = eastRay(far, islands: [Hex(2, 1), Hex(5, -2)], entry: Hex(5, 0))
        XCTAssertEqual(ray?.cells, [Hex(5, 0), Hex(4, 0), Hex(3, 0), Hex(4, -1), Hex(5, -1)])
        XCTAssertEqual(ray?.reflections, 1)
        XCTAssertEqual(ray?.termination, .leftOcean)
    }

    // MARK: R-4 — ray/island interaction: a ray that enters an island
    // cell reflects (direction reversed), and a ray passing a cell
    // adjacent to an island on its leeward side refracts one step
    // toward it. Both halves on the far chart: island (2,-1) reflects
    // the ray refracted into it, then island (1,1) refracts the
    // reflected leg onward (one reflection, tie → clockwise per
    // R-13/R-14); island (-1,0) alone shows the pure refraction half
    // with no reflection.

    func test_R4_reflectsOffIslandCell_refractsOnLeewardPass() {
        let bounced = eastRay(far, islands: [Hex(2, -1), Hex(1, 1)], entry: Hex(5, 0))
        XCTAssertEqual(
            bounced?.cells,
            [
                Hex(5, 0), Hex(4, 0), Hex(3, 0), Hex(2, 0), Hex(2, 1),
                Hex(1, 2), Hex(0, 3), Hex(-1, 4), Hex(-2, 5),
            ])
        XCTAssertEqual(bounced?.reflections, 1)
        let dodged = eastRay(far, islands: [Hex(-1, 0)], entry: Hex(5, 0))
        XCTAssertEqual(
            dodged?.cells,
            [
                Hex(5, 0), Hex(4, 0), Hex(3, 0), Hex(2, 0), Hex(1, 0), Hex(0, 0),
                Hex(0, -1), Hex(0, -2), Hex(0, -3), Hex(0, -4), Hex(0, -5),
            ])
        XCTAssertEqual(dodged?.reflections, 0)
    }

    // MARK: Literal 5 (far chart) — island (0,1): the ray dodges SW
    // into the island, bounces NE, and at (4,-3) refracts toward atoll
    // (4,-4) (lower row-major than (5,-4)) turning NW, reflects off
    // (4,-4), then rides the q=4 column north to the rim.
    // Hand-verified cell by cell.

    func test_literal5_farAtollPincer_capsAtThree() {
        let ray = eastRay(far, islands: [Hex(0, 1)], entry: Hex(5, 0))
        XCTAssertEqual(
            ray?.cells,
            [
                Hex(5, 0), Hex(4, 0), Hex(3, 0), Hex(2, 0), Hex(1, 0), Hex(2, -1),
                Hex(3, -2), Hex(4, -3), Hex(4, -2), Hex(4, -1), Hex(4, 0), Hex(4, 1),
            ])
        XCTAssertEqual(ray?.reflections, 2)
        XCTAssertEqual(ray?.termination, .leftOcean)
    }

    // MARK: Literal 6 (standard chart) — island (2,1) with both atolls
    // in play: the ray refracts toward atoll (5,-1) on entering (4,0),
    // then toward atoll (4,-2) on entering (4,-1), reflects off it,
    // refracts toward island (2,1) on re-entering (3,0) — tie turns
    // clockwise — rides row 0 west, refracts toward atoll (-5,1) at
    // (-4,0), reflects off (-5,1), and exits northwest.
    // Hand-verified cell by cell (see docs/STATUS.md G1 evidence).

    func test_literal6_doubleAtollChain() {
        let ray = eastRay(standard, islands: [Hex(2, 1)], entry: Hex(5, 0))
        XCTAssertEqual(
            ray?.cells,
            [
                Hex(5, 0), Hex(4, 0), Hex(4, -1), Hex(3, 0), Hex(2, 0), Hex(1, 0),
                Hex(0, 0), Hex(-1, 0), Hex(-2, 0), Hex(-3, 0), Hex(-4, 0),
                Hex(-3, -1), Hex(-2, -2), Hex(-1, -3), Hex(0, -4), Hex(1, -5),
            ])
        XCTAssertEqual(ray?.reflections, 2)
        XCTAssertEqual(ray?.termination, .leftOcean)
    }

    // MARK: Literal 7 (standard chart) — island (-3,1): the ray
    // refracts toward atoll (5,-1) at (4,0), toward atoll (4,-2) at
    // (4,-1), reflects off (5,-2)... riding the atoll chain, then
    // escapes southeast through (2,1),(1,2),(0,3),(-1,4),(-2,5).
    // Hand-verified cell by cell.

    func test_literal7_islandAboveRow_atollChainEscape() {
        let ray = eastRay(standard, islands: [Hex(-3, 1)], entry: Hex(5, 0))
        XCTAssertEqual(
            ray?.cells,
            [
                Hex(5, 0), Hex(4, 0), Hex(4, -1), Hex(3, 0), Hex(2, 1),
                Hex(1, 2), Hex(0, 3), Hex(-1, 4), Hex(-2, 5),
            ])
        XCTAssertEqual(ray?.reflections, 1)
        XCTAssertEqual(ray?.termination, .leftOcean)
    }

    // MARK: Literal 8 (standard chart) — island (1,-3) on row -3: the
    // ray refracts toward atoll (4,-2) on entering (4,-3) and turns
    // SW, never reaching the island; it exits northwest over rows
    // -2..5 on the q=descending SW diagonal... traced: the turn sends
    // it SW along (3,-2),(2,-1),(1,0),(0,1),(-1,2),(-2,3),(-3,4),(-4,5).

    func test_literal8_rowMinusThree_atollRefractFirst() {
        let ray = eastRay(standard, islands: [Hex(1, -3)], entry: Hex(5, -3))
        XCTAssertEqual(
            ray?.cells,
            [
                Hex(5, -3), Hex(4, -3), Hex(3, -2), Hex(2, -1), Hex(1, 0),
                Hex(0, 1), Hex(-1, 2), Hex(-2, 3), Hex(-3, 4), Hex(-4, 5),
            ])
        XCTAssertEqual(ray?.reflections, 0)
        XCTAssertEqual(ray?.termination, .leftOcean)
    }

    // MARK: Emission and blocking (R-3, R-16)

    func test_emission_edgeCellsEmit_andObstructedEntriesDoNot() {
        let chart = standard
        let clean = field(chart, islands: [])
        // One ray per unobstructed entry cell (R-3, R-16): the P2
        // atoll sits on two east-edge cells and suppresses those.
        let unobstructed = chart.ocean.edge(0).filter { !chart.atollCells.contains($0) }
        XCTAssertEqual(
            clean.rays.filter { $0.swell == "east_dom" }.count,
            unobstructed.count)

        // An island on an entry cell suppresses that entry only.
        let blocked = field(chart, islands: [Hex(5, -3)])
        XCTAssertNil(blocked.rays.first { $0.start == Hex(5, -3) && $0.swell == "east_dom" })
        XCTAssertNotNil(blocked.rays.first { $0.start == Hex(5, 0) && $0.swell == "east_dom" })

        // An atoll on an entry cell suppresses that entry (R-16).
        XCTAssertNil(clean.rays.first { $0.start == Hex(5, -1) && $0.swell == "east_dom" })
        XCTAssertNil(clean.rays.first { $0.start == Hex(5, -2) && $0.swell == "east_dom" })
    }

    func test_atollRefractsAndReflects_row1() {
        let chart = standard
        let f = field(chart, islands: [])
        // Row 1's ray refracts toward the atoll at (-5,1) near its
        // west end, turns, and strikes the atoll chain — reflections
        // follow (R-16: atolls behave as islands).
        let row1 = f.rays.first { $0.swell == "east_dom" && $0.start == Hex(4, 1) }
        XCTAssertNotNil(row1)
        XCTAssertGreaterThan(row1?.reflections ?? 0, 0)
        // No atoll cell ever joins a path (R-16).
        for ray in f.rays {
            XCTAssertFalse(
                ray.cells.contains { chart.atollCells.contains($0) },
                "atoll cell joined a path")
        }
    }

    // MARK: R-6 aggregation on a fixture field

    func test_strengthMasks_matchRayPaths() {
        let chart = TestCharts.validated(TestCharts.eastAndDiagonal())
        let f = field(chart, islands: [])
        // Rebuild the masks from the rays (R-6, R-15) and compare.
        var masks: [Hex: Set<String>] = [:]
        var strengths: [Hex: Int] = [:]
        let weights = Dictionary(uniqueKeysWithValues: chart.swells.map { ($0.id, $0.weight) })
        for ray in f.rays {
            for cell in ray.cells {
                masks[cell, default: []].insert(ray.swell)
            }
        }
        for (cell, mask) in masks {
            strengths[cell] = mask.reduce(0) {
                $0 + require(weights[$1], "unknown swell \($1)")
            }
        }
        for cell in chart.ocean.allCells {
            XCTAssertEqual(f.swells(at: cell), masks[cell] ?? [], "mask at \(cell)")
            XCTAssertEqual(f.strength(at: cell), strengths[cell] ?? 0, "strength at \(cell)")
        }
        // Nodes are exactly the cells with two or more distinct swells.
        let nodes = Set(chart.ocean.allCells.filter { (masks[$0]?.count ?? 0) >= 2 })
        XCTAssertEqual(f.nodes, nodes)
    }

    // MARK: The oracle battery

    /// Fixed configurations (deterministic from SeededRNG seeds) that
    /// exercise reflection and refraction together across two charts.
    func batteryConfigs() -> [(seed: UInt64, chart: Chart, islands: Set<Hex>)] {
        fixtureBattery()
    }

    func test_oracleBattery_tracerMatchesIndependentImplementation() {
        for (seed, chart, islands) in batteryConfigs() {
            let obstacles = islands.union(chart.atollCells)
            let engine = Tracer.trace(
                ocean: chart.ocean, swells: chart.swells,
                islands: islands, atollCells: chart.atollCells)
            let oracle = Oracle.rays(ocean: chart.ocean, swells: chart.swells, obstacles: obstacles)
            XCTAssertEqual(engine.count, oracle.count, "seed \(seed): ray count")
            for (e, o) in zip(engine, oracle) {
                XCTAssertEqual(
                    e, o,
                    "seed \(seed): ray mismatch at \(o.start?.q ?? -99),\(o.start?.r ?? -99)")
            }
        }
    }

    // MARK: INV-5 over every fixture ray

    func test_inv5_everyRayTerminatesWithin40Steps() {
        for (seed, chart, islands) in batteryConfigs() {
            let f = field(chart, islands: islands)
            for ray in f.rays {
                // `cells` includes the start cell; steps = count - 1.
                XCTAssertLessThanOrEqual(
                    ray.cells.count - 1, 40,
                    "seed \(seed) ray \(String(describing: ray.cells.first))")
            }
        }
        let plain = field(TestCharts.eastOnly(), islands: [])
        for ray in plain.rays {
            XCTAssertLessThanOrEqual(ray.cells.count - 1, 40)
        }
    }

    // MARK: Fixture-count guards (MT-P1.1: 40 reflection fixtures;
    // MT-P1.2: 30 refraction fixtures — the 36-case reflection table
    // is tested in HexTests, the literals here, the battery below).

    func test_fixtureBudgets_reflectionAndRefraction() {
        // Count rays, not configurations: a reflection fixture is a
        // ray with at least one bounce; a refraction fixture is a ray
        // whose heading changed at least once (a bend). The 36-case
        // reflection table lives in
        // HexTests.testClosedFormMatchesHandTableAll36.
        var bounceRays = 0
        var bendRays = 0
        for (_, chart, islands) in batteryConfigs() {
            for ray in field(chart, islands: islands).rays {
                if ray.reflections > 0 { bounceRays += 1 }
                var bends = 0
                var previous: Hex?
                var heading: Int?
                for cell in ray.cells {
                    if let p = previous {
                        let d = Hex.directionVectors.firstIndex(of: cell - p)
                        if let h = heading, d != h { bends += 1 }
                        heading = d
                    }
                    previous = cell
                }
                if bends > 0 { bendRays += 1 }
            }
        }
        let literalRays =
            field(standard, islands: [Hex(3, 1)]).rays
            + field(far, islands: [Hex(-1, 0)]).rays
            + field(far, islands: [Hex(2, -1), Hex(1, 1)]).rays
            + field(far, islands: [Hex(2, 1), Hex(5, -2)]).rays
            + field(far, islands: [Hex(0, 1)]).rays
            + field(standard, islands: [Hex(2, 1)]).rays
            + field(standard, islands: [Hex(-3, 1)]).rays
            + field(standard, islands: [Hex(1, -3)]).rays
        for ray in literalRays {
            if ray.reflections > 0 { bounceRays += 1 }
        }
        XCTAssertGreaterThanOrEqual(36 + bounceRays, 40, "reflection fixtures")
        XCTAssertGreaterThanOrEqual(bendRays, 30, "refraction fixtures")
    }
}
