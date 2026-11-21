// FieldInvariantTests.swift — R-3..R-6 field rules, INV-1 order
// independence, INV-6 symmetry, and the tracing-determinism sweep
// (A.7: 10,000 random fields).

import XCTest

@testable import MTCore

final class FieldInvariantTests: XCTestCase {
    func field(_ chart: Chart, islands: Set<Hex>) -> Field {
        Field.compute(
            ocean: chart.ocean, swells: chart.swells, islands: islands,
            atollCells: chart.atollCells)
    }

    // MARK: R-3 — one ray per unobstructed edge cell, straight travel

    func test_R3_oneRayPerUnobstructedEdgeCell() {
        for chart in [TestCharts.eastOnly(), TestCharts.eastAndDiagonal()] {
            let f = field(chart, islands: [])
            for swell in chart.swells {
                let expected = chart.ocean.edge(swell.entrySide)
                    .filter { !chart.atollCells.contains($0) }
                let rays = f.rays.filter { $0.swell == swell.id }
                XCTAssertEqual(rays.count, expected.count, "chart \(chart.id) swell \(swell.id)")
                // Every ray starts on its swell's entry edge (R-3).
                for ray in rays {
                    XCTAssertTrue(
                        expected.contains(ray.cells.first ?? Hex(99, 99)),
                        "ray starts off the entry edge: \(String(describing: ray.cells.first))")
                }
            }
        }
    }

    func test_R3_raysTravelStraightOnAnEmptyBoard() {
        let chart = TestCharts.eastOnly()
        let f = field(chart, islands: [])
        // Rows -4 and -5 stay clear of atoll adjacency, so their rays
        // run unobstructed from edge to edge (R-3, R-5).
        for entry in [Hex(5, -4), Hex(5, -5)] {
            guard let ray = f.rays.first(where: { $0.swell == "east_dom" && $0.start == entry })
            else {
                XCTFail("missing ray from \(entry)")
                continue
            }
            let v = Hex.directionVectors[3]  // the east swell travels W
            for (a, b) in zip(ray.cells, ray.cells.dropFirst()) {
                XCTAssertEqual(b - a, v, "ray from \(entry) left its row")
            }
            XCTAssertEqual(ray.reflections, 0)
            XCTAssertEqual(ray.termination, .leftOcean)
        }
        // Every ray, bent or not, moves between adjacent cells.
        for ray in f.rays {
            for (a, b) in zip(ray.cells, ray.cells.dropFirst()) {
                XCTAssertEqual(a.distance(to: b), 1)
            }
        }
    }

    // MARK: R-5 — termination caps

    func test_R5_terminationReasonsAreWithinCaps() {
        for (_, chart, islands) in TracerFixtureTests().batteryConfigs() {
            for ray in field(chart, islands: islands).rays {
                XCTAssertLessThanOrEqual(ray.reflections, Balance.maxReflections)
                XCTAssertLessThanOrEqual(ray.cells.count - 1, 40)
                switch ray.termination {
                case .leftOcean, .maxReflections, .maxSteps:
                    break
                }
            }
        }
    }

    // MARK: R-6 — swell sets, strengths, nodes (R-15 one count per swell)

    func test_R6_masksStrengthsNodes_matchRays() {
        let chart = TestCharts.eastAndDiagonal()
        for islandSet in [[Hex(2, 1)], [Hex(0, 0), Hex(3, -2)], []] {
            let f = field(chart, islands: Set(islandSet))
            var masks: [Hex: Set<String>] = [:]
            let weights = Dictionary(uniqueKeysWithValues: chart.swells.map { ($0.id, $0.weight) })
            for ray in f.rays {
                for cell in ray.cells {
                    masks[cell, default: []].insert(ray.swell)
                }
            }
            for cell in chart.ocean.allCells {
                let mask = masks[cell] ?? []
                XCTAssertEqual(f.swells(at: cell), mask, "mask at \(cell)")
                XCTAssertEqual(
                    f.strength(at: cell),
                    mask.reduce(0) {
                        $0 + require(weights[$1], "unknown swell \($1)")
                    },
                    "strength at \(cell)")
                XCTAssertEqual(f.isNode(cell), mask.count >= 2, "node at \(cell)")
            }
        }
    }

    // MARK: INV-1 — tracing is order-independent

    func test_INV1_fieldIndependentOfSwellOrder() {
        let chart = TestCharts.eastAndDiagonal()
        let islands: Set<Hex> = [Hex(1, 1), Hex(-2, 0), Hex(3, -2)]
        let forward = field(chart, islands: islands)
        let reversedChart = Chart(
            id: chart.id, radius: chart.radius,
            swells: chart.swells.reversed(), preIslands: chart.preIslands,
            atolls: chart.atolls, symmetry: chart.symmetry)
        let reversed = field(reversedChart, islands: islands)

        // Masks, strengths, and nodes are identical.
        for cell in chart.ocean.allCells {
            XCTAssertEqual(forward.swells(at: cell), reversed.swells(at: cell))
            XCTAssertEqual(forward.strength(at: cell), reversed.strength(at: cell))
        }
        XCTAssertEqual(forward.nodes, reversed.nodes)
        // The ray sets are equal as sets (list order follows the swell
        // order; the traced geometry does not).
        XCTAssertEqual(Set(forward.rays), Set(reversed.rays))
    }

    // MARK: INV-6 — the field respects the chart's declared symmetry

    func test_INV6_mirrorSymmetry() {
        let chart = TestCharts.mirrorPair()
        let f = field(chart, islands: [])
        for cell in chart.ocean.allCells {
            let image = chart.symmetryImage(of: cell)
            XCTAssertEqual(f.strength(at: cell), f.strength(at: image), "strength \(cell)")
            XCTAssertEqual(f.swells(at: cell), f.swells(at: image), "mask \(cell)")
            XCTAssertEqual(f.isNode(cell), f.isNode(image), "node \(cell)")
        }
    }

    func test_INV6_rotate180Symmetry() {
        let chart = TestCharts.rotatePair()
        let f = field(chart, islands: [])
        // Under rotate180 the swell pairs swap ids; compare strengths
        // and node structure, and the paired ray counts.
        for cell in chart.ocean.allCells {
            let image = chart.symmetryImage(of: cell)
            XCTAssertEqual(f.strength(at: cell), f.strength(at: image), "strength \(cell)")
            XCTAssertEqual(f.isNode(cell), f.isNode(image), "node \(cell)")
        }
        func raysOf(_ id: String) -> Set<RayPath> {
            Set(f.rays.filter { $0.swell == id })
        }
        let pairs = [("east_dom", "west_dom")]
        for (a, b) in pairs {
            XCTAssertEqual(raysOf(a).count, raysOf(b).count, "ray counts \(a)/\(b)")
        }
    }

    // MARK: A.7 — tracing determinism on 10,000 random fields

    func test_tracingDeterminism_10000RandomFields() {
        var rng = SeededRNG(seed: 0x4D41_5454_414E_47A5)
        let charts = [TestCharts.eastOnly(), TestCharts.eastAndDiagonal(), TestCharts.rotatePair()]
        var checked = 0
        for _ in 0..<10_000 {
            let chart = charts[rng.nextInt(below: charts.count)]
            let cells = chart.ocean.allCells.filter { !chart.atollCells.contains($0) }
            var islands: Set<Hex> = []
            let count = rng.nextInt(below: 7)
            for _ in 0..<count {
                islands.insert(cells[rng.nextInt(below: cells.count)])
            }

            let f = field(chart, islands: islands)
            // (a) INV-5: every ray terminates within 40 steps.
            for ray in f.rays {
                XCTAssertLessThanOrEqual(ray.cells.count - 1, 40)
                XCTAssertLessThanOrEqual(ray.reflections, Balance.maxReflections)
            }
            // (b) Determinism: a fresh computation is identical.
            let g = field(chart, islands: islands)
            XCTAssertEqual(f, g)
            // (c) Order independence, spot-checked every 10th field.
            if rng.nextInt(below: 10) == 0 {
                let reversedChart = Chart(
                    id: chart.id, radius: chart.radius,
                    swells: chart.swells.reversed(), preIslands: chart.preIslands,
                    atolls: chart.atolls, symmetry: chart.symmetry)
                let h = field(reversedChart, islands: islands)
                for cell in chart.ocean.allCells {
                    XCTAssertEqual(f.strength(at: cell), h.strength(at: cell))
                }
                XCTAssertEqual(Set(f.rays), Set(h.rays))
            }
            checked += 1
        }
        XCTAssertEqual(checked, 10_000)
    }
}
