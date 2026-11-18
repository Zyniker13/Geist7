import Foundation
import RSCore
import Testing

@testable import RSAI

private func note(_ s: String) {
    FileHandle.standardError.write(Data((s + "\n").utf8))
}

@Test func scratchTwoPieceValue() throws {
    // Mirror SolveTests' two-piece initial state; deep EMM value for P0
    // should approach the published 0.5186 if the engine is fair.
    var state = MatchState.newMatch(
        ruleset: .finkel, dice: .tetra4, stake: 2, omens: [], fortunes: [])
    state.pieces = [Piece.making(id: 0, owner: .player0), Piece.making(id: 0, owner: .player1)]
    state.movablePieceIds = []
    for depth in [2, 3, 4, 5] {
        let emm = Expectiminimax(depth: depth)
        let value = emm.value(of: state, for: .player0)
        note("TWOPIECE depth=\(depth) value=\(value)")
    }
}
