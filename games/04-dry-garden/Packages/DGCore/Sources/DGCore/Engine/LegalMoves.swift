// LegalMoves.swift — the legal-move generator (S1.1; INV-10's source).
//
// Every move returned here passes the reducer's legality checks (the
// shared predicates in `Legality` guarantee it). R-27: pass appears
// only when nothing else is legal.

public enum LegalMoves {

    /// All legal actions for the player to move.
    public static func all(
        for player: PlayerID, courtyard: Courtyard, state: GameState,
        balance: Balance
    ) -> [Action] {
        if state.isOver { return [] }
        guard state.toMove == player else { return [] }
        // Cache the derived lookups once per call: the placement and
        // rake generators consult them per candidate.
        let context = Context(state: state, courtyard: courtyard)
        var moves: [Action] = []
        moves.append(contentsOf: placements(
            for: player, courtyard: courtyard, state: state,
            balance: balance, context: context))
        moves.append(contentsOf: rakes(
            for: player, courtyard: courtyard, state: state,
            balance: balance, context: context))
        if moves.isEmpty {
            moves.append(.pass)
        }
        return moves
    }

    /// Derived per-call lookups shared by the generators: the
    /// stone-by-cell map and the raked-cell owner map. Rebuilt once
    /// per `LegalMoves.all`/`passError` call instead of per candidate.
    public struct Context: Sendable {
        public let stoneAt: [Hex: Stone]
        public let rakedBy: [Hex: PlayerID]
        public let occupied: Set<Hex>

        public init(state: GameState, courtyard: Courtyard) {
            var map: [Hex: Stone] = [:]
            for stone in state.stones {
                map[stone.cell] = stone
            }
            self.stoneAt = map
            self.occupied = Set(map.keys)
            var raked: [Hex: PlayerID] = [:]
            for rake in state.rakes {
                for cell in rake.cells where raked[cell] == nil {
                    raked[cell] = rake.owner
                }
            }
            self.rakedBy = raked
        }

        public func stone(at cell: Hex) -> Stone? {
            stoneAt[cell]
        }
    }

    /// Every legal placement (R-4, R-20, R-7, R-8): empty placeable
    /// cells × remaining sizes × 6 facings.
    public static func placements(
        for player: PlayerID, courtyard: Courtyard, state: GameState,
        balance: Balance, context: Context? = nil
    ) -> [Action] {
        let ctx = context ?? Context(state: state, courtyard: courtyard)
        var moves: [Action] = []
        let sizes: [StoneSize] = [.large, .medium, .small]
        let available = sizes.filter {
            state.supplies[player]?.has($0) == true
        }
        for cell in courtyard.placeableCells {
            if ctx.occupied.contains(cell) || courtyard.isFeature(cell) {
                continue
            }
            if ctx.rakedBy[cell] != nil {
                continue  // R-5: raked cells never receive stones
            }
            for size in available {
                if Legality.placementError(
                    cell, size: size, facing: 0, player: player,
                    courtyard: courtyard, state: state, balance: balance,
                    context: ctx) == nil {
                    moves.append(.place(cell: cell, size: size, facing: 0))
                }
            }
        }
        return moves
    }

    /// Every legal rake (R-5, R-21, R-22): anchors × 6 directions ×
    /// lengths 2–5 (A.5's generation shape).
    public static func rakes(
        for player: PlayerID, courtyard: Courtyard, state: GameState,
        balance: Balance, context: Context? = nil
    ) -> [Action] {
        var moves: [Action] = []
        guard (state.rakesUsed[player] ?? 0) < balance.rakesPerPlayer else {
            return moves
        }
        let ctx = context ?? Context(state: state, courtyard: courtyard)
        for stone in state.stones where stone.owner == player {
            for direction in 0..<6 {
                for length in 2...min(5, max(2, balance.rakeMaxLength)) {
                    if Legality.rakeError(
                        start: stone.cell, direction: direction,
                        length: length, player: player, courtyard: courtyard,
                        state: state, balance: balance,
                        context: ctx) == nil {
                        moves.append(
                            .rake(start: stone.cell, direction: direction, length: length))
                    }
                }
            }
        }
        return moves
    }
}
