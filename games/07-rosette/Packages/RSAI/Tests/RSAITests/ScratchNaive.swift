import Foundation
import RSCore
import Testing

@testable import RSAI

private func note(_ s: String) {
    FileHandle.standardError.write(Data((s + "\n").utf8))
}

@Test func scratchNaiveDiagnostics() throws {
    let naive = RosetteBot(personality: .gambler, strength: 1)
    let optimal = OptimalBot(depth: 2)
    var borneWins = 0
    var concessionLosses = 0
    var boreOffLosses = 0
    for i in 0..<30 {
        let record = try BotMatch.play(
            seed: UInt64(i * 100 + 2),
            ruleset: .finkel,
            dice: .tetra4,
            stake: 2,
            bot0: naive,
            bot1: optimal,
            maxActions: 60_000
        )
        let end = record.finalState
        let p0 = end.borneOff[.player0] ?? 0
        let p1 = end.borneOff[.player1] ?? 0
        let cube = end.cube.value
        let tag: String
        if p0 == 7 {
            borneWins += 1
            tag = "NAIVE-BORNE"
        } else if p1 == 7 {
            boreOffLosses += 1
            tag = "OPTIMAL-BORNE"
        } else {
            concessionLosses += 1
            tag = "CONCEDE"
        }
        note(
            "NAIVE seed=\(i * 100 + 2) \(tag) p0=\(p0) p1=\(p1) cube=\(cube) plies=\(end.plies) complete=\(end.isComplete)"
        )
    }
    note(
        "NAIVE TOTAL borneWins=\(borneWins) optimalBorne=\(boreOffLosses) concede=\(concessionLosses)"
    )
}
