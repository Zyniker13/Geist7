import Foundation
import RSContent
import RSCore
import Testing

@testable import RSAI

/// Scratch: circuit completion sweeps to calibrate the G4 bands
/// (roadmap: purse tunable 20–80; ADR-0011 region strength map).
/// Manual-only tool (disabled in suites: minutes of runtime); the recorded
/// calibration values live in ADR-0011 and docs/BALANCE.md. Re-enable to
/// re-run a sweep.
private func scratchErr(_ s: String) {
    FileHandle.standardError.write(Data((s + "\n").utf8))
}

struct ScratchCircuitRun {
    @Test(.disabled("manual calibration sweep; see ADR-0011"))
    func scratchCalibrationSweep() async throws {
        let store = SolvedTableStore()
        let configs: [(label: String, purse: Int, s: Int, e: Int, m: Int, n: Int)] = [
            ("C_48", 80, 3, 4, 4, 48),
            ("E_sum4_48", 80, 4, 4, 4, 48),
        ]
        for config in configs {
            let completed = try await Self.concurrentRuns(
                count: config.n, baseSeed: 500_001, purse: config.purse, sumer: config.s,
                egypt: config.e, mexica: config.m
            ) {
                OptimalBot(table: store, depth: 2)
            }
            scratchErr(
                "SWEEP \(config.label) completed=\(completed)/\(config.n) rate=\(Double(completed) / Double(config.n))"
            )
        }
        #expect(true)
    }

    @Test(.disabled("manual calibration sweep; see ADR-0011"))
    func scratchNaiveBand() async throws {
        for strength in [1, 2, 3] {
            for purse in [40, 80] {
                let completed = try await Self.concurrentRuns(
                    count: 24, baseSeed: 700_001, purse: purse, sumer: 3, egypt: 4, mexica: 4
                ) {
                    RosetteBot(personality: .careful, strength: strength)
                }
                scratchErr(
                    "NAIVE s=\(strength) p=\(purse) completed=\(completed)/24 rate=\(Double(completed) / 24.0)"
                )
            }
        }
        #expect(true)
    }

    /// Completion count over `count` concurrent circuit runs.
    private static func concurrentRuns(
        count: Int, baseSeed: UInt64, purse: Int, sumer: Int, egypt: Int, mexica: Int,
        makePlayer: @escaping @Sendable () -> any MatchBot & Sendable
    ) async throws -> Int {
        try await withThrowingTaskGroup(of: Bool.self) { group in
            for index in 0..<count {
                let seed = baseSeed &+ UInt64(index &* 9_977)
                group.addTask {
                    let run = try await BotMatchAITests.runCircuitSweepForScratch(
                        seed: seed, purse: purse, sumer: sumer, egypt: egypt, mexica: mexica,
                        makePlayer: makePlayer
                    )
                    return run.completed
                }
            }
            var completed = 0
            for try await done in group where done { completed += 1 }
            return completed
        }
    }
}

extension BotMatchAITests {
    /// Scratch sweep entry: explicit purse and region strengths.
    static func runCircuitSweepForScratch(
        seed: UInt64, purse: Int, sumer: Int, egypt: Int, mexica: Int,
        makePlayer: @escaping @Sendable () -> any MatchBot & Sendable
    ) async throws -> CircuitRunResult {
        try await runCircuit(
            seed: seed, makePlayer: makePlayer, purse: purse,
            strengthFor: { region in
                switch region {
                case "sumer": return sumer
                case "egypt": return egypt
                case "mexica": return mexica
                default: return 3
                }
            }
        )
    }
}
