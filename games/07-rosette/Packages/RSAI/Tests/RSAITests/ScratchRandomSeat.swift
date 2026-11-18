import Foundation
import RSCore
import Testing

@testable import RSAI

private func note(_ s: String) {
    FileHandle.standardError.write(Data((s + "\n").utf8))
}

@Test func scratchRandomSeat() throws {
    var wins0 = 0
    var wins1 = 0
    let matches = 200
    for seed in 0..<matches {
        let record = try RandomMatch.play(seed: UInt64(seed), maxActions: 100_000)
        if record.finalState.outcome?.winner == .player0 { wins0 += 1 } else { wins1 += 1 }
    }
    note("RANDOMSEAT P0wins=\(wins0)/\(matches) P1wins=\(wins1)")
}
