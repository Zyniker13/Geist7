// MARK: - OddsCalculator

/// Exact probabilities for the odds panel (RS-P2.1). Pure functions over the
/// current state: no randomness, no wall-clock, fully deterministic.
///
/// The capture chance is the probability that the current player's next roll
/// admits at least one capturing move under the astragal distribution. It is
/// computed exactly by enumerating every dice outcome, building the
/// hypothetical post-roll state exactly as `Reducer.applyRoll` does, and
/// probing each candidate move through the reducer, counting an outcome when
/// the reducer emits `.pieceCaptured` (so capture legality — safe rosettes,
/// the safety omen, R-5 — comes from the same engine that plays the game).
public enum OddsCalculator {
    /// The exact probability (0…1) that the current player's next roll
    /// admits at least one capturing move.
    public static func nextRollCaptureChance(for state: MatchState) -> Double {
        // A roll is only available from a fresh turn: a pending double must
        // be answered first (R-10) and a split's second half is not a roll.
        guard !state.isComplete, !state.hasRolled, !state.doubleOffered else {
            return 0
        }

        let denominator = state.dice.denominator
        guard denominator > 0 else { return 0 }

        var favorable = 0
        for outcome in state.dice.outcomes {
            // A roll of 0 passes the turn (R-3): no captures.
            guard outcome.value > 0 else { continue }
            if capturesExist(in: state, rolling: outcome.value) {
                favorable += outcome.weight
            }
        }
        return Double(favorable) / Double(denominator)
    }

    /// Whether any legal move for the given roll captures an opposing piece.
    static func capturesExist(in state: MatchState, rolling amount: Int) -> Bool {
        let unsafeActive = state.pendingOmen?.effect.kind == .unsafeRosettes
        let moves = MoveGen.legalMoves(
            for: state.currentPlayer,
            amount: amount,
            pieces: state.pieces,
            track: state.track,
            rules: state.ruleset,
            unsafeRosettesActive: unsafeActive
        )
        guard !moves.isEmpty else { return false }

        // The hypothetical post-roll state, built exactly as applyRoll does
        // for a non-zero amount with no active split.
        var hypothetical = state
        hypothetical.hasRolled = true
        hypothetical.diceValue = amount
        hypothetical.movablePieceIds = Set(moves.map { $0.piece })

        // Move actions draw no randomness, so the probe streams are never
        // stepped; any seed is equivalent. Each probe works on its own copy.
        for move in moves {
            var probe = hypothetical
            var rng = SeededRNG(seed: 0)
            var omenRng = SeededRNG(seed: 0)
            guard
                let result = try? Reducer.apply(
                    .move(move.piece), to: probe, rng: &rng, omenRng: &omenRng
                )
            else { continue }
            if result.events.contains(where: isCapture) {
                return true
            }
        }
        return false
    }

    /// Event predicate: the event is a capture.
    private static func isCapture(_ event: Event) -> Bool {
        if case .pieceCaptured = event { return true }
        return false
    }

    /// The odds panel line (RS-P2.1): "Chance to capture next roll: N%".
    public static func panelText(for state: MatchState) -> String {
        let chance = nextRollCaptureChance(for: state)
        let percentage = Int((chance * 100).rounded())
        return "Chance to capture next roll: \(percentage)%"
    }
}
