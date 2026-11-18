import Foundation
import RSCore
import Testing

@testable import RSAI

private func note(_ s: String) {
    FileHandle.standardError.write(Data((s + "\n").utf8))
}

@Test func scratchTableProbe() throws {
    let store = SolvedTableStore()
    precondition(store.isAvailable)
    var state = MatchState.newMatch(
        ruleset: .finkel, dice: .tetra4, stake: 2, omens: [], fortunes: [])
    state.pieces = [
        Piece.making(id: 0, owner: .player0), Piece.making(id: 0, owner: .player1),
    ]
    var rng = SeededRNG(seed: 7)
    var omenRng = SeededRNG(seed: 99)
    let result = try Reducer.apply(.roll, to: state, rng: &rng, omenRng: &omenRng)
    state = result.state
    note(
        "PROBE after roll dice=\(state.diceValue ?? -9) player=\(state.currentPlayer) hasRolled=\(state.hasRolled)"
    )
    let moves = MoveGen.legalMoves(
        for: state.currentPlayer, amount: state.diceValue ?? 0, pieces: state.pieces,
        track: state.track, rules: state.ruleset)
    note("PROBE moves=\(moves.count)")
    for move in moves {
        var copy = state
        var o2 = SeededRNG(seed: 0)
        let r = try Reducer.apply(.move(move.piece), to: copy, rng: &rng, omenRng: &o2)
        let after = r.state
        let position = TableBridge.position(from: after)
        let prob = position.flatMap { store.winProbability(forRoller: $0) }
        note(
            "PROBE piece=\(move.piece) pos=\(position.map { "\($0)" } ?? "nil") prob=\(prob.map { "\($0)" } ?? "nil")"
        )
    }
    note(
        "PROBE initialStateCovered=\(TableBridge.position(from: state).map { store.winProbability(forRoller: $0).map { "\($0)" } ?? "nil" } ?? "posnil")"
    )
}
