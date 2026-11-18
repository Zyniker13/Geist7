import Foundation
import RSCore
import Testing

@testable import RSAI

private func note(_ s: String) {
    FileHandle.standardError.write(Data((s + "\n").utf8))
}

/// Per-seat event tallies for EMM mirrors: find where P1's edge comes from.
@Test func scratchEmmMirrorStats() throws {
    var totalTurns: [Int] = [0, 0]
    var totalMoves: [Int] = [0, 0]
    var totalCaptures: [Int] = [0, 0]
    var totalExtraRolls: [Int] = [0, 0]
    var totalBornOff: [Int] = [0, 0]
    var totalDoubles = 0
    var wins0 = 0
    var wins1 = 0
    let matches = 30
    for i in 0..<matches {
        let emm0 = OptimalBot(depth: 2)
        let emm1 = OptimalBot(depth: 2)
        var state = MatchState.newMatch(
            ruleset: .finkel, dice: .tetra4, stake: 2, omens: [], fortunes: [])
        var rng = SeededRNG(seed: UInt64(i * 37 + 7))
        var omenRng = SeededRNG(seed: UInt64(i * 37 + 7) &+ 0x9E37_79B9_7F4A_7C15)
        var actions = 0
        var turns: [Int] = [0, 0]
        var moves: [Int] = [0, 0]
        var captures: [Int] = [0, 0]
        var extraRolls: [Int] = [0, 0]
        var doubles = 0
        while !state.isComplete, actions < 60_000 {
            actions += 1
            let seat = state.currentPlayer == .player0 ? 0 : 1
            let action: Action
            if state.doubleOffered {
                let decider: PlayerID = state.currentPlayer == .player0 ? .player1 : .player0
                var pickRng = SeededRNG(
                    seed: UInt64(i * 37 + 7) &+ UInt64(state.plies) &+ 0x2545_F491_4F6C_DD1D)
                let deciderBot: OptimalBot = decider == .player0 ? emm0 : emm1
                action =
                    deciderBot.decideDouble(state: state, rng: &pickRng) ? .acceptDouble : .concede
            } else if !state.hasRolled {
                var pickRng = SeededRNG(
                    seed: UInt64(i * 37 + 7) &+ UInt64(state.plies) &+ 0x2545_F491_4F6C_DD1D)
                let bot: OptimalBot = seat == 0 ? emm0 : emm1
                action = bot.wantsDouble(state: state, rng: &pickRng) ? .offerDouble : .roll
            } else {
                let bot: OptimalBot = seat == 0 ? emm0 : emm1
                let legal = MoveGen.legalMoves(
                    for: state.currentPlayer, amount: state.diceValue ?? 0, pieces: state.pieces,
                    track: state.track, rules: state.ruleset)
                guard !legal.isEmpty else { break }
                var pickRng = SeededRNG(seed: UInt64(i * 37 + 7) &+ 0xABCD)
                guard let move = bot.chooseMove(from: state, moves: legal, rng: &pickRng) else {
                    break
                }
                action = .move(move.piece)
                moves[seat] += 1
            }
            let hadExtra = state.extraRoll
            if i == 0 {
                note(
                    "ACT p=\(state.plies) seat=\(seat) action=\(action) rolled=\(state.hasRolled) offered=\(state.doubleOffered) doubledTurn=\(state.hasDoubledThisTurn)"
                )
            }
            do {
                let result = try Reducer.apply(action, to: state, rng: &rng, omenRng: &omenRng)
                if action == .roll {
                    turns[seat] += 1
                    if hadExtra { extraRolls[seat] += 1 }
                }
                for event in result.events {
                    if case .pieceCaptured(let pieceId, _) = event {
                        let victim = result.state.pieces.first { $0.id == pieceId }
                        let victimSeat = victim?.owner == .player0 ? 1 : 0
                        captures[victimSeat] += 1
                    }
                    if case .cubeDoubled = event { doubles += 1 }
                }
                state = result.state
            } catch {
                note(
                    "EMMERR m\(i) action=\(action) seat=\(seat) plies=\(state.plies) doubledThisTurn=\(state.hasDoubledThisTurn) offered=\(state.doubleOffered) cube=\(state.cube.value) owner=\(String(describing: state.cube.owner)) hasRolled=\(state.hasRolled)"
                )
                throw error
            }
        }
        if state.isComplete {
            if state.outcome?.winner == .player0 {
                wins0 += 1
            } else {
                wins1 += 1
            }
            totalTurns[0] += turns[0]
            totalTurns[1] += turns[1]
            totalMoves[0] += moves[0]
            totalMoves[1] += moves[1]
            totalCaptures[0] += captures[0]
            totalCaptures[1] += captures[1]
            totalExtraRolls[0] += extraRolls[0]
            totalExtraRolls[1] += extraRolls[1]
            totalBornOff[0] += state.borneOff[.player0] ?? 0
            totalBornOff[1] += state.borneOff[.player1] ?? 0
            totalDoubles += doubles
            note(
                "EMMSTAT m\(i) w=\(state.outcome?.winner == .player0 ? "P0" : "P1") turns=\(turns[0])/\(turns[1]) moves=\(moves[0])/\(moves[1]) caps=\(captures[0])/\(captures[1]) extra=\(extraRolls[0])/\(extraRolls[1]) borne=\(state.borneOff[.player0] ?? -1)/\(state.borneOff[.player1] ?? -1) plies=\(state.plies)"
            )
        } else {
            note("EMMSTAT m\(i) TIMEOUT plies=\(state.plies)")
        }
    }
    note(
        "EMMTOTAL wins P0=\(wins0) P1=\(wins1) turns=\(totalTurns[0])/\(totalTurns[1]) moves=\(totalMoves[0])/\(totalMoves[1]) caps=\(totalCaptures[0])/\(totalCaptures[1]) extra=\(totalExtraRolls[0])/\(totalExtraRolls[1]) borne=\(totalBornOff[0])/\(totalBornOff[1]) doubles=\(totalDoubles)"
    )
}
