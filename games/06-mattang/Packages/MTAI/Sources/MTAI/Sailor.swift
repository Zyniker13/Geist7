// Sailor.swift — the §7 Sailor tier: a one-ply greedy heuristic.
//
// Sailor is the mid tier of §7 ("Sailor (depth 2)" gains its depth
// with P4's AlphaBeta; P2 ships the 1-ply reader MT-P2.2 names). It
// picks the legal action whose immediate successor scores best under
// Evaluator for the mover. Ties are broken uniformly over the
// equal-best actions, using the caller's SeededRNG, so games remain
// reproducible under a recorded seed (S0.2).

import MTCore

public struct Sailor: Sendable {
    public init() {}

    /// The action Sailor takes in `state`. Never fails: the choice is
    /// always a member of `Reducer.legalActions(in:)`.
    public func chooseAction(in state: GameState, rng: inout SeededRNG) -> Action {
        let mover = state.toMove
        let actions = Reducer.legalActions(in: state)
        precondition(!actions.isEmpty, "legalActions always offers at least pass")
        if actions.count == 1 { return actions[0] }

        var bestScore: Int?
        var best: [Action] = []
        for action in actions {
            let next: GameState
            do {
                next = try Reducer.apply(action, to: state).state
            } catch {
                preconditionFailure("legalActions offered an illegal action: \(error)")
            }
            let score = Evaluator.score(state: next, for: mover)
            switch bestScore {
            case nil:
                bestScore = score
                best = [action]
            case .some(let current) where score > current:
                bestScore = score
                best = [action]
            case .some(let current) where score == current:
                best.append(action)
            default:
                break
            }
        }
        return best[rng.nextInt(below: best.count)]
    }
}
