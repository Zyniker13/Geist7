import Foundation
import RSCore
import Testing

@testable import RSAI

private func note(_ s: String) {
    FileHandle.standardError.write(Data((s + "\n").utf8))
}

private func run(_ name: String, bot0: any MatchBot, bot1: any MatchBot, seeds: Int)
    throws -> Int
{
    var wins = 0
    for i in 0..<seeds {
        let record = try BotMatch.play(
            seed: UInt64(i * 100 + 4),
            ruleset: .finkel,
            dice: .tetra4,
            stake: 2,
            bot0: bot0,
            bot1: bot1,
            maxActions: 60_000
        )
        let end = record.finalState
        let p0 = end.borneOff[.player0] ?? 0
        let p1 = end.borneOff[.player1] ?? 0
        let winner: String =
            p0 == 7 ? "P0" : (p1 == 7 ? "P1" : (end.outcome?.winner == .player0 ? "P0*" : "P1*"))
        note(
            "LADDER \(name) seed=\(i * 100 + 4) winner=\(winner) p0=\(p0) p1=\(p1) plies=\(end.plies)"
        )
        if winner == "P0" { wins += 1 }
    }
    note("LADDER \(name) WINS=\(wins)/\(seeds)")
    return wins
}

@Test func scratchSeat() throws {
    // P3-vs-P3 same-strength pairs: any P0 dominance is a seat bias.
    _ = try run(
        "greedy3_as_p0_vs_careful3", bot0: RosetteBot(personality: .greedy, strength: 3),
        bot1: RosetteBot(personality: .careful, strength: 3), seeds: 30)
    _ = try run(
        "greedy3_as_p1_vs_careful3", bot0: RosetteBot(personality: .careful, strength: 3),
        bot1: RosetteBot(personality: .greedy, strength: 3), seeds: 30)
}
