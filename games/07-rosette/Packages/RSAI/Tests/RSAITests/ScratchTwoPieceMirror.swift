import Foundation
import RSCore
import Testing

@testable import RSAI

private func note(_ s: String) {
    FileHandle.standardError.write(Data((s + "\n").utf8))
}

/// Pure table-driven bot: maximizes exact solved win probability.
struct ScratchTableBot: MatchBot {
    let store: SolvedTableStore

    func chooseMove(
        from state: MatchState, moves: [Move], rng: inout SeededRNG
    ) -> Move? {
        let me = state.currentPlayer
        var best: Move?
        var bestValue = -Double.infinity
        for move in moves {
            var copy = state
            var omenRng = SeededRNG(seed: 0)
            let result = try? Reducer.apply(
                .move(move.piece), to: copy, rng: &rng, omenRng: &omenRng)
            guard let after = result?.state else { continue }
            guard let position = TableBridge.position(from: after) else { continue }
            guard let p = store.winProbability(forRoller: position) else { continue }
            let value = me == .player0 ? p : 1 - p
            if value > bestValue {
                bestValue = value
                best = move
            }
        }
        return best
    }

    func wantsDouble(state: MatchState, rng: inout SeededRNG) -> Bool {
        guard let position = TableBridge.position(from: state) else { return false }
        guard let p = store.winProbability(forRoller: position) else { return false }
        return state.currentPlayer == .player0 ? p > 0.7 : 1 - p > 0.7
    }

    func decideDouble(state: MatchState, rng: inout SeededRNG) -> Bool {
        guard let position = TableBridge.position(from: state) else { return true }
        guard let p = store.winProbability(forRoller: position) else { return true }
        return state.currentPlayer == .player0 ? p > 0.3 : 1 - p > 0.3
    }
}

@Test func scratchTwoPieceMirror() throws {
    let bot0 = ScratchTableBot(store: SolvedTableStore())
    let bot1 = ScratchTableBot(store: SolvedTableStore())
    precondition(bot0.store.isAvailable)
    var wins0 = 0
    var wins1 = 0
    let matches = 200
    for i in 0..<matches {
        var state = MatchState.newMatch(
            ruleset: .finkel, dice: .tetra4, stake: 2, omens: [], fortunes: [])
        state.pieces = [
            Piece.making(id: 0, owner: .player0), Piece.making(id: 0, owner: .player1),
        ]
        var rng = SeededRNG(seed: UInt64(i * 37 + 7))
        var omenRng = SeededRNG(seed: UInt64(i * 37 + 7) &+ 0x9E37_79B9_7F4A_7C15)
        var actions = 0
        while !state.isComplete, actions < 20_000 {
            actions += 1
            let bot = state.currentPlayer == .player0 ? bot0 : bot1
            let action: Action
            if state.doubleOffered {
                let decider: PlayerID = state.currentPlayer == .player0 ? .player1 : .player0
                let deciderBot = decider == .player0 ? bot0 : bot1
                var pickRng = SeededRNG(
                    seed: UInt64(i * 37 + 7) &+ UInt64(state.plies) &+ 0x2545_F491_4F6C_DD1D)
                action =
                    deciderBot.decideDouble(state: state, rng: &pickRng) ? .acceptDouble : .concede
            } else if !state.hasRolled {
                var pickRng = SeededRNG(
                    seed: UInt64(i * 37 + 7) &+ UInt64(state.plies) &+ 0x2545_F491_4F6C_DD1D)
                action =
                    (bot.wantsDouble(state: state, rng: &pickRng)) ? .offerDouble : .roll
            } else {
                let moves = MoveGen.legalMoves(
                    for: state.currentPlayer, amount: state.diceValue ?? 0, pieces: state.pieces,
                    track: state.track, rules: state.ruleset)
                guard !moves.isEmpty else { break }
                var pickRng = SeededRNG(
                    seed: UInt64(i * 37 + 7) &+ UInt64(state.plies) &+ 0x2545_F491_4F6C_DD1D)
                guard let move = bot.chooseMove(from: state, moves: moves, rng: &pickRng) else {
                    break
                }
                action = .move(move.piece)
            }
            let result = try Reducer.apply(action, to: state, rng: &rng, omenRng: &omenRng)
            state = result.state
        }
        if state.isComplete {
            if state.outcome?.winner == .player0 { wins0 += 1 } else { wins1 += 1 }
        } else {
            note("MIRROR2 timeout at seed \(i)")
        }
    }
    note("MIRROR2 P0wins=\(wins0)/\(matches) P1wins=\(wins1)")
}
