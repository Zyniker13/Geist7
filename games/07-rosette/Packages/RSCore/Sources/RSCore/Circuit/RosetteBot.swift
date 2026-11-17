/// Generate a random float in [0, 1) from a SeededRNG.
func nextFloat(rng: inout SeededRNG) -> Float {
    Float(rng.next(UInt64(1000))) / 1000.0
}

// MARK: - RosetteBot

/// A simple AI opponent for circuit matches.
public struct RosetteBot: Sendable {
    /// The bot's difficulty (1–5).
    public let difficulty: Int
    /// The bot's strategy style.
    public let style: StrategyStyle

    /// Create a bot at a given difficulty and style.
    public init(difficulty: Int, style: StrategyStyle) {
        self.difficulty = max(1, min(5, difficulty))
        self.style = style
    }

    /// Choose a move from the legal moves for this bot.
    public func chooseMove(
        legalMoves: [Action],
        rng: inout SeededRNG
    ) -> Action {
        guard !legalMoves.isEmpty else {
            fatalError("Bot called with no legal moves")
        }

        // Difficulty affects randomness: higher difficulty = more deterministic
        let randomness = Float(6 - difficulty) / 5.0 // 1.0 (easy) to 0.2 (hard)

        // Style affects preference
        switch style {
        case .aggressive:
            return chooseAggressive(legalMoves, rng: &rng, randomness: randomness)
        case .positional:
            return choosePositional(legalMoves, rng: &rng, randomness: randomness)
        case .balanced:
            return chooseBalanced(legalMoves, rng: &rng, randomness: randomness)
        case .random:
            return legalMoves[rng.next(legalMoves.count)]
        }
    }

    private func chooseAggressive(
        _ moves: [Action],
        rng: inout SeededRNG,
        randomness: Float
    ) -> Action {
        // Prefer captures (simplified: all moves are potential captures for now)
        if !moves.isEmpty && nextFloat(rng: &rng) < 0.7 * randomness {
            return moves[rng.next(moves.count)]
        }
        return moves[rng.next(moves.count)]
    }

    private func choosePositional(
        _ moves: [Action],
        rng: inout SeededRNG,
        randomness: Float
    ) -> Action {
        // Prefer moves that advance pieces toward home
        // Simplified: pick from the middle of the list
        let mid = moves.count / 2
        let range = max(1, moves.count / 3)
        let start = max(0, mid - range / 2)
        let end = min(moves.count, start + range)
        let subset = Array(moves[start..<end])
        return subset[rng.next(subset.count)]
    }

    private func chooseBalanced(
        _ moves: [Action],
        rng: inout SeededRNG,
        randomness: Float
    ) -> Action {
        // Mix of aggressive and positional
        if nextFloat(rng: &rng) < 0.5 {
            return moves[rng.next(moves.count)]
        }
        return choosePositional(moves, rng: &rng, randomness: randomness)
    }
}
