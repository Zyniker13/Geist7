// PathDistance.swift — the turn-metric path distance over the field.
//
// §7/A.5 evaluates positions by "shortest-path distances (over
// strength ≥ 1 cells, node chains free)" to the rival atoll: how many
// sail actions a canoe would need, where stepping node to node costs
// nothing because a node chain rides free of range (R-8) and a canoe
// standing on a node may leave it in any direction on a later turn.
// The metric is positional: it ranks terrain, abstracting away the
// single-action path shape (Movement owns that) and the transient
// positions of canoes; islands and atolls are the permanent walls.

import MTCore

public enum PathDistance {
    /// The distance-to-`targets` map for every reachable sea cell: the
    /// reverse 0–1 BFS seeded at the targets. `distance(from:to:in:)`
    /// reads a single cell out of this map. Evaluators use the whole
    /// map (one pass instead of one per canoe).
    public static func distanceMap(to targets: Set<Hex>, in state: GameState) -> [Hex: Int] {
        precondition(!targets.isEmpty, "distance needs at least one target cell")
        let ocean = state.chart.ocean
        let field = state.field

        var best: [Hex: Int] = [:]
        for target in targets { best[target] = 0 }
        // 0–1 BFS from the targets over reversed edges; edge costs are
        // symmetric (node-to-node), so the reversed pass matches the
        // forward one.
        var deque: [(cell: Hex, cost: Int)] = targets.map { ($0, 0) }
        var head = 0

        while head < deque.count {
            let entry = deque[head]
            head += 1
            let cell = entry.cell
            let cost = entry.cost
            if let seen = best[cell], seen < cost { continue }

            for next in cell.neighbors() {
                guard ocean.contains(next), !state.islands.contains(next) else { continue }
                if state.chart.atollCells.contains(next), !targets.contains(next) { continue }
                guard field.strength(at: next) > Balance.becalmedStrength
                    || targets.contains(next)
                else { continue }
                let stepCost = field.isNode(cell) && field.isNode(next) ? 0 : 1
                let newCost = cost + stepCost
                if newCost < (best[next] ?? Int.max) {
                    best[next] = newCost
                    if stepCost == 0 {
                        deque.insert((next, newCost), at: head)
                    } else {
                        deque.append((next, newCost))
                    }
                }
            }
        }
        return best
    }

    /// Cheapest cost of a path from `start` that enters some cell of
    /// `targets` (R-10's landing step included). Adjacent ocean cells
    /// are joined node-to-node at cost 0 and otherwise at cost 1;
    /// islands, atoll cells outside `targets`, and calm cells block.
    /// Nil when no target is reachable.
    public static func distance(
        from start: Hex,
        to targets: Set<Hex>,
        in state: GameState
    ) -> Int? {
        distanceMap(to: targets, in: state)[start]
    }
}
