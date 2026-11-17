// MARK: - RosetteBot

/// The P3 circuit bot: a deterministic, legal-by-construction move chooser
/// driven by an opponent personality (roadmap §7) and a strength tier.
/// All scoring uses Int math (_CONVENTIONS §4.2: no Float/Double in Core).
/// P4's RSAI replaces this for the real difficulty tiers.
public struct RosetteBot: Sendable {
    /// The opponent personality.
    public let personality: Personality
    /// Strength tier 1–5 (higher plays with less noise and more foresight).
    public let strength: Int

    public init(personality: Personality, strength: Int) {
        self.personality = personality
        self.strength = max(1, min(5, strength))
    }

    /// Choose a move from the legal moves, or nil when there are none.
    /// Deterministic given the same inputs and RNG state.
    public func chooseMove(
        from legalMoves: [Move],
        pieces: [Piece],
        track: Track,
        rng: inout SeededRNG
    ) -> Move? {
        guard !legalMoves.isEmpty else { return nil }
        if legalMoves.count == 1 { return legalMoves[0] }

        var best = legalMoves[0]
        var bestScore = Int.min
        for move in legalMoves {
            let owner = pieces.first { $0.id == move.piece }?.owner ?? .player0
            let score =
                self.score(move, owner: owner, pieces: pieces, track: track)
                + noise(rng: &rng)
            if score > bestScore {
                bestScore = score
                best = move
            }
        }
        return best
    }

    /// Personality-weighted score for one move (Int only).
    private func score(
        _ move: Move,
        owner: PlayerID,
        pieces: [Piece],
        track: Track
    ) -> Int {
        var value = move.destination  // mild forward bias

        if move.destination == -1 {
            // Bearing off wins pieces; greedies chase it harder.
            value += personality == .greedy ? 900 : 700
        } else {
            // Capture: an opponent piece sits on the destination and the
            // square is not a safe rosette.
            let captured = pieces.contains {
                $0.owner != owner && $0.position == move.destination
            }
            let safe = track.safeRosetteIndices.contains(move.destination)
            if captured && !safe {
                value += personality == .greedy ? 1_200 : 900
            }
            // Rosettes grant an extra roll (R-6); safe rosettes also protect.
            if track.rosetteIndices.contains(move.destination) {
                value += 150
                if safe { value += 120 }
            }
            // Exposure: an enemy within 1–4 squares behind the destination
            // can hit it next roll (weighted by how central that roll is).
            value -= exposure(at: move.destination, owner: owner, pieces: pieces)
        }

        switch personality {
        case .careful:
            value += safeBonus(move, track: track)
        case .greedy:
            break  // capture/bear-off bonuses above carry the style
        case .bluffer:
            value += move.destination / 2  // pushes race tempo
        case .gambler:
            value -= safeBonus(move, track: track) / 2  // shrugs at safety
        }
        return value
    }

    /// Bonus for landing where the piece cannot be sent home.
    private func safeBonus(_ move: Move, track: Track) -> Int {
        if move.destination < 0 { return 0 }
        if track.safeRosetteIndices.contains(move.destination) { return 200 }
        if track.rosetteIndices.contains(move.destination) { return 60 }
        return 0
    }

    /// Exposure penalty: enemy pieces 1–4 squares behind `square` can capture
    /// with a matching roll; closer and more-central rolls weigh more.
    private func exposure(at square: Int, owner: PlayerID, pieces: [Piece]) -> Int {
        guard square >= 0 else { return 0 }
        var penalty = 0
        for piece in pieces
        where piece.owner != owner && piece.position >= 0 && piece.position < square {
            let distance = square - piece.position
            if distance <= 4 {
                // Central rolls (2–3) are more likely (R-2's 1-4-6-4-1 shape).
                let weight = distance == 2 || distance == 3 ? 60 : 30
                penalty += weight
            }
        }
        return penalty
    }

    /// Deterministic noise; weaker bots shake their picks more.
    private func noise(rng: inout SeededRNG) -> Int {
        let spread = (6 - strength) * 30
        return spread == 0 ? 0 : Int(rng.next(UInt64(spread)))
    }
}
