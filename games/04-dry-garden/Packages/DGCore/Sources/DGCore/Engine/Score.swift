// Score.swift — ownership, groups, and game scoring (R-11, R-13, R-14,
// R-24, R-26, INV-8).
//
// Ownership comes from the influence tallies (R-11). Groups connect
// same-owner stones within hex distance 2 (R-26) and are computed at
// game end; odd-sized groups score `groupBonus[size]` (R-13). Score =
// owned cells + group bonuses (R-14), recomputable from the final
// state alone (INV-8).

public enum Score {

    /// Every courtyard cell's owner from influence tallies (R-11):
    /// strictly greater influence wins; ties are unowned (nil).
    public static func owners(
        courtyard: Courtyard, tallies: [Hex: InfluenceTally]
    ) -> [Hex: PlayerID] {
        var result: [Hex: PlayerID] = [:]
        for cell in courtyard.cells {
            if let tally = tallies[cell], let owner = tally.owner {
                result[cell] = owner
            }
        }
        return result
    }

    /// Owned-cell counts per player (R-14's first term; features count
    /// at weight 1, R-24).
    public static func ownedCellCounts(
        courtyard: Courtyard, tallies: [Hex: InfluenceTally]
    ) -> [PlayerID: Int] {
        var counts: [PlayerID: Int] = [.one: 0, .two: 0]
        for cell in courtyard.cells {
            guard let tally = tallies[cell], let owner = tally.owner else {
                continue
            }
            counts[owner, default: 0] += 1
        }
        return counts
    }

    /// R-13/R-26: groups of same-owner stones connected within hex
    /// distance 2. Computed at game end for scoring (R-13) and used
    /// mid-game by the AI's parity heuristic (A.5) — the math is the
    /// same, the game only scores at the end.
    public static func groups(of stones: [Stone]) -> [[Stone]] {
        var adjacency: [Hex: [Hex]] = [:]
        var byCell: [Hex: Stone] = [:]
        for stone in stones {
            byCell[stone.cell] = stone
        }
        for stone in stones {
            var neighbors: [Hex] = []
            for other in stones where other.cell != stone.cell {
                if stone.cell.distance(to: other.cell) <= 2 {
                    neighbors.append(other.cell)
                }
            }
            adjacency[stone.cell] = neighbors
        }
        var visited = Set<Hex>()
        var result: [[Stone]] = []
        for stone in stones {
            guard !visited.contains(stone.cell) else { continue }
            var component: [Stone] = []
            var queue = [stone.cell]
            visited.insert(stone.cell)
            while let cell = queue.popLast() {
                component.append(byCell[cell]!)
                for neighbor in adjacency[cell] ?? [] where !visited.contains(neighbor) {
                    visited.insert(neighbor)
                    queue.append(neighbor)
                }
            }
            result.append(component)
        }
        return result
    }

    /// R-13: the group bonus sum for one player's stones.
    public static func groupBonuses(
        for stones: [Stone], balance: Balance
    ) -> Int {
        var total = 0
        for group in groups(of: stones) where group.count % 2 == 1 {
            total += balance.groupBonusFor(size: group.count)
        }
        return total
    }

    /// R-14/R-15: final scores from a finished state. Score = owned
    /// cells + group bonuses. Ties go to Player 2 (R-15).
    public static func finalScores(
        courtyard: Courtyard, state: GameState, balance: Balance
    ) -> [PlayerID: Int] {
        let tallies = InfluenceEngine.computeAll(
            courtyard: courtyard, stones: state.stones,
            rakes: state.rakes, balance: balance)
        let owned = ownedCellCounts(courtyard: courtyard, tallies: tallies)
        var result: [PlayerID: Int] = [:]
        for player in PlayerID.allCases {
            result[player] = (owned[player] ?? 0)
                + groupBonuses(for: state.stones(of: player), balance: balance)
        }
        return result
    }

    /// R-15: the winner from final scores. A tie goes to Player 2
    /// (R-15), so this never returns nil for a real scored game.
    public static func winner(from scores: [PlayerID: Int]) -> PlayerID? {
        let one = scores[.one] ?? 0
        let two = scores[.two] ?? 0
        if one > two { return .one }
        return .two  // tie → Player 2 (R-15)
    }
}
