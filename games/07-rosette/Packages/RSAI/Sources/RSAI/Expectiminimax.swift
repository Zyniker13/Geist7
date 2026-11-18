import Foundation
import RSCore

/// The heuristic evaluation for the variant expectiminimax (A.5), from the
/// searching player's perspective:
///
///     pipsOpp − pipsMe + 6·rosettesHeld + 4·safePieces − 5·exposedPieces
///
/// where `exposedPieces` counts pieces an enemy can reach within 1–4 steps,
/// each weighted by that roll's probability. The raw score is squashed into
/// a pseudo-win-probability so leaf values and terminal 0/1 values live on
/// one scale.
public enum Evaluator {

    /// The pip distance still to walk for one piece (entry counts as a step
    /// from the path's start; borne-off pieces cost nothing).
    static func pipDistance(_ piece: Piece, trackLength: Int) -> Int {
        switch piece.position {
        case -2: return 0
        case -1: return trackLength
        case let step: return trackLength - step
        }
    }

    /// The probability (0…1) of rolling exactly `n` with the state's dice.
    static func rollProbability(_ n: Int, dice: DiceModel) -> Double {
        guard n >= 0 else { return 0 }
        for outcome in dice.outcomes where outcome.value == n {
            return Double(outcome.weight) / Double(dice.denominator)
        }
        return 0
    }

    /// The raw evaluation from `me`'s perspective, in arbitrary units.
    public static func rawScore(of state: MatchState, for me: PlayerID) -> Double {
        let opponent: PlayerID = me == .player0 ? .player1 : .player0
        var pipsMe = 0.0
        var pipsOpp = 0.0
        var rosettesHeld = 0.0
        var safePieces = 0.0
        var exposed = 0.0

        let trackLength = state.track.length
        for piece in state.pieces {
            let isMine = piece.owner == me
            let pips = Double(pipDistance(piece, trackLength: trackLength))
            if isMine { pipsMe += pips } else { pipsOpp += pips }

            if piece.position >= 0 {
                // Rosettes held and safe pieces: private squares can never
                // be reached by the enemy, safe rosettes cannot be captured.
                let onPrivate = piece.position < 4 || piece.position >= 12
                let onSafeRosette = state.track.safeRosetteIndices.contains(piece.position)
                if isMine {
                    if state.track.rosetteIndices.contains(piece.position) {
                        rosettesHeld += 1
                    }
                    if onPrivate || onSafeRosette { safePieces += 1 }
                }
                // Exposure: only shared squares can be captured. An enemy
                // piece `d` steps behind (1–4) can hit it with probability
                // p(d); enemy pieces already past cannot come back.
                if piece.position >= 4 && piece.position < 12 {
                    let behind = state.pieces.filter {
                        $0.owner != me && $0.position >= 0 && $0.position < piece.position
                    }
                    for enemy in behind {
                        let distance = piece.position - enemy.position
                        if distance >= 1 && distance <= 4 {
                            exposed += rollProbability(distance, dice: state.dice)
                        }
                    }
                }
            } else if piece.position == -2 {
                safePieces += 1
            }
        }

        return pipsOpp - pipsMe + 6 * rosettesHeld + 4 * safePieces - 5 * exposed
    }

    /// The squashed pseudo-win-probability in [0.02, 0.98]. The pips term
    /// dominates (about ±70 raw), so 100 units map to the full band.
    public static func winProbability(of state: MatchState, for me: PlayerID) -> Double {
        let raw = rawScore(of: state, for: me)
        return min(0.98, max(0.02, 0.5 + raw / 100.0))
    }
}

/// Depth-limited expectiminimax over the real engine (A.5: "expectiminimax
/// depth 3 with chance nodes"). Chance nodes enumerate the dice model's
/// outcomes and drive `Reducer.postRoll`; decision nodes drive
/// `Reducer.applyMove` — the exact semantics live play uses, so the search
/// can never drift from the rules (ADR-0011).
///
/// Depth counts *decision* plies; chance nodes are free. With depth 3 the
/// leaf evaluation happens at the fourth decision level's pre-roll states.
public struct Expectiminimax: Sendable {

    /// Search depth in decision plies (A.5 default: 3).
    public let depth: Int

    public init(depth: Int = 3) {
        self.depth = max(1, depth)
    }

    /// The searching player's value of `state`: terminal states return 1/0,
    /// leaves the evaluator, interior nodes the expectimax/minimax value.
    public func value(of state: MatchState, for me: PlayerID) -> Double {
        search(state, for: me, remaining: depth)
    }

    /// The bounded search. `remaining` is the number of decision plies the
    /// search may still spend; it must reach zero or the tree is unbounded.
    private func search(_ state: MatchState, for me: PlayerID, remaining: Int) -> Double {
        if state.isComplete {
            return state.outcome?.winner == me ? 1.0 : 0.0
        }
        if remaining == 0 {
            return Evaluator.winProbability(of: state, for: me)
        }
        if !state.hasRolled {
            // Chance node: average the dice outcomes through the engine's
            // own post-roll transition. A pending reroll omen redraws from
            // the same distribution, so the outcome weights are unchanged.
            var total = 0.0
            for outcome in state.dice.outcomes {
                let weight = Double(outcome.weight) / Double(state.dice.denominator)
                guard weight > 0 else { continue }
                var rolled = state
                rolled.hasRolled = true
                guard let (after, _) = try? Reducer.postRoll(
                    to: rolled, amount: outcome.value, events: [])
                else { continue }
                total += weight * search(after, for: me, remaining: remaining)
            }
            return total
        }
        // Decision node: the player to move maximises (minimises) if they
        // are (are not) the searching player.
        let unsafeActive = state.pendingOmen?.effect.kind == .unsafeRosettes
        let moves = MoveGen.legalMoves(
            for: state.currentPlayer,
            amount: state.diceValue ?? 0,
            pieces: state.pieces,
            track: state.track,
            rules: state.ruleset,
            unsafeRosettesActive: unsafeActive,
            allowEntry: !state.splitActive
        )
        guard !moves.isEmpty else {
            // No legal move though one was rolled: the turn passes.
            // A forced pass spends no decision ply.
            return search(Reducer.endTurn(state), for: me, remaining: remaining)
        }
        let maximising = state.currentPlayer == me
        var best = maximising ? -Double.infinity : Double.infinity
        for move in moves {
            guard let (after, _) = try? Reducer.applyMove(to: state, piece: move.piece)
            else { continue }
            let child = search(after, for: me, remaining: remaining - 1)
            if maximising ? child > best : child < best {
                best = child
            }
        }
        return best
    }

    /// The best move for the searching player at a rolled state, with its
    /// value. Ties break to the lowest piece id, keeping choices
    /// deterministic. Returns nil when there are no legal moves.
    public func bestMove(from state: MatchState, for me: PlayerID) -> (move: Move, value: Double)? {
        precondition(state.hasRolled, "bestMove expects a rolled state")
        let unsafeActive = state.pendingOmen?.effect.kind == .unsafeRosettes
        let moves = MoveGen.legalMoves(
            for: state.currentPlayer,
            amount: state.diceValue ?? 0,
            pieces: state.pieces,
            track: state.track,
            rules: state.ruleset,
            unsafeRosettesActive: unsafeActive,
            allowEntry: !state.splitActive
        )
        guard let first = moves.min(by: { $0.piece < $1.piece }) else { return nil }
        var best = first
        var bestValue = -Double.infinity
        for move in moves.sorted(by: { $0.piece < $1.piece }) {
            guard let (after, _) = try? Reducer.applyMove(to: state, piece: move.piece)
            else { continue }
            let child = value(of: after, for: me)
            if child > bestValue {
                bestValue = child
                best = move
            }
        }
        return (best, bestValue)
    }
}
