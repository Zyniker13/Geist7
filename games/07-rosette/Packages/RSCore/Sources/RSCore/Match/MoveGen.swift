// MARK: - Move

/// A legal move for a piece.
public struct Move: Sendable, Equatable, Hashable {
    /// The piece being moved.
    public let piece: PieceID
    /// The destination path index, or -1 to bear off.
    public let destination: Int
}

// MARK: - MoveGenerating

/// A pluggable move generator. Each ruleset names its generator by id
/// (`RuleSet.moveGenerator`), which lets the data model carry variants
/// (RS-P1.3): "ur", "senet-like", "patolli-like".
public protocol MoveGenerating: Sendable {
    func legalMoves(
        for player: PlayerID,
        amount: Int,
        pieces: [Piece],
        track: Track,
        rules: RuleSet,
        unsafeRosettesActive: Bool,
        allowEntry: Bool
    ) -> [Move]
}

// MARK: - UrMoveGenerator

/// The Finkel/RoyalUr generator (R-3, R-4, R-5, R-7, R-18).
public struct UrMoveGenerator: MoveGenerating {
    public init() {}

    public func legalMoves(
        for player: PlayerID,
        amount: Int,
        pieces: [Piece],
        track: Track,
        rules: RuleSet,
        unsafeRosettesActive: Bool,
        allowEntry: Bool
    ) -> [Move] {
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
    func canBearOff(piece: Piece, amount: Int, track: Track, rules: RuleSet) -> Bool {
        if rules.exactBearOff {
            return piece.position + amount == track.length
        }
        return piece.position + amount >= track.length
    }
}

// MARK: - SenetLikeMoveGenerator

/// A Senet-like variant: no captures, and pieces may neither land on nor
/// jump over any occupied square (own or opponent).
public struct SenetLikeMoveGenerator: MoveGenerating {
    public init() {}

    public func legalMoves(
        for player: PlayerID,
        amount: Int,
        pieces: [Piece],
        track: Track,
        rules: RuleSet,
        unsafeRosettesActive: Bool,
        allowEntry: Bool
    ) -> [Move] {
        var moves: [Move] = []
        let owned = pieces.filter { $0.owner == player && !$0.isBorneOff }
        let occupied = Set(pieces.filter { $0.position >= 0 }.map { $0.position })

        for piece in owned {
            if piece.position == -1 {
                guard allowEntry else { continue }
                if !occupied.contains(0) {
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
            // The whole path from the next square to the destination must be
            // clear: no landing on occupied squares and no jumping over them.
            let pathClear = ((piece.position + 1)...destination).allSatisfy { !occupied.contains($0) }
            if pathClear {
                moves.append(Move(piece: piece.id, destination: destination))
            }
        }

        return moves
    }

    private func canBearOff(piece: Piece, amount: Int, track: Track, rules: RuleSet) -> Bool {
        if rules.exactBearOff {
            return piece.position + amount == track.length
        }
        return piece.position + amount >= track.length
    }
}

// MARK: - PatolliLikeMoveGenerator

/// A Patolli-like variant: own pieces may stack on one square and never
/// block each other; landing on an opponent captures them (bump home).
public struct PatolliLikeMoveGenerator: MoveGenerating {
    public init() {}

    public func legalMoves(
        for player: PlayerID,
        amount: Int,
        pieces: [Piece],
        track: Track,
        rules: RuleSet,
        unsafeRosettesActive: Bool,
        allowEntry: Bool
    ) -> [Move] {
        var moves: [Move] = []
        let owned = pieces.filter { $0.owner == player && !$0.isBorneOff }

        for piece in owned {
            if piece.position == -1 {
                // Stacking: an own piece on the entry square does not block.
                guard allowEntry else { continue }
                moves.append(Move(piece: piece.id, destination: 0))
                continue
            }

            if canBearOff(piece: piece, amount: amount, track: track, rules: rules) {
                moves.append(Move(piece: piece.id, destination: -1))
                continue
            }

            let destination = piece.position + amount
            guard destination < track.length else { continue }
            // Landing on a safe rosette held by the opponent is illegal
            // unless the safety omen is active this turn.
            let opponentThere = pieces.contains { $0.owner != player && $0.position == destination }
            if opponentThere && !unsafeRosettesActive && track.safeRosetteIndices.contains(destination) {
                continue
            }
            moves.append(Move(piece: piece.id, destination: destination))
        }

        return moves
    }

    private func canBearOff(piece: Piece, amount: Int, track: Track, rules: RuleSet) -> Bool {
        if rules.exactBearOff {
            return piece.position + amount == track.length
        }
        return piece.position + amount >= track.length
    }
}

// MARK: - MoveGen

/// Generates legal moves for a state, dispatching on the ruleset's generator.
public enum MoveGen {
    /// The generator implementation for a ruleset id.
    public static func generator(for id: String) -> MoveGenerating {
        switch id {
        case "senet-like": SenetLikeMoveGenerator()
        case "patolli-like": PatolliLikeMoveGenerator()
        default: UrMoveGenerator()
        }
    }

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
        return generator(for: rules.moveGenerator).legalMoves(
            for: player,
            amount: amount,
            pieces: pieces,
            track: track,
            rules: rules,
            unsafeRosettesActive: unsafeRosettesActive,
            allowEntry: allowEntry
        )
    }
}
