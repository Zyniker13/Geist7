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
            seed: UInt64(i * 100 + 3),
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
            "LADDER \(name) seed=\(i * 100 + 3) winner=\(winner) p0=\(p0) p1=\(p1) plies=\(end.plies)"
        )
        if winner == "P0" { wins += 1 }
    }
    note("LADDER \(name) WINS=\(wins)/\(seeds)")
    return wins
}

@Test func scratchLadder2() throws {
    // EMM (as P0, moving first) vs each P3 personality.
    let emm = OptimalBot(depth: 2)
    _ = try run(
        "emm_first_vs_greedy3", bot0: emm, bot1: RosetteBot(personality: .greedy, strength: 3),
        seeds: 30)
    _ = try run(
        "emm_first_vs_gambler1", bot0: emm, bot1: RosetteBot(personality: .gambler, strength: 1),
        seeds: 30)
}
