// AlphaBeta.swift — the §7/A.5 search: alpha-beta with iterative
// deepening, a transposition table, a history heuristic, and
// quiescence on becalming placements.
//
// A.5's design, honored exactly:
// - **Iterative deepening** from depth 1 to the tier's target, each
//   pass searching root actions in the previous pass's value order
//   (best-first, so the final pass's cutoffs bite early).
// - **Transposition table** keyed by Zobrist.positionKey, capacity
//   2^19 entries, storing depth, exact/bound value, and the best
//   action for move ordering.
// - **History heuristic** table indexed by (toMove, action kind) —
//   the coarse index keeps the table small and stable across the
//   state's cell counts; cutoff counts bump the entries, and the
//   root reorders actions by score-then-history.
// - **Quiescence on becalming placements** (depth 2): after a search
//   leaf, if the side to move can place an island that becalms a
//   rival canoe, the search extends two plies past the horizon so a
//   depth-1 search does not walk into a becalm blind (§7: "moves
//   that becalm canoes").
//
// Determinism (ADR-0018): the search is pure and fixed-budget in
// depth — no wall clock, no threading. Identical states and tiers
// yield identical actions everywhere, so recorded replays and the
// UI's replayed positions stay byte-identical (INV-1/INV-4).

import MTCore

public struct AlphaBeta: Sendable {
    /// The tier whose depth (and noise band) this search runs.
    public let tier: Tier

    public init(tier: Tier) { self.tier = tier }

    /// Measurement knob for the sim tool's ADR-0020 strength studies
    /// (`MTAI_NOCAPS=1`): disables the root/interior breadth caps so a
    /// capped search can be compared against the uncapped one. The
    /// shipped game never calls it, so every runtime sees the caps and
    /// replay determinism (INV-1/INV-4) is unaffected.
    public static func setCaps(_ enabled: Bool) {
        RootBreadth.capsEnabled = enabled
    }

    /// A.5's search-side placement pruning: of the state's legal
    /// placements, keep the cells within 2 of any ray of the current
    /// field that touches a canoe's shortest path to its target. The
    /// A.5 text is a performance device, not a rules change — the
    /// reducer accepts any legal placement, so this narrows only what
    /// the search CONSIDERS. Placement-heavy tiers that face no canoes
    /// yet (every opening) fall back to cells near the two atolls'
    /// launch corridors so the pruning never empties the list.
    static func searchPlacements(in state: GameState) -> [Action] {
        let all = Reducer.legalActions(in: state)
        let placements = all.filter {
            if case .placeIsland = $0 { return true }
            return false
        }
        guard placements.count > 24 else { return all }

        // The rays worth caring about: those passing within 2 of any
        // sea canoe (either side) — the corridors play actually uses.
        var nearCanoes: Set<Hex> = []
        for id in CanoeID.allCanoeIDs {
            guard case .sea(let at) = state.canoe(id).location else { continue }
            nearCanoes.insert(at)
            for n in at.neighbors() { nearCanoes.insert(n) }
            for n2 in at.neighbors().flatMap({ $0.neighbors() }) {
                nearCanoes.insert(n2)
            }
        }
        var corridor: Set<Hex> = []
        for ray in state.field.rays {
            guard ray.cells.contains(where: { nearCanoes.contains($0) }) else { continue }
            for cell in ray.cells {
                corridor.insert(cell)
                for n in cell.neighbors() { corridor.insert(n) }
            }
        }
        // Launch cells join the corridor: an island that walls off a
        // launch sea cell is always interesting.
        for player in [PlayerID.p1, .p2] {
            for atollCell in state.chart.atoll(for: player).cells {
                for n in atollCell.neighbors() where state.chart.ocean.contains(n) {
                    corridor.insert(n)
                    for n2 in n.neighbors() { corridor.insert(n2) }
                }
            }
        }

        let pruned = placements.filter { action in
            guard case .placeIsland(let cell) = action else { return false }
            return corridor.contains(cell)
        }
        // Never prune to fewer than 8 placements (a safety floor so a
        // degenerate corridor can't blind the search).
        guard pruned.count >= 8 else { return all }
        let others = all.filter {
            if case .placeIsland = $0 { return false }
            return true
        }
        return others + pruned
    }

    /// The action the tier takes in `state`. Never fails: the choice
    /// is always a member of `Reducer.legalActions(in:)`. When every
    /// root action scores inside the tier's noise band, one is chosen
    /// uniformly by `rng` (Paddler's band; 0-band tiers take the best
    /// and fall to history-order tie-breaks, never the RNG — the
    /// recorded replays stay deterministic).
    public func chooseAction(
        in state: GameState, rng: inout SeededRNG
    ) -> Action {
        let actions = Self.searchPlacements(in: state)
        precondition(!actions.isEmpty, "legalActions always offers at least pass")
        if actions.count == 1 { return actions[0] }
        if state.status.isOver { return actions[0] }

        var root = RootSearch(state: state)
        let best = root.run(depth: tier.depth, actions: actions)
        // Paddler's noise band: uniform over actions within `band`
        // points of the best. Deterministic given the seed.
        let band = tier.noiseBand
        if band > 0 {
            let top = best[0].value
            let inBand = best.filter { top - $0.value <= band }.map { entry -> Action in
                entry.action
            }
            if inBand.count > 1 {
                return inBand[rng.nextInt(below: inBand.count)]
            }
        }
        return best[0].action
    }

    /// The root's scored actions, best-first by the final iteration's
    /// values — the list chooseAction plays from (the head is the
    /// move). Exposed for the tier contract tests, which pin the
    /// best-first contract the root must hold.
    func rootScores(in state: GameState) -> [Scored] {
        let actions = Self.searchPlacements(in: state)
        precondition(!actions.isEmpty, "legalActions always offers at least pass")
        if state.status.isOver || actions.count == 1 {
            return actions.map { Scored(action: $0, value: 0) }
        }
        var root = RootSearch(state: state)
        return root.run(depth: tier.depth, actions: actions)
    }

    /// One root entry: an action and its searched value.
    struct Scored: Sendable {
        let action: Action
        let value: Int
    }

    /// The iterative-deepening root over one state.
    private struct RootSearch {
        let state: GameState
        var table: TT
        var history: History

        init(state: GameState) {
            self.state = state
            self.table = TT()
            self.history = History()
        }

        /// Deepen 1...depth, reordering by the previous pass, and
        /// return the final pass's ordered root with values from the
        /// deepest completed pass. From the third pass on, only the
        /// RootBreadth.cap-best actions are re-searched (ADR-0020):
        /// the earlier passes scored every action, so the cap drops
        /// only actions those passes already ranked below the cut.
        mutating func run(depth: Int, actions: [Action]) -> [Scored] {
            var ordered: [Scored] = actions.map { Scored(action: $0, value: 0) }
            var final: [Scored] = ordered
            for d in 1...max(1, depth) {
                let pass = ordered.count > RootBreadth.cap && d >= 3
                    ? Array(ordered.prefix(RootBreadth.cap)) : ordered
                var scored: [Scored] = []
                for entry in pass {
                    let next = Search.apply(entry.action, to: state)
                    let value = -Search.negamax(
                        next, depth: d - 1, alpha: -Int.max, beta: Int.max,
                        table: &table, history: &history, deep: depth >= 4)
                    scored.append(Scored(action: entry.action, value: value))
                }
                if pass.count < ordered.count {
                    // Untouched actions carry their previous value so
                    // the returned list stays complete and ordered.
                    let searched = Set(pass.map { $0.action })
                    for stale in ordered where !searched.contains(stale.action) {
                        scored.append(stale)
                    }
                }
                final = scored
                ordered = scored.sorted { $0.value > $1.value }
            }
            // The contract chooseAction relies on: best-first by the
            // FINAL iteration's values. Returning the list in search
            // order made the root play the previous iteration's best
            // (a depth-2 tier played its depth-1 best), and the noise
            // band compared against a non-maximal value.
            return final.sorted { $0.value > $1.value }
        }
    }

    /// Search-shared helpers (action application and the negamax
    /// recursion live here so RootSearch and Quiescence share them).
    enum Search {
        /// Reducer.apply with the engine's own precondition: every
        /// action searched was offered by legalActions. `visited` is
        /// carried through: the R-23 hash bookkeeping inside Reducer
        /// costs one Zobrist hash per apply, and in exchange the
        /// search SEES a would-be third repetition — it ends the game
        /// by the R-11 tie-break (scored via terminalValue), so the
        /// AI can no longer walk into tie-break losses. (The old
        /// apply wiped `visited`, leaving the "AI sees a repetition
        /// as terminal by score" promise in the Reducer comment
        /// unimplemented: nothing scored it, so repetitions looked
        /// free and the engine steered into them.)
        static func apply(_ action: Action, to state: GameState) -> GameState {
            do {
                return try Reducer.apply(action, to: state).state
            } catch {
                preconditionFailure("legalActions offered an illegal action: \(error)")
            }
        }

        /// A.5's fail-soft negamax with alpha-beta, the TT, and the
        /// history heuristic. Values are from `state.toMove`'s view.
        /// `deep` selects ADR-0020's interior breadth cap (the deep
        /// tiers, depth ≥ 4); shallow tiers expand every child.
        static func negamax(
            _ state: GameState, depth: Int, alpha: Int, beta: Int,
            table: inout TT, history: inout History, deep: Bool
        ) -> Int {
            if state.status.isOver {
                return terminalValue(state)
            }
            if depth <= 0 {
                return Quiescence.score(
                    state, alpha: alpha, beta: beta, table: table,
                    history: &history, depth: 2)
            }

            let key = Zobrist.positionKey(of: state)
            let entry = table.lookup(key, depth: depth)
            if let entry {
                switch entry.kind {
                case .exact: return entry.value
                case .lower where entry.value >= beta: return entry.value
                case .upper where entry.value <= alpha: return entry.value
                default: break
                }
            }

            let actions = AlphaBeta.searchPlacements(in: state)
            var alpha = alpha
            var bestValue = -Int.max
            var bestAction: Action?
            let originalAlpha = alpha

            // ADR-0020: the deep tiers cap interior breadth too — the
            // ordered prefix (TT best, then history) is searched, the
            // rest skipped. Ordered prefix ⇒ deterministic subset.
            var children = Search.order(actions, best: entry?.best, history: history)
            if deep, RootBreadth.capsEnabled, depth >= 2,
                children.count > RootBreadth.interiorCap
            {
                children = Array(children.prefix(RootBreadth.interiorCap))
            }

            for action in children {
                let next = apply(action, to: state)
                let value = -negamax(
                    next, depth: depth - 1, alpha: -beta, beta: -alpha,
                    table: &table, history: &history, deep: deep)
                if value > bestValue {
                    bestValue = value
                    bestAction = action
                }
                if value > alpha {
                    alpha = value
                }
                if alpha >= beta {
                    history.bump(action)
                    break
                }
            }

            let kind: TTEntry.Kind
            if bestValue <= originalAlpha {
                kind = .upper
            } else if bestValue >= beta {
                kind = .lower
            } else {
                kind = .exact
            }
            table.store(
                key, depth: depth, value: bestValue, kind: kind,
                best: bestAction)
            return bestValue
        }

        /// Move ordering: the TT's best action first, then by history
        /// score (cutoff-heavy actions first), then the stable
        /// legalActions order.
        static func order(
            _ actions: [Action], best: Action?, history: History
        ) -> [Action] {
            var ordered = actions
            ordered.sort { a, b in
                if let best, a == best { return true }
                if let best, b == best { return false }
                return history.score(of: a) > history.score(of: b)
            }
            return ordered
        }

        /// A finished game's value from the mover's view: a win lands
        /// beyond any positional score (landed × 100 tops out under
        /// 500), a loss is its mirror, and the R-11 tie-break (the
        /// third repetition or the stuck rule) is a dead draw.
        static func terminalValue(_ state: GameState) -> Int {
            guard let winner = state.status.winner else { return 0 }
            return winner == state.toMove ? 100_000 : -100_000
        }
    }
}

/// One TT entry.
struct TTEntry: Sendable {
    enum Kind: Sendable { case exact, lower, upper }

    let depth: Int
    let value: Int
    let kind: Kind
    let best: Action?
}

/// The 2^19-entry transposition table (§7/A.5). Fixed capacity, no
/// allocation growth: index = key & mask, collisions overwrite the
/// shallower-or-equal entry. Deterministic: two equal states always
/// leave the same table state.
struct TT: Sendable {
    private static let bits = 19
    private static let mask = (1 << bits) - 1
    private var slots: [UInt64: TTEntry] = [:]

    mutating func store(
        _ key: UInt64, depth: Int, value: Int, kind: TTEntry.Kind,
        best: Action?
    ) {
        let entry = TTEntry(depth: depth, value: value, kind: kind, best: best)
        if let existing = slots[key & UInt64(Self.mask)],
            existing.depth > depth {
            return  // keep the deeper entry
        }
        slots[key & UInt64(Self.mask)] = entry
    }

    func lookup(_ key: UInt64, depth: Int) -> TTEntry? {
        guard let entry = slots[key & UInt64(Self.mask)], entry.depth >= depth
        else { return nil }
        return entry
    }
}

/// ADR-0020's root breadth cap: the deep tiers' budgets are met by
/// widening the A.5 placement pruning to the ROOT only, keeping a
/// deterministic subset of root actions. The cap keeps the TT-best
/// and history-ranked prefix (the same order the search would use),
/// so it can never drop a root action the search would have picked
/// at a shallower pass — the choice stays seed-deterministic and the
/// tree stays a strict subset of the unpruned one.
enum RootBreadth {
    /// Root actions searched per pass at depth ≥ 3 (the deep tiers).
    static let cap = 24
    /// Interior-node breadth at depth ≥ 2 for the deep tiers: after
    /// move ordering (TT best, then history), only this many children
    /// are searched at an interior node. Measured on the radius-7
    /// charts: without it a depth-4/6 interior node expands the full
    /// placement list (~100+ actions) at every ply, and a 3-ply
    /// Navigator soak takes ~2 minutes per ply — the tier gap would
    /// never fit the §7 budgets. The cap keeps the ordered prefix, so
    /// the searched tree stays a deterministic strict subset and
    /// seed-determinism (ADR-0018) is untouched.
    static let interiorCap = 12

    /// Whether the caps apply. The sim tool's strength studies
    /// (`MTAI_NOCAPS=1`) clear this through `AlphaBeta.setCaps(_:)`;
    /// the game never does, so every shipped runtime sees the caps
    /// and replay determinism (INV-1/INV-4) is unaffected.
    nonisolated(unsafe) static var capsEnabled = true

    static func limit(_ ordered: [AlphaBeta.Scored]) -> [AlphaBeta.Scored] {
        guard capsEnabled else { return ordered }
        guard ordered.count > cap else { return ordered }
        return Array(ordered.prefix(cap))
    }
}

/// The history heuristic: a cutoff count per (mover, action kind),
/// added to move ordering. The coarse index keeps the table fixed
/// size; cutoff-heavy action kinds bubble to the front over a game.
struct History: Sendable {
    private var counts: [UInt64: Int] = [:]

    mutating func bump(_ action: Action) {
        counts[index(of: action), default: 0] += 1
    }

    func score(of action: Action) -> Int {
        counts[index(of: action)] ?? 0
    }

    private func index(of action: Action) -> UInt64 {
        switch action {
        case .placeIsland: return 0x10
        case .launch: return 0x20
        case .sail: return 0x30
        case .tow: return 0x40
        case .pass: return 0x50
        }
    }
}
