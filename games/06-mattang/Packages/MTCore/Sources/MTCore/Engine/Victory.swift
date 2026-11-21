// Victory.swift — R-11 end of game: outright wins, the tie-break, and
// the §7 path-distance metric that decides it.

public enum Victory {
    /// R-11: a player who has landed `Balance.canoesToWin` canoes has
    /// won. Checked after every action, before the stuck and repetition
    /// rules (the reducer applies the precedence).
    public static func check(_ state: GameState) -> GameStatus {
        for player in [PlayerID.p1, PlayerID.p2] {
            if (state.landed[player] ?? 0) >= Balance.canoesToWin {
                return .won(player)
            }
        }
        return .ongoing
    }

    /// R-11 tie-break, in the roadmap's order (ADR-0010): more landed
    /// canoes wins; with equal landed counts, the §7 path-distance
    /// metric decides — the sum of the path distances of each player's
    /// best (closest) min(3, remaining) canoes to the rival atoll; the
    /// smaller sum wins; equal sums end with Player 2, the mover of the
    /// ply after the deciding event.
    public static func tiebreakWinner(_ state: GameState) -> PlayerID {
        let landed1 = state.landed[.p1] ?? 0
        let landed2 = state.landed[.p2] ?? 0
        if landed1 > landed2 { return .p1 }
        if landed2 > landed1 { return .p2 }
        let sum1 = pathDistanceSum(state, .p1)
        let sum2 = pathDistanceSum(state, .p2)
        if sum1 < sum2 { return .p1 }
        if sum2 < sum1 { return .p2 }
        return .p2
    }

    /// The §7/A.5 path-distance sum for one player (ADR-0010): the
    /// per-canoe distances sorted ascending, best min(3, count) summed.
    /// Canoes with no route are excluded; a side with no reachable
    /// canoe scores `unreachableDistance`.
    public static func pathDistanceSum(_ state: GameState, _ player: PlayerID) -> Int {
        let distances = canoeDistances(state, player)
        let best = distances.prefix(3)
        guard !best.isEmpty else { return unreachableDistance }
        return best.reduce(0, +)
    }

    /// Path distances of one player's remaining canoes to the rival
    /// atoll, ascending. A distance is the number of steps in the §7
    /// model: over strength ≥ 1 sea cells, node→node steps free, canoe
    /// collisions ignored; entering a rival atoll cell is the final
    /// step (cost 1); a home canoe's path starts with its launch step.
    /// Becalmed canoes have no route (at a tie-break nobody can tow —
    /// R-9); a home canoe whose atoll has no sailable neighbour has no
    /// route. Deterministic: fixed neighbour order, fixed deque
    /// discipline (INV-4).
    public static func canoeDistances(_ state: GameState, _ player: PlayerID) -> [Int] {
        let ocean = state.chart.ocean
        let atollCells = state.chart.atollCells
        let islands = state.islands
        let field = state.field
        let rivalCells = Set(state.chart.atoll(for: player.opponent).cells)

        func sailable(_ cell: Hex) -> Bool {
            ocean.contains(cell) && !atollCells.contains(cell) && !islands.contains(cell)
                && field.strength(at: cell) > Balance.becalmedStrength
        }

        // Reverse 0-1 BFS from the rival atoll: dist[cell] = fewest
        // steps for a canoe standing on `cell` to enter a rival atoll
        // cell. Seeded at 1 for sailable cells adjacent to the atoll —
        // the entry step itself, and atoll cells are never nodes.
        var dist: [Hex: Int] = [:]
        var deque = Deque<(Hex, Int)>()
        func relax(_ cell: Hex, _ distance: Int) {
            guard distance < (dist[cell] ?? Int.max) else { return }
            dist[cell] = distance
            if distance == 0 {
                deque.pushFront((cell, distance))
            } else {
                deque.pushBack((cell, distance))
            }
        }
        for cell in rivalCells {
            for neighbor in cell.neighbors() where sailable(neighbor) {
                relax(neighbor, 1)
            }
        }
        while let (cell, distance) = deque.popFront() {
            guard dist[cell] == distance else { continue }
            for neighbor in cell.neighbors() where sailable(neighbor) {
                let freeHop = field.isNode(cell) && field.isNode(neighbor)
                relax(neighbor, distance + (freeHop ? 0 : 1))
            }
        }

        var result: [Int] = []
        for id in CanoeID.allCanoeIDs where state.canoe(id).owner == player {
            let canoe = state.canoe(id)
            switch canoe.location {
            case .sea(let cell):
                if !canoe.becalmed, let d = dist[cell] {
                    result.append(d)
                }
            case .home:
                var best: Int?
                for cell in state.chart.atoll(for: player).cells {
                    for neighbor in cell.neighbors() where sailable(neighbor) {
                        if let d = dist[neighbor] {
                            best = min(best ?? Int.max, d + 1)
                        }
                    }
                }
                if let d = best { result.append(d) }
            case .landed:
                break
            }
        }
        result.sort()
        return result
    }

    /// The score of a side with no reachable canoe (ADR-0010).
    public static let unreachableDistance = 10_000
}

/// A minimal deque for 0-1 BFS: push-front for zero-weight
/// relaxations, push-back for unit weights, pop-front always. `head`
/// stores the front in reverse so both ends are O(1) appends.
struct Deque<Element> {
    private var head: [Element] = []
    private var tail: [Element] = []

    var isEmpty: Bool { head.isEmpty && tail.isEmpty }

    mutating func pushFront(_ element: Element) {
        head.append(element)
    }

    mutating func pushBack(_ element: Element) {
        tail.append(element)
    }

    mutating func popFront() -> Element? {
        if let element = head.popLast() {
            return element
        }
        return tail.isEmpty ? nil : tail.removeFirst()
    }
}
