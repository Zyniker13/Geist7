// PuzzleGenerator.swift — the MT-P4.2 puzzle miner (§7: "mining
// positions with forced landings within N plies").
//
// A puzzle row is a chart + island overlay + the hero canoe at sea
// (goal owner to move; every other canoe at home). A row ships only
// when the reconstructed position is VERIFIED by the AND/OR search
// below:
//
//   solvable — the goal owner can force a landing of one of their
//              canoes within `plies` of their own actions, whatever
//              the opponent replies (OR over the goal owner's legal
//              actions, AND over every opponent reply — the real
//              reducer's legal actions, so tows, placements, and
//              passes are all honoured by construction), and
//   unique   — exactly ONE of the goal owner's legal actions starts
//              a forced line (a second winning first move would make
//              the puzzle ambiguous).
//
// `plies` counts the goal owner's own actions (defenders reply in
// between); `plies: 1` degenerates to ADR-0019's spot-the-landing
// check, which is how the G3 rows were verified.
//
// Cost control (ADR-0019's lesson: the unpruned AND/OR produced zero
// rows in 25 minutes): attacker candidates are capped and ordered by
// the A.5 evaluation (root CAP_ROOT — mirroring ADR-0020's caps);
// the defender's reply list is NEVER pruned (AND semantics), but the
// search cuts out at the first refuting reply and the memo skips
// re-verification of repeated (position, plies) pairs.

import MTCore

public struct PuzzleGenerator: Sendable {
    public init() {}

    /// Attacker-candidate cap at the root (ADR-0020 style). Interior
    /// attacker nodes keep it too; ply-1 verification uses the full
    /// list (the spot check must see every landing).
    static let capRoot = 24

    /// Memo over (Zobrist position key, plies left) → verified result.
    public final class Memo: @unchecked Sendable {
        private var storage: [UInt64: [Int: Bool]] = [:]
        public init() {}
        func value(for key: UInt64, plies: Int) -> Bool? {
            storage[key]?[plies]
        }
        func insert(value: Bool, for key: UInt64, plies: Int) {
            storage[key, default: [:]][plies] = value
        }
        /// Distinct (position, plies) entries memoized so far.
        public var count: Int { storage.values.reduce(0) { $0 + $1.count } }
    }

    /// True when `owner` can force a landing within `plies` of their
    /// own actions from `state`, whatever the opponent does. Memoized
    /// over (Zobrist key, plies left).
    public func forcedLanding(
        in state: GameState, owner: PlayerID, plies: Int,
        memo: Memo
    ) -> Bool {
        precondition(plies >= 1, "plies counts the goal owner's actions")
        let key = Zobrist.positionKey(of: state)
        if let cached = memo.value(for: key, plies: plies) { return cached }
        let result = forcedLandingUncached(in: state, owner: owner, plies: plies, memo: memo)
        memo.insert(value: result, for: key, plies: plies)
        return result
    }

    func forcedLandingUncached(
        in state: GameState, owner: PlayerID, plies: Int, memo: Memo
    ) -> Bool {
        guard state.toMove == owner else { return false }
        let actions = Reducer.legalActions(in: state)
        let cap = plies >= 2 ? Self.capRoot : actions.count
        let candidates = orderedCandidates(actions, in: state, owner: owner, cap: cap)
        for action in candidates {
            guard let (next, _) = try? Reducer.apply(action, to: state) else {
                continue
            }
            if landed(owner: owner, in: next) { return true }
            guard plies >= 2 else { continue }
            if opponentCannotPrevent(in: next, owner: owner, plies: plies - 1, memo: memo) {
                return true
            }
        }
        return false
    }

    /// AND over every opponent reply: every reply must leave a
    /// position where `owner` still forces a landing in `plies` more
    /// of their own actions. The reply list is never capped (AND
    /// semantics) and the loop returns on the first refuting reply.
    func opponentCannotPrevent(
        in state: GameState, owner: PlayerID, plies: Int, memo: Memo
    ) -> Bool {
        let replies = Reducer.legalActions(in: state)
        for reply in replies {
            guard let (after, _) = try? Reducer.apply(reply, to: state) else {
                return false
            }
            // R-7 alternation: after the opponent's single action the
            // owner moves next. Any other successor shape refutes the
            // line rather than being assumed safe.
            guard after.toMove == owner else { return false }
            guard forcedLanding(in: after, owner: owner, plies: plies, memo: memo) else {
                return false
            }
        }
        return !replies.isEmpty
    }

    /// Landing of any of `owner`'s canoes in the successor state (a
    /// landing ends the game; Reducer sets the canoe to `.landed`).
    func landed(owner: PlayerID, in state: GameState) -> Bool {
        state.landed[owner, default: 0] > 0
            || state.canoes.values.contains { $0.owner == owner && $0.location == .landed }
    }

    /// Candidates ordered by the A.5 evaluation of the immediate
    /// successor, best first, capped at `cap`. `cap >= actions.count`
    /// returns the list unchanged.
    func orderedCandidates(
        _ actions: [Action], in state: GameState, owner: PlayerID, cap: Int
    ) -> [Action] {
        guard actions.count > cap else { return actions }
        let scored: [(Action, Int)] = actions.map { action in
            guard let (next, _) = try? Reducer.apply(action, to: state) else {
                return (action, Int.min)
            }
            return (action, Evaluator.score(state: next, for: owner))
        }
        return Array(scored.sorted { $0.1 > $1.1 }.prefix(cap).map { $0.0 })
    }

    /// The winning first actions of a position (for the uniqueness
    /// check and for tests): every legal action that either lands
    /// immediately or starts a forced line.
    public func winningFirstActions(
        in state: GameState, owner: PlayerID, plies: Int
    ) -> [Action] {
        guard state.toMove == owner else { return [] }
        let actions = Reducer.legalActions(in: state)
        var winners: [Action] = []
        let memo = Memo()
        for action in actions {
            guard let (next, _) = try? Reducer.apply(action, to: state) else { continue }
            if landed(owner: owner, in: next) {
                winners.append(action)
                continue
            }
            guard plies >= 2,
                opponentCannotPrevent(in: next, owner: owner, plies: plies - 1, memo: memo)
            else { continue }
            winners.append(action)
        }
        return winners
    }

    /// Verify a candidate row: demand solvable AND unique. Returns
    /// the verified winning first action, or nil.
    public func verify(
        state: GameState, owner: PlayerID, plies: Int
    ) -> Action? {
        let winners = winningFirstActions(in: state, owner: owner, plies: plies)
        guard winners.count == 1 else { return nil }
        return winners[0]
    }
}
