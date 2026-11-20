import Foundation
import RSCore
import Testing

@testable import RSAI

private func note(_ s: String) {
    FileHandle.standardError.write(Data((s + "\n").utf8))
}

/// Records the wall-clock cost of every AI decision (move or cube call).
private struct TimingBot: MatchBot, @unchecked Sendable {
    let inner: any MatchBot
    let record: (Double) -> Void

    func chooseMove(from state: MatchState, moves: [Move], rng: inout SeededRNG) -> Move? {
        let start = ContinuousClock.now
        let move = inner.chooseMove(from: state, moves: moves, rng: &rng)
        record(start.duration(to: .now).seconds)
        return move
    }

    func decideDouble(state: MatchState, rng: inout SeededRNG) -> Bool {
        let start = ContinuousClock.now
        let decision = inner.decideDouble(state: state, rng: &rng)
        record(start.duration(to: .now).seconds)
        return decision
    }

    func wantsDouble(state: MatchState, rng: inout SeededRNG) -> Bool {
        inner.wantsDouble(state: state, rng: &rng)
    }
}

private extension Duration {
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}

@Test func scratchThinkTime() throws {
    // P8 G8: daily AI (OptimalBot, bundled solved table) think-time
    // distribution across ten full Finkel matches. Budget: p95 < 1.5 s.
    var samples: [Double] = []
    for seed in 100_000..<100_010 {
        let bot = TimingBot(inner: OptimalBot()) { samples.append($0) }
        _ = try BotMatch.play(
            seed: UInt64(seed), ruleset: .finkel, dice: .tetra4, stake: 2,
            bot0: bot, bot1: bot, maxActions: 60_000
        )
    }
    samples.sort()
    guard !samples.isEmpty else {
        Issue.record("no AI decisions sampled")
        return
    }
    let p50 = samples[samples.count / 2]
    let p95 = samples[Int(Double(samples.count - 1) * 0.95)]
    let worst = samples.last ?? 0
    note(
        "THINK n=\(samples.count) p50=\(String(format: "%.3f", p50))s "
        + "p95=\(String(format: "%.3f", p95))s max=\(String(format: "%.3f", worst))s"
    )
}
