import Foundation
import RSCore
import Testing

@testable import RSAI

private func note(_ s: String) {
    FileHandle.standardError.write(Data((s + "\n").utf8))
}

@Test func scratchTrace() throws {
    var state = MatchState.newMatch(
        ruleset: .finkel, dice: .tetra4, stake: 2, omens: [], fortunes: [])
    var rng = SeededRNG(seed: 105)
    var omenRng = SeededRNG(seed: 105 &+ 0x9E37_79B9_7F4A_7C15)
    let bot0 = RosetteBot(personality: .greedy, strength: 3)
    let bot1 = RosetteBot(personality: .greedy, strength: 3)
    var turnCounts: [PlayerID: Int] = [:]
    var passCounts: [PlayerID: Int] = [:]
    var moveCounts: [PlayerID: Int] = [:]
    var captureCounts: [PlayerID: Int] = [:]

    for _ in 0..<200_000 {
        if state.isComplete { break }
        let bot = state.currentPlayer == .player0 ? bot0 : bot1
        var action: Action
        if !state.hasRolled {
            turnCounts[state.currentPlayer, default: 0] += 1
            var pickRng = SeededRNG(
                seed: 105 &+ UInt64(state.plies) &+ 0x2545_F491_4F6C_DD1D)
            action = .roll
            let result = try Reducer.apply(action, to: state, rng: &rng, omenRng: &omenRng)
            let me = state.currentPlayer
            if result.state.currentPlayer != me,
                result.state.diceValue == nil || !result.state.hasRolled
            {
                // check pass: turn ended right after the roll
                if result.events.contains(where: { $0 == .turnPassed }) {
                    passCounts[me, default: 0] += 1
                    let inHand = result.state.pieces.filter { $0.owner == me && $0.position < 0 }
                        .count
                    note(
                        "TRACE pass \(me) rollValue=\(result.state == state ? -9 : result.events.count) inHand=\(inHand)"
                    )
                }
            }
            state = result.state
            continue
        }
        let moves = MoveGen.legalMoves(
            for: state.currentPlayer, amount: state.diceValue ?? 0, pieces: state.pieces,
            track: state.track, rules: state.ruleset)
        guard !moves.isEmpty else {
            note(
                "TRACE ILLEGAL no moves hasRolled=\(state.hasRolled) dice=\(state.diceValue ?? -9)")
            break
        }
        var pickRng = SeededRNG(seed: 105 &+ UInt64(state.plies) &+ 0x2545_F491_4F6C_DD1D)
        guard let move = bot.chooseMove(from: state, moves: moves, rng: &pickRng) else { break }
        let me = state.currentPlayer
        let before = state.pieces
        let dest = moves.first { $0.piece == move.piece }?.destination ?? -99
        let captured = before.contains {
            $0.owner != me && $0.position == dest && dest != 7
        }
        action = .move(move.piece)
        let result = try Reducer.apply(action, to: state, rng: &rng, omenRng: &omenRng)
        moveCounts[me, default: 0] += 1
        if captured { captureCounts[me, default: 0] += 1 }
        state = result.state
    }
    note(
        "TRACE turns p0=\(turnCounts[.player0, default: 0]) p1=\(turnCounts[.player1, default: 0]) passes p0=\(passCounts[.player0, default: 0]) p1=\(passCounts[.player1, default: 0]) moves p0=\(moveCounts[.player0, default: 0]) p1=\(moveCounts[.player1, default: 0]) captures p0=\(captureCounts[.player0, default: 0]) p1=\(captureCounts[.player1, default: 0])"
    )
    note(
        "TRACE final p0=\(state.borneOff[.player0, default: 0]) p1=\(state.borneOff[.player1, default: 0])"
    )
}
