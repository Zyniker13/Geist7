import Foundation
import RSCore
import Testing

@testable import RSAI

private func note(_ s: String) {
    FileHandle.standardError.write(Data((s + "\n").utf8))
}

private func run(_ name: String, bot0: any MatchBot, bot1: any MatchBot, seeds: Int) throws {
    var wins0 = 0
    var wins1 = 0
    var concessions0 = 0
    var concessions1 = 0
    for i in 0..<seeds {
        let record = try BotMatch.play(
            seed: UInt64(i * 100 + 6), ruleset: .finkel, dice: .tetra4, stake: 2,
            bot0: bot0, bot1: bot1, maxActions: 60_000)
        let end = record.finalState
        let winner = end.outcome?.winner ?? ((end.borneOff[.player0] == 7) ? .player0 : .player1)
        if winner == .player0 {
            wins0 += 1
            if end.borneOff[.player0] != 7 { concessions0 += 1 }
        } else {
            wins1 += 1
            if end.borneOff[.player1] != 7 { concessions1 += 1 }
        }
    }
    note(
        "LADDER2 \(name) P0wins=\(wins0)/\(seeds) (of which conceded=\(concessions0)) P1wins=\(wins1) (conceded=\(concessions1))"
    )
}

@Test func scratchLadder3() throws {
    let emm = OptimalBot(depth: 2)
    try run(
        "emm_mirror", bot0: emm, bot1: OptimalBot(depth: 2), seeds: 30)
    try run(
        "greedy3_mirror", bot0: RosetteBot(personality: .greedy, strength: 3),
        bot1: RosetteBot(personality: .greedy, strength: 3), seeds: 30)
    try run(
        "emm_vs_gambler1", bot0: RosetteBot(personality: .gambler, strength: 1), bot1: emm,
        seeds: 30)
    try run(
        "emm_first_vs_gambler1", bot0: emm, bot1: RosetteBot(personality: .gambler, strength: 1),
        seeds: 30)
}
