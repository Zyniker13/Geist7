import Foundation
import RSCore
import Testing

@testable import RSAI

private func note(_ s: String) {
    FileHandle.standardError.write(Data((s + "\n").utf8))
}

@Test func scratchTurnCounts() throws {
    // One greedy3 mirror match: count rolls and moves per seat.
    let record = try BotMatch.play(
        seed: 105, ruleset: .finkel, dice: .tetra4, stake: 2,
        bot0: RosetteBot(personality: .greedy, strength: 3),
        bot1: RosetteBot(personality: .greedy, strength: 3),
        maxActions: 60_000
    )
    var moves: [PlayerID: Int] = [:]
    var rollCount = 0
    for action in record.actions {
        switch action {
        case .roll: rollCount += 1
        case .move(let pieceId): moves[(pieceId % 2 == 0) ? .player0 : .player1, default: 0] += 1
        default: break
        }
    }
    note(
        "TURNS rolls=\(rollCount) moves p0=\(moves[.player0, default: 0]) p1=\(moves[.player1, default: 0])"
    )
    note(
        "TURNS final p0=\(record.finalState.borneOff[.player0, default: 0]) p1=\(record.finalState.borneOff[.player1, default: 0]) plies=\(record.finalState.plies)"
    )
}
