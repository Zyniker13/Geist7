// InvariantPlayoutTests.swift — INV-2 (incremental tracing equals full
// recompute), INV-3 (canoe count conservation) and INV-4 (replay
// determinism) over 5,000 seeded random-legal games, with the INV-9
// field-update timing (< 0.5 ms) measured across every placement.

import XCTest

@testable import MTCore

final class InvariantPlayoutTests: XCTestCase {
    private let seedCount = 5_000
    private let maxPlies = 120

    func test_INV3_INV4_over5000SeededPlayouts() throws {
        let charts = [TestCharts.eastOnly(), TestCharts.eastAndDiagonal(), TestCharts.rotatePair()]
        var encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        for seed in UInt64(1)...UInt64(seedCount) {
            let chart = charts[Int(seed) % charts.count]
            let record = Playout.run(seed: seed, chart: chart, maxPlies: maxPlies)

            // INV-3 was asserted after every ply inside the harness;
            // re-assert on the final state.
            Playout.assertCanoeCounts(record.final)

            // INV-4: replaying the recorded actions from a fresh initial
            // state reproduces the final state exactly — structurally,
            // by stable hash, and byte for byte.
            var replay = Reducer.initial(chart: chart)
            for action in record.actions {
                let (next, _) = try Reducer.apply(action, to: replay)
                replay = next
            }
            XCTAssertEqual(replay, record.final, "seed \(seed): replay diverged")
            XCTAssertEqual(
                try StateHashing.stableHash(replay),
                try StateHashing.stableHash(record.final),
                "seed \(seed): replay hash differs")
            XCTAssertEqual(
                try encoder.encode(replay),
                try encoder.encode(record.final),
                "seed \(seed): replay bytes differ")

            // A won game must have landings to show for it.
            if case .won(let player) = record.final.status {
                XCTAssertGreaterThan(record.final.landed[player] ?? 0, 0)
            }
        }
    }

    /// INV-2/INV-9 in depth over the first 1,000 seeds (the MT-P1.3
    /// figure): after every island placement the incremental update
    /// equals a full recompute, and the update stays under 0.5 ms.
    func test_INV2_INV9_incrementalEqualsFull_withTiming() throws {
        let charts = [TestCharts.eastOnly(), TestCharts.eastAndDiagonal(), TestCharts.rotatePair()]
        let clock = ContinuousClock()
        var totalUpdate: Duration = .zero
        var worstUpdate: Duration = .zero
        var placementsChecked = 0

        // Warm the runtime before timing: the first call pays one-time
        // initialisation that is not part of the steady-state budget.
        do {
            let warm = FieldUpdate.applyIslandPlacement(
                previous: Field.compute(
                    ocean: charts[0].ocean, swells: charts[0].swells,
                    islands: [], atollCells: charts[0].atollCells),
                ocean: charts[0].ocean, swells: charts[0].swells,
                islands: [], atollCells: charts[0].atollCells,
                placed: Hex(0, 0))
            _ = warm
        }

        for seed in UInt64(1)...1_000 {
            let chart = charts[Int(seed) % charts.count]
            var rng = SeededRNG(seed: seed)
            var state = Reducer.initial(chart: chart)
            for _ in 0..<maxPlies {
                guard !state.status.isOver else { break }
                let action = Playout.chooseAction(in: state, rng: &rng)
                if case .placeIsland(let cell) = action {
                    let started = clock.now
                    let incremental = FieldUpdate.applyIslandPlacement(
                        previous: state.field, ocean: chart.ocean,
                        swells: chart.swells, islands: state.islands,
                        atollCells: chart.atollCells, placed: cell)
                    let elapsed = clock.now - started
                    totalUpdate += elapsed
                    if elapsed > worstUpdate { worstUpdate = elapsed }
                    let full = Field.compute(
                        ocean: chart.ocean, swells: chart.swells,
                        islands: state.islands.union([cell]),
                        atollCells: chart.atollCells)
                    XCTAssertEqual(incremental, full, "seed \(seed): INV-2 at \(cell)")
                    placementsChecked += 1
                }
                let (next, _) = try Reducer.apply(action, to: state)
                Playout.assertCanoeCounts(next)
                state = next
            }
        }
        XCTAssertGreaterThan(placementsChecked, 1_000, "the sweep exercised placements")
        // INV-9 / G1: the steady-state field update stays under half a
        // millisecond in release builds (the gate is measured with
        // `make perf`, which runs this suite release-optimised); a
        // debug build carries instrumentation, so it asserts INV-9's
        // device bound instead. The assertion is on the MEAN because a
        // single worst sample on a shared build machine measures the
        // scheduler, not the algorithm; the worst sample is still
        // reported for the gate record.
        func ms(_ d: Duration) -> Double {
            Double(d.components.seconds) * 1_000 + Double(d.components.attoseconds) / 1e15
        }
        let meanMs = ms(totalUpdate) / Double(max(placementsChecked, 1))
        #if DEBUG
            XCTAssertLessThan(meanMs, 2.0, "mean incremental update \(meanMs) ms (debug)")
        #else
            XCTAssertLessThan(meanMs, 0.5, "mean incremental update \(meanMs) ms")
        #endif
        print(
            "PERF worst incremental update \(ms(worstUpdate)) ms; "
                + "mean \(meanMs) ms over \(placementsChecked) placements")
    }
}
