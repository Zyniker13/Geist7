// Legality.swift — every static legality predicate in one home, shared
// by the reducer and LegalMoves so the two cannot disagree (INV-10's
// foundation).
//
// Placement: R-4 (empty, non-feature, no same-size adjacency) and
// R-20 (not raked, not adjacent to a basin). Rakes: R-5 (2–5 empty
// non-feature cells from an anchor), R-21 (single-cell crossings),
// R-22 (no passing through stones/features/walls). Laws: R-7, R-8.

public enum Legality {

    // MARK: Placement (R-4, R-20)

    /// R-4: the cell must be empty, on the courtyard, not a feature,
    /// and not adjacent to a same-player stone of the same size.
    /// `context` caches the stone-by-cell and raked-by lookups; the
    /// reducer passes nil (it judges one action).
    public static func placementCellErrors(
        _ cell: Hex, size: StoneSize, player: PlayerID,
        courtyard: Courtyard, state: GameState,
        context: LegalMoves.Context? = nil
    ) -> [IllegalReason] {
        var reasons: [IllegalReason] = []
        guard courtyard.cellSet.contains(cell) else {
            return [.offCourtyard]
        }
        let ctx = context ?? LegalMoves.Context(
            state: state, courtyard: courtyard)
        if courtyard.isFeature(cell) {
            reasons.append(.feature)
        }
        if ctx.stone(at: cell) != nil {
            reasons.append(.occupied)
        }
        if ctx.rakedBy[cell] != nil {
            reasons.append(.raked)
        }
        // R-4: adjacent same-player same-size stones are forbidden.
        for d in 0..<6 {
            if let stone = ctx.stone(at: cell.neighbor(d)),
                stone.owner == player, stone.size == size {
                reasons.append(.sameSizeAdjacent)
            }
        }
        // R-20: not adjacent to a basin.
        if !basinAdjacentAllowed(courtyard) {
            for d in 0..<6 {
                let neighbor = cell.neighbor(d)
                if let feature = courtyard.features
                    .first(where: { $0.cell == neighbor }),
                    feature.kind == "basin" {
                    reasons.append(.basinAdjacent)
                }
            }
        }
        return reasons
    }

    /// R-20's `basinAdjacentAllowed` flag: content-level, default false
    /// at P1 (no content file loads it yet; the default courtyard does
    /// not set it).
    public static func basinAdjacentAllowed(_ courtyard: Courtyard) -> Bool {
        false
    }

    /// R-4 + laws: the full check the reducer applies before committing
    /// a placement. Returns the FIRST failing reason (the reducer's
    /// explanation contract) or nil when legal.
    public static func placementError(
        _ cell: Hex, size: StoneSize, facing: Int, player: PlayerID,
        courtyard: Courtyard, state: GameState, balance: Balance,
        context: LegalMoves.Context? = nil
    ) -> IllegalReason? {
        guard (0..<6).contains(facing) else { return .offCourtyard }
        let cellErrors = placementCellErrors(
            cell, size: size, player: player, courtyard: courtyard,
            state: state, context: context)
        if let first = cellErrors.first {
            return first
        }
        // Supplies (R-2, INV-3): the bin must hold a stone.
        guard state.supplies[player]?.has(size) == true else {
            return .noSupply
        }
        // The garden laws judge the AFTER position (R-7, R-8).
        var trial = state.stones
        let newStone = Stone(owner: player, cell: cell, size: size, facing: facing)
        trial.append(newStone)
        if SymmetryLaw.violated(
            stones: trial, courtyard: courtyard, balance: balance) {
            return .symmetry
        }
        // R-8 incrementally: only triples through the new stone can be
        // new (existing triples already failed the earlier action that
        // completed them, INV-1). The full sweep stays available for
        // the audit tests.
        if CollinearLaw.violated(trial, newStone: newStone) {
            return .collinear
        }
        return nil
    }

    // MARK: Rakes (R-5, R-21, R-22)

    /// R-5: the cells a rake of `length` would cover from `start` in
    /// `direction`, or nil when the run leaves the courtyard.
    public static func rakePath(
        start: Hex, direction: Int, length: Int, courtyard: Courtyard
    ) -> [Hex]? {
        guard length >= 2, length <= 5 else { return nil }  // R-5: 2–5
        var cells: [Hex] = []
        cells.reserveCapacity(length)
        var probe = start
        let inSet = courtyard.cellSet
        for _ in 0..<length {
            probe = probe.neighbor(direction)
            guard inSet.contains(probe) else { return nil }
            cells.append(probe)
        }
        return cells
    }

    /// R-5's anchor: rake starts adjacent to one of the mover's stones.
    /// `courtyard` is unused here but keeps the call shape stable; the
    /// context's stone map is all this reads.
    public static func rakeAnchor(
        for rakeCells: [Hex], player: PlayerID, state: GameState,
        context: LegalMoves.Context
    ) -> Hex? {
        let first = rakeCells.first!
        for d in 0..<6 {
            if let stone = context.stone(at: first.neighbor(d)),
                stone.owner == player {
                return stone.cell
            }
        }
        return nil
    }

    /// Rake legality (R-5, R-21, R-22). Returns the first failing
    /// reason or nil when legal. `context` caches the stone and rake
    /// lookups (the reducer passes nil; the generators pass theirs).
    public static func rakeError(
        start: Hex, direction: Int, length: Int, player: PlayerID,
        courtyard: Courtyard, state: GameState, balance: Balance,
        context: LegalMoves.Context? = nil
    ) -> IllegalReason? {
        guard let cells = rakePath(
            start: start, direction: direction, length: length,
            courtyard: courtyard) else {
            // Distinguish a bad length from a run off the yard.
            return (2...balance.rakeMaxLength).contains(length)
                ? .offCourtyard : .rakeBadLength
        }
        let ctx = context ?? LegalMoves.Context(
            state: state, courtyard: courtyard)
        // R-22: the path may not pass through stones or features. The
        // path is only length ≤ 5, so a linear scan is cheapest.
        for cell in cells {
            if ctx.stone(at: cell) != nil {
                return .rakeBlocked
            }
            if courtyard.isFeature(cell) {
                return .rakeBlocked
            }
        }
        // R-5: a raked cell cannot be raked again — except that two
        // rake lines may cross at exactly ONE shared cell (R-21; the
        // crossing cell carries both rakes' bonuses and belongs to
        // neither rake for future crossings). INV-9: no two rakes
        // overlap in more than one cell, opponent or own.
        var overlaps = 0
        for cell in cells where ctx.rakedBy[cell] != nil {
            overlaps += 1
            if overlaps > 1 {
                return .rakeCrossing
            }
        }
        // R-5: the first cell must sit adjacent to a mover's stone.
        guard rakeAnchor(
            for: cells, player: player, state: state, context: ctx) != nil
        else {
            return .rakeNoAnchor
        }
        // R-2: rake lines are limited per player.
        guard (state.rakesUsed[player] ?? 0) < balance.rakesPerPlayer else {
            return .noSupply
        }
        return nil
    }

    // MARK: Pass (R-6, R-27)

    /// R-6/R-27: pass is legal only when the mover has NO legal
    /// placement AND no rakes left. This consults the same generators
    /// `LegalMoves.all` uses (placements and rakes, not the `.all`
    /// aggregation, which would see the pass itself as a move).
    public static func passError(
        player: PlayerID, courtyard: Courtyard, state: GameState,
        balance: Balance
    ) -> IllegalReason? {
        if state.isOver { return .gameOver }
        let hasPlacementMove = !LegalMoves.placements(
            for: player, courtyard: courtyard, state: state,
            balance: balance).isEmpty
        let hasRakeMove = !LegalMoves.rakes(
            for: player, courtyard: courtyard, state: state,
            balance: balance).isEmpty
        if hasPlacementMove || hasRakeMove {
            return .mustMove
        }
        return nil
    }
}
