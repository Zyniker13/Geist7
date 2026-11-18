import Foundation
import RSCore
import Testing

@testable import RSAI

private func note(_ s: String) {
    FileHandle.standardError.write(Data((s + "\n").utf8))
}

@Test func scratchTactics() throws {
    let emm = Expectiminimax(depth: 2)

    func rolledState(amount: Int) -> MatchState {
        var state = MatchState(
            ruleset: .finkel,
            track: RuleSet.finkel.makeTrack(),
            dice: .tetra4,
            pieces: (0..<7).flatMap { id in
                PlayerID.allCases.map { Piece.making(id: id, owner: $0) }
            },
            currentPlayer: .player0,
            diceValue: nil,
            movablePieceIds: [],
            extraRoll: false,
            stake: Stake(value: 2),
            cube: .centered,
            cubeDead: false,
            doubleOffered: false,
            hasDoubledThisTurn: false,
            omensHeld: [:],
            omensPlayed: [:],
            pendingOmen: nil,
            splitRemaining: nil,
            splitActive: false,
            hasRolled: false,
            borneOff: [.player0: 0, .player1: 0],
            plies: 0,
            isComplete: false,
            outcome: nil
        )
        state.hasRolled = true
        state.diceValue = amount
        return state
    }

    // Position A: rolled 2. P0 piece on 5 can move to 7 where a P1 piece sits
    // (capture), or P0 can enter a waiting piece to 1. Capture must win.
    var captureState = rolledState(amount: 2)
    var pieces = captureState.pieces
    pieces[0].position = 5  // P0 piece: 5 + 2 = 7 captures
    pieces[2].position = -1  // P0 piece: could enter at 1 instead
    pieces[1].position = 7  // P1 piece standing on 7
    captureState.pieces = pieces
    captureState.movablePieceIds = Set(
        MoveGen.legalMoves(
            for: .player0, amount: 2, pieces: captureState.pieces,
            track: captureState.track, rules: captureState.ruleset
        ).map(\.piece))
    if let (move, value) = emm.bestMove(from: captureState, for: .player0) {
        note("TACTIC capture: chose piece=\(move.piece) dest=\(move.destination) value=\(value)")
    } else {
        note("TACTIC capture: NO MOVES")
    }

    // Position B: rolled 3. P0 piece on 8 is exposed (P1 on 6, hits with 2).
    // Safe alternative: move a DIFFERENT piece. bestMove should not ignore
    // the exposure swing entirely.
    var blotState = rolledState(amount: 3)
    var bp = blotState.pieces
    bp[0].position = 8  // P0 piece exposed (enemy 2 behind, p=6/16)
    bp[2].position = 1  // P0's other piece safe on private start
    bp[1].position = 6  // P1 piece 2 behind P0's blot
    blotState.pieces = bp
    blotState.movablePieceIds = Set(
        MoveGen.legalMoves(
            for: .player0, amount: 3, pieces: blotState.pieces,
            track: blotState.track, rules: blotState.ruleset
        ).map(\.piece))
    for move in MoveGen.legalMoves(
        for: .player0, amount: 3, pieces: blotState.pieces,
        track: blotState.track, rules: blotState.ruleset)
    {
        let (after, _) = try Reducer.applyMove(to: blotState, piece: move.piece)
        let afterOpp = Evaluator.rawScore(of: after, for: .player0)
        note(
            "TACTIC blot cand piece=\(move.piece) dest=\(move.destination) rawAfter=\(afterOpp)"
        )
    }
    if let (move, value) = emm.bestMove(from: blotState, for: .player0) {
        note("TACTIC blot: chose piece=\(move.piece) dest=\(move.destination) value=\(value)")
    }
}
