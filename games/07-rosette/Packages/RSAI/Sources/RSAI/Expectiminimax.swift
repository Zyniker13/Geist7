import Foundation
import RSCore

/// The heuristic evaluation for the variant expectiminimax (A.5), from the
/// searching player's perspective:
///
///     2·(pipsOpp − pipsMe) + 1·(rosettesMe − rosettesOpp)
///       + 1·(safeMe − safeOpp) + 2·(exposedOpp − exposedMe)
///
/// The pip term dominates: winning is a race to bear off all pieces, so the
/// distance-to-home difference must outweigh every other term. `safePieces`
/// are pieces on the shared run or exit that cannot be captured (safe
/// rosette, private exit squares); the private START (0–3) is NOT counted as
/// safe, because hoarding pieces there is not progress. `exposedPieces` are
/// pieces on shared squares an enemy can reach within 1–4 steps, each
/// weighted by that roll's probability. Every term is antisymmetric in the
/// two players, so evaluating the same state for either player yields exactly
/// negated raw scores and complementary pseudo-win-probabilities — the
/// property minimax search relies on. The raw score is squashed into a
/// pseudo-win-probability so leaf values and terminal 0/1 values live on one
/// scale.
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
    /// Antisymmetric: `rawScore(state, .player1) == -rawScore(state, .player0)`.
    public static func rawScore(of state: MatchState, for me: PlayerID) -> Double {
        var pipsMe = 0.0
        var pipsOpp = 0.0
        var rosettes = 0.0
        var safe = 0.0
        var exposure = 0.0

        let trackLength = state.track.length
        for piece in state.pieces {
            let isMine = piece.owner == me
            let sign: Double = isMine ? 1 : -1
            let pips = Double(pipDistance(piece, trackLength: trackLength))
            if isMine { pipsMe += pips } else { pipsOpp += pips }

            if piece.position >= 0 {
                // Rosettes held, and pieces on squares the enemy can never
                // reach (safe rosettes, private exit squares): captured-proof.
                // The private START (0–3) is NOT counted as safe, because
                // hoarding pieces there is not progress.
                let onSafeRosette = state.track.safeRosetteIndices.contains(piece.position)
                let onPrivateExit = piece.position >= 12
                if state.track.rosetteIndices.contains(piece.position) {
                    rosettes += sign
                }
                // Only count safety for pieces that have advanced past the
                // private start — a piece sitting on 0–3 is not "safely
                // advanced", it is simply not yet racing.
                if (onSafeRosette || onPrivateExit) && piece.position >= 4 {
                    safe += sign
                }
                // Exposure: only shared squares can be captured. An enemy
                // piece `d` steps behind (1–4) can hit it with probability
                // p(d); enemy pieces already past cannot come back.
                if piece.position >= 4 && piece.position < 12 {
                    let behind = state.pieces.filter {
                        $0.owner != piece.owner && $0.position >= 0 && $0.position < piece.position
                    }
                    for enemy in behind {
                        let distance = piece.position - enemy.position
                        if distance >= 1 && distance <= 4 {
                            exposure += sign * rollProbability(distance, dice: state.dice)
                        }
                    }
                }
            } else if piece.position == -2 {
                safe += sign
            }
        }

        // Own exposure must lower the score (the piece can be sent home),
        // opponent exposure must raise it; `exposure` sums sign·p over both
        // sides, so it enters negated.
        return 2 * (pipsOpp - pipsMe) + rosettes + safe - 2 * exposure

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
/// can never drift from the rules (ADR-0010).
///
/// Depth counts *decision* plies; chance nodes are free. With depth 3 the
/// leaf evaluation happens at the fourth decision level's pre-roll states.
public struct Expectiminimax: Sendable {

    /// Search depth in decision plies (A.5 default: 3).
    public let depth: Int

    public init(depth: Int = 3) {
        self.depth = max(1, depth)
    }

    /// Total search-node allowance for one value search. Every recursive
    /// `search` call consumes one node, chance nodes and passes included,
    /// so this bounds the whole enumerated tree, not just the recursion
    /// path: without it, pass chains (a roll of zero, or a roll with no
    /// legal move) spend no decision ply and the chance-node enumeration
    /// multiplies the tree without bound (two pre-roll states alternating
    /// through repeated zero rolls alone is exponential). Exhausted
    /// searches fall back to the leaf evaluation. With alpha-beta pruning
    /// a legitimate depth-3 tree fits well inside the allowance.
    static func searchBudget(for depth: Int) -> Int { 256 * (depth + 2) }

    /// The mutable node counter shared across one search (a class so the
    /// whole tree draws from a single allowance).
    private final class NodeBudget: @unchecked Sendable {
        var remaining: Int
        init(_ remaining: Int) { self.remaining = remaining }
    }

    /// Values of states already resolved during one search, keyed by
    /// `(state hash, remaining plies)`. Pass chains make the chance-node
    /// enumeration revisit the same states repeatedly — two pre-roll
    /// states alternating through repeated zero rolls alone would double
    /// the tree at every level — so caching turns that exponential blowup
    /// polynomial. Only exact values are stored: terminal and leaf
    /// evaluations are window-independent, and interior nodes are stored
    /// only when they were searched with the full `[-1, 2]` window (a
    /// narrowed fail-soft window yields bounds, which would be wrong to
    /// reuse as exact values).
    private final class TranspositionTable: @unchecked Sendable {
        var map: [UInt64: Double] = [:]
    }

    /// The searching player's value of `state`: terminal states return 1/0,
    /// leaves the evaluator, interior nodes the expectiminimax value.
    ///
    /// `searchDepth` overrides the configured depth for calls whose
    /// decisions tolerate shallower equity: cube decisions use depth 2
    /// (ADR-0010) because the Finkel thresholds are wide (offer at 70%,
    /// take at 25%) and the fresh-turn chance tree at depth 3 is the
    /// single most expensive search in a match.
    public func value(
        of state: MatchState, for me: PlayerID, searchDepth: Int? = nil
    ) -> Double {
        let plies = max(1, searchDepth ?? depth)
        return search(
            state, for: me, remaining: plies,
            budget: NodeBudget(Self.searchBudget(for: plies)),
            tt: TranspositionTable(), path: [state.stateHash], alpha: -1, beta: 2)
    }

    /// The bounded search. `remaining` is the number of decision plies the
    /// search may still spend; `budget` is the shared total-node allowance
    /// (see `searchBudget`); `tt` caches exact values for this search (see
    /// `TranspositionTable`); `path` holds the state hashes on the current
    /// recursion path for cycle detection; `alpha`/`beta` are the fail-soft
    /// alpha-beta window (node values always lie in [0, 1]).
    ///
    /// Cycle handling: a pass chain (a roll of zero, or a roll with no
    /// legal move) spends no decision ply, so the enumerated tree can
    /// return to a position it already visited — e.g. both players rolling
    /// zero alternates between the same two pre-roll states forever, a
    /// cycle live play escapes only because real dice vary. A child whose
    /// hash is already on the path is therefore evaluated directly as a
    /// leaf rather than recursed (ADR-0010).
    ///
    /// Pruning: decision nodes prune with the alpha-beta window; chance
    /// nodes prune star1-style — once the weighted prefix sum plus the
    /// remaining outcome weight's best case cannot land inside the window,
    /// the remaining outcomes cannot change the parent's choice. Pruned
    /// values stay exact, so `value(state, p0) + value(state, p1) == 1`.
    private func search(
        _ state: MatchState, for me: PlayerID, remaining: Int, budget: NodeBudget,
        tt: TranspositionTable, path: Set<UInt64>, alpha: Double, beta: Double
    ) -> Double {
        if state.isComplete {
            return state.outcome?.winner == me ? 1.0 : 0.0
        }
        let key = state.stateHash ^ (UInt64(truncatingIfNeeded: remaining) << 56)
        if let cached = tt.map[key] { return cached }
        // Every non-cached visit draws from the allowance — leaves
        // included — so the budget bounds the whole enumerated tree, not
        // just the interior nodes.
        budget.remaining -= 1
        if remaining == 0 || budget.remaining <= 0 {
            let leaf = Evaluator.winProbability(of: state, for: me)
            tt.map[key] = leaf
            return leaf
        }
        let fullWindow = alpha == -1 && beta == 2
        let value = searchBody(
            state, for: me, remaining: remaining, budget: budget, tt: tt,
            path: path, alpha: alpha, beta: beta)
        if fullWindow { tt.map[key] = value }
        return value
    }

    /// The interior-node body of `search` (everything after the terminal,
    /// cache, and leaf checks).
    private func searchBody(
        _ state: MatchState, for me: PlayerID, remaining: Int, budget: NodeBudget,
        tt: TranspositionTable, path: Set<UInt64>, alpha: Double, beta: Double
    ) -> Double {
        var alpha = alpha
        var beta = beta
        // A child already on the current path is a cycle: evaluate it as a
        // leaf instead of recursing into it again.
        func descend(_ child: MatchState, remaining: Int) -> Double {
            if path.contains(child.stateHash) {
                return Evaluator.winProbability(of: child, for: me)
            }
            var childPath = path
            childPath.insert(child.stateHash)
            return search(
                child, for: me, remaining: remaining,
                budget: budget, tt: tt, path: childPath, alpha: alpha, beta: beta)
        }
        if !state.hasRolled {
            // Chance node: average the dice outcomes through the engine's
            // own post-roll transition. A pending reroll omen redraws from
            // the same distribution, so the outcome weights are unchanged.
            // Outcomes are walked heaviest first so star1 pruning cuts in
            // early. `partial` and `rest` bound the expectation: it lies
            // in [partial, partial + rest]; once that interval leaves the
            // window the remaining outcomes cannot matter.
            let outcomes = state.dice.outcomes
                .filter { $0.weight > 0 }
                .sorted { $0.weight > $1.weight }
            var partial = 0.0
            var rest = 1.0
            for outcome in outcomes {
                let weight = Double(outcome.weight) / Double(state.dice.denominator)
                guard weight > 0 else { continue }
                var rolled = state
                rolled.hasRolled = true
                guard
                    let (after, _) = try? Reducer.postRoll(
                        to: rolled, amount: outcome.value, events: [])
                else {
                    rest -= weight
                    continue
                }
                partial += weight * descend(after, remaining: remaining)
                rest -= weight
                if partial + rest <= alpha || partial >= beta {
                    // The expectation cannot land inside the window.
                    return max(partial, min(partial + rest, beta))
                }
            }
            return partial
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
            return descend(Reducer.endTurn(state), remaining: remaining)
        }
        let maximising = state.currentPlayer == me
        // Move ordering: the cheapest useful order is by the child's leaf
        // evaluation, which makes the alpha-beta cutoffs bite early. Moves
        // the reducer rejects (MoveGen/Reducer disagreement) are dropped.
        let ordered = moves.compactMap { move -> (MatchState, Double)? in
            guard let (after, _) = try? Reducer.applyMove(to: state, piece: move.piece)
            else { return nil }
            let score = Evaluator.rawScore(of: after, for: state.currentPlayer)
            return (after, score)
        }
        .sorted {
            maximising ? $0.1 > $1.1 : $0.1 < $1.1
        }
        var best = maximising ? -Double.infinity : Double.infinity
        for (after, _) in ordered {
            let child = descend(after, remaining: remaining - 1)
            if maximising {
                if child > best {
                    best = child
                }
                if best >= beta {
                    return best
                }
                if best > alpha {
                    alpha = best
                }
            } else {
                if child < best {
                    best = child
                }
                if best <= alpha {
                    return best
                }
                if best < beta {
                    beta = best
                }
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
        // One transposition table shared across the root's children: the
        // chance chains under different moves revisit the same states, so
        // sharing the cache cuts the whole decision's cost further.
        let tt = TranspositionTable()
        // Root window: the mover maximises, so children start at
        // (alpha = best-so-far, beta = +inf).
        for move in moves.sorted(by: { $0.piece < $1.piece }) {
            guard let (after, _) = try? Reducer.applyMove(to: state, piece: move.piece)
            else { continue }
            // The root choice is itself a decision ply, so children are
            // searched with one fewer remaining ply (ADR-0010): this keeps
            // the whole decision bounded at `depth` plies and inside the
            // latency budget.
            let childPath: Set<UInt64> = [state.stateHash, after.stateHash]
            let child = search(
                after, for: me, remaining: depth - 1,
                budget: NodeBudget(Self.searchBudget(for: depth)), tt: tt,
                path: childPath, alpha: max(bestValue, -1), beta: 2)
            if child > bestValue {
                bestValue = child
                best = move
            }
        }
        return (best, bestValue)
    }
}
