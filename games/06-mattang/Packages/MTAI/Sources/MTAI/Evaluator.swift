// Evaluator.swift — §7/A.5's positional evaluation for Mattang.
//
// A.5: a side's evaluation is 100·landed, plus Σ over its best three
// canoes of (30 − distance), minus 8 per becalmed canoe, where
// distance is PathDistance's turn metric to the rival atoll. A canoe
// still at home pays 1 for its launch and starts from its best launch
// cell (a launch needs a strength ≥ 1 sea cell beside the home atoll,
// R-17); a becalmed canoe cannot advance, so it is excluded from the
// distance sum and penalised directly. The score for a player is the
// difference between the two sides' terms.
//
// One reverse BFS per evaluation supplies every cell's distance
// (PathDistance.distanceMap); the per-side pass is lookups only.

import MTCore

public enum Evaluator {
    /// A.5's evaluation, from `player`'s point of view: each side is
    /// measured against its OWN rival's atoll, so the two sides need
    /// two distance maps.
    public static func score(state: GameState, for player: PlayerID) -> Int {
        let ownMap = PathDistance.distanceMap(
            to: state.chart.atoll(for: player.opponent).cells, in: state)
        let rivalMap = PathDistance.distanceMap(
            to: state.chart.atoll(for: player).cells, in: state)
        return side(state: state, player: player, distances: ownMap)
            - side(state: state, player: player.opponent, distances: rivalMap)
    }

    /// One side's terms: landed × 100, plus the best-three distance
    /// credit, minus 8 per becalmed canoe.
    static func side(state: GameState, player: PlayerID) -> Int {
        side(
            state: state, player: player,
            distances: PathDistance.distanceMap(
                to: state.chart.atoll(for: player.opponent).cells, in: state))
    }

    /// The side's terms against a precomputed distance map.
    static func side(state: GameState, player: PlayerID, distances: [Hex: Int]) -> Int {
        var credits: [Int] = []
        var becalmedCount = 0
        var homeCredit: Int?

        for id in CanoeID.allCanoeIDs {
            let canoe = state.canoe(id)
            guard canoe.owner == player else { continue }
            switch canoe.location {
            case .landed:
                break  // already counted by landed × 100
            case .sea(let cell):
                if canoe.becalmed {
                    becalmedCount += 1
                } else if let distance = distances[cell] {
                    credits.append(30 - distance)
                }
            case .home:
                // Every home canoe shares the best launch cell: R-17
                // launches the lowest-numbered canoe first, but any of
                // them may launch on a later turn, so the metric is
                // the same for all of them.
                if homeCredit == nil {
                    homeCredit = launchCredit(state: state, player: player, distances: distances)
                }
                if let credit = homeCredit {
                    credits.append(credit)
                }
            }
        }

        let best3 = credits.sorted(by: >).prefix(3).reduce(0) { $0 + $1 }
        let landedScore = 100 * (state.landed[player] ?? 0)
        return landedScore + best3 - 8 * becalmedCount
    }

    /// The credit a home canoe faces: 30 − (1 + the best launch cell's
    /// distance). Nil when no legal launch cell exists (R-17) or none
    /// reaches the rival atoll.
    static func launchCredit(
        state: GameState, player: PlayerID, distances: [Hex: Int]
    ) -> Int? {
        var best: Int?
        for atollCell in state.chart.atoll(for: player).cells {
            for neighbor in atollCell.neighbors() {
                guard state.chart.ocean.contains(neighbor),
                    !state.islands.contains(neighbor),
                    !state.chart.atollCells.contains(neighbor),
                    state.canoe(at: neighbor) == nil,
                    state.field.strength(at: neighbor) > Balance.becalmedStrength
                else { continue }
                guard let distance = distances[neighbor] else { continue }
                let credit = 30 - (distance + 1)
                if let current = best, credit <= current { continue }
                best = credit
            }
        }
        return best
    }
}
