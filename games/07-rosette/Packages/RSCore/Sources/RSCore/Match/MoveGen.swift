// MARK: - Move

/// A legal move for a piece.
public struct Move: Sendable, Equatable, Hashable {
    /// The piece being moved.
    public let piece: PieceID
    /// The destination path index, or -1 to bear off.
    public let destination: Int
}

// MARK: - MoveGen

/// Generates legal moves for a given state (R-3, R-4, R-5, R-7, R-18).
public enum MoveGen {
    /// All legal moves for the player given the amount they must move.
    ///
    /// Positions are path indices in the owner's own path space: both players
    /// share the same index layout (4 private start squares, 8 shared squares,
    /// 2 private exit squares), so an opponent can only ever be met on the
    /// shared run (indices 4-11).
    public static func legalMoves(
        for player: PlayerID,
        amount: Int,
        pieces: [Piece],
        track: Track,
        rules: RuleSet,
        unsafeRosettesActive: Bool = false,
        allowEntry: Bool = true
    ) -> [Move] {
        guard amount > 0 else { return [] }

        var moves: [Move] = []
        let owned = pieces.filter { $0.owner == player && !$0.isBorneOff }

        for piece in owned {
            if piece.position == -1 {
                // Entry: any non-zero roll brings a piece in onto the first
                // square of its path; the roll is consumed by entering.
                // Split turns exclude entry moves: entering spends the roll.
                guard allowEntry else { continue }
                let entryBlocked = pieces.contains { $0.owner == player && $0.position == 0 }
                if !entryBlocked {
                    moves.append(Move(piece: piece.id, destination: 0))
                }
                continue
            }

            if canBearOff(piece: piece, amount: amount, track: track, rules: rules) {
                moves.append(Move(piece: piece.id, destination: -1))
                continue
            }

            let destination = piece.position + amount
            guard destination < track.length else { continue }
            // R-4: a piece cannot land on a square held by its own piece.
            if pieces.contains(where: { $0.owner == player && $0.position == destination }) {
                continue
            }
            // R-5: landing on a safe rosette held by the opponent is illegal,
            // unless the safety omen is active this turn.
            let opponentThere = pieces.contains { $0.owner != player && $0.position == destination }
            if opponentThere && !unsafeRosettesActive && track.safeRosetteIndices.contains(destination) {
                continue
            }
            moves.append(Move(piece: piece.id, destination: destination))
        }

        return moves
    }

    /// R-7: bearing off needs the exact count to step past the last square
    /// (or any count reaching past it when the ruleset allows inexact bear-off).
    static func canBearOff(piece: Piece, amount: Int, track: Track, rules: RuleSet) -> Bool {
        if rules.exactBearOff {
            return piece.position + amount == track.length
        }
        return piece.position + amount >= track.length
    }
}
