// Quiescence.swift — A.5's quiescence on becalming placements.
//
// A search leaf that ends just before the side to move places an
// island that becalms a rival canoe misreads the position: the becalm
// is a forced tactical swing (a canoe frozen for turns, −8 in the
// evaluation and unable to advance). §7: "quiescence on moves that
// becalm canoes." This pass extends at most `depth` plies past the
// horizon, and only along becalming placements — everything else is
// scored statically by Evaluator.
//
// The static score is Evaluator.score from the side to move's view;
// the search is fail-soft negamax with the shared TT and history.

import MTCore

enum Quiescence {
    /// The quiescence value of `state` from `state.toMove`'s view.
    /// The stand-pat value is the static evaluation; a becalming
    /// placement is searched when one exists, capping the recursion
    /// at `depth` further plies.
    static func score(
        _ state: GameState, alpha: Int, beta: Int,
        table: TT, history: inout History, depth: Int
    ) -> Int {
        if state.status.isOver {
            return AlphaBeta.Search.terminalValue(state)
        }
        let standPat = Evaluator.score(state: state, for: state.toMove)
        if depth <= 0 { return standPat }

        // The only extending moves: placements that becalm at least
        // one rival canoe on the sea (nothing to becalm → stand pat
        // immediately; this is the cheap exit for most leaves).
        var becalming: [Action] = []
        if state.poolRemaining > 0,
            CanoeID.allCanoeIDs.contains(where: {
                guard let canoe = state.canoes[$0],
                    canoe.owner == state.toMove.opponent,
                    case .sea = canoe.location
                else { return false }
                return true
            })
        {
            becalming = becalmingPlacements(in: state)
        }
        if becalming.isEmpty { return standPat }

        var alpha = alpha
        var best = standPat
        for action in AlphaBeta.Search.order(becalming, best: nil, history: history) {
            let next = AlphaBeta.Search.apply(action, to: state)
            let value = -score(
                next, alpha: -beta, beta: -alpha, table: table,
                history: &history, depth: depth - 1)
            if value > best { best = value }
            if value > alpha { alpha = value }
            if alpha >= beta {
                history.bump(action)
                break
            }
        }
        return best
    }

    /// Every legal island placement in `state` that becalms at least
    /// one rival canoe on the sea (the placement's field update drops
    /// some sea cell beside a rival canoe to `Balance.becalmedStrength`
    /// or below). Illegal placements are skipped; the list is in
    /// legalActions' stable order. At most `maxProbes` placements are
    /// applied (ADR-0020's quiescence cap — each probe is a field
    /// re-trace).
    static let maxProbes = 6
    ///
    /// Candidates are pre-filtered by distance before any field work:
    /// an island's field shadow (the cells whose strength can change)
    /// is within one step of the placed cell plus the swells whose
    /// rays pass near it, and a rival canoe becalms only where it
    /// STANDS — so only placements within one step of a rival sea
    /// canoe's cell can calm that canoe's own cell. This trims the
    /// ~150 raw candidates to a handful of applies per leaf.
    static func becalmingPlacements(in state: GameState) -> [Action] {
        guard state.poolRemaining > 0, !state.status.isOver else { return [] }
        var result: [Action] = []
        let mover = state.toMove
        let rivalCells = CanoeID.allCanoeIDs.compactMap { id -> Hex? in
            guard let canoe = state.canoes[id], canoe.owner == mover.opponent,
                case .sea(let at) = canoe.location
            else { return nil }
            return at
        }
        // The shadow set: every cell whose placement can calm a rival
        // canoe's own cell is within one step of that canoe. Walk each
        // rival's ring once (7 cells per canoe) and intersect it with
        // legality — no per-candidate scan of ~170 ocean cells, no
        // neighbor-list rebuilds per cell. Each surviving candidate
        // costs a full placement apply (a field re-trace), so the list
        // is capped (ADR-0020): the first `maxProbes` legal candidates
        // in row-major order are applied, the rest skipped. The cap is
        // deterministic (stable iteration order), and a becalm that
        // matters is almost always one of the nearest cells to a
        // rival canoe.
        var shadows: Set<Hex> = []
        for at in rivalCells {
            shadows.insert(at)
            for n in at.neighbors() { shadows.insert(n) }
        }
        var probes = 0
        for cell in state.placeableCandidates() where shadows.contains(cell) {
            guard probes < maxProbes else { break }
            guard Island.placementReason(cell, in: state) == nil else { continue }
            probes += 1
            var next = state
            do {
                next = try Reducer.apply(.placeIsland(cell), to: state).state
            } catch {
                continue
            }
            let becalmsRival = rivalCells.contains { at in
                next.field.strength(at: at) <= Balance.becalmedStrength
                    && state.field.strength(at: at) > Balance.becalmedStrength
            }
            if becalmsRival { result.append(.placeIsland(cell)) }
        }
        return result
    }
}
