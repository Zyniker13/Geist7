// Island.swift — R-7 island placement legality and the R-21
// enclosure rule.

public enum Island {
    /// R-7: why a player may not place an island on `cell`, or nil when
    /// the placement is legal (the pool check lives in the reducer).
    /// Order of checks matches the rule list.
    public static func placementReason(_ cell: Hex, in state: GameState) -> IllegalReason? {
        guard state.chart.ocean.contains(cell) else { return .cellNotInOcean(cell) }
        guard !state.islands.contains(cell), !state.chart.atollCells.contains(cell) else {
            return .cellOccupied(cell)
        }
        guard state.canoe(at: cell) == nil else { return .cellHasCanoe(cell) }
        for neighbor in cell.neighbors() {
            if state.islands.contains(neighbor) { return .adjacentToIsland(neighbor) }
            if state.chart.atollCells.contains(neighbor) { return .adjacentToAtoll(neighbor) }
        }
        if let enclosed = fullyEnclosesAnyCanoe(cell, in: state) {
            return .fullyEncloses(enclosed)
        }
        return nil
    }

    /// R-21 (ADR-0008): the first canoe (stable CanoeID order) that
    /// placing an island on `cell` would leave without any adjacent
    /// enterable cell — "no adjacent cell at all (fully enclosed)" —
    /// or nil.
    ///
    /// A cell is enterable when it is in the ocean, not an island or
    /// atoll cell, not the new island, and not held by another canoe
    /// (R-20). A cell of strength 0 still counts: a becalmed canoe can
    /// be towed onto any adjacent empty cell (R-19). Only canoes
    /// adjacent to the new island — and atolls the placement touches —
    /// can be newly enclosed, so the check is local.
    public static func fullyEnclosesAnyCanoe(_ cell: Hex, in state: GameState) -> CanoeID? {
        let blocked = state.islands.union(state.chart.atollCells).union([cell])
        for id in CanoeID.allCanoeIDs {
            let canoe = state.canoe(id)
            switch canoe.location {
            case .sea(let at):
                guard at.isAdjacent(to: cell) else { continue }
                let hasEscape = at.neighbors().contains { neighbor in
                    state.chart.ocean.contains(neighbor)
                        && !blocked.contains(neighbor)
                        && state.canoe(at: neighbor) == nil
                }
                if !hasEscape { return id }
            case .home:
                let home = state.chart.atoll(for: canoe.owner)
                // Only a placement touching the atoll's launch
                // neighbourhood can seal every launch cell.
                let touches = home.cells.contains { atollCell in
                    atollCell.isAdjacent(to: cell)
                }
                guard touches else { continue }
                let hasLaunch = home.cells.contains { atollCell in
                    atollCell.neighbors().contains { neighbor in
                        state.chart.ocean.contains(neighbor)
                            && !blocked.contains(neighbor)
                            && state.canoe(at: neighbor) == nil
                    }
                }
                if !hasLaunch { return id }
            case .landed:
                continue
            }
        }
        return nil
    }
}
