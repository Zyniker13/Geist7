// Zobrist.swift — stable-order hashing of GameState.
//
// Every part of GameState is hashed in a fixed order (canoes in
// CanoeID.allCanoeIDs order, islands and cells in row-major Hex
// order), so two structurally identical states hash identically in
// every process and on every platform. The tables are generated once
// from SeededRNG with a fixed seed, so they are identical in every
// build. The hash keys R-23 repetition detection (ADR-0013) and is
// available to the AI and tests; replay determinism (INV-4) does not
// rest on it — a replay is seed + recorded actions alone.

public enum Zobrist {
    /// Fixed seed for the hash tables; any fixed odd value works.
    private static let tableSeed: UInt64 = 0x4D41_5454_414E_47A5

    /// Largest radius the tables cover (ocean cells = 3r² + 3r + 1).
    private static let maxCells = 512

    private static let table = Table(seed: tableSeed)

    /// A stable hash of the state (ADR-0013). Structural equality
    /// implies equal hashes; no two distinct reachable states of the
    /// same chart should collide in practice.
    public static func hash(of state: GameState) -> UInt64 {
        let cells = state.chart.ocean.allCells
        precondition(cells.count <= maxCells, "chart larger than the hash tables")
        var indexOfCell: [Hex: Int] = [:]
        for (index, cell) in cells.enumerated() { indexOfCell[cell] = index }

        var hash: UInt64 = 0
        for cell in state.islands.sorted(by: Hex.rowMajor) {
            guard let index = indexOfCell[cell] else {
                preconditionFailure("island cell \(cell) is outside the chart")
            }
            hash ^= table.island[index]
        }
        for id in CanoeID.allCanoeIDs {
            let index = id.player.rawValue == "p1" ? id.index : Balance.canoesPerPlayer + id.index
            switch state.canoe(id).location {
            case .home:
                hash ^= table.homeCanoe[index]
            case .sea(let cell):
                guard let seaIndex = indexOfCell[cell] else {
                    preconditionFailure("canoe cell \(cell) is outside the chart")
                }
                hash ^= table.seaCanoe[index][seaIndex]
            case .landed:
                hash ^= table.landedCanoe[index]
            }
        }
        hash ^= state.toMove == .p1 ? table.toMoveP1 : table.toMoveP2
        hash ^= table.pool[state.poolRemaining]
        hash ^= table.stuckTurns[min(state.stuckTurns, table.stuckTurns.count - 1)]
        return hash
    }

    /// The position key R-23 counts (ADR-0013): the state hash.
    /// `GameState.visited` maps each key to its occurrence count; a
    /// key reaching `Balance.repetitionLimit` ends the game by the
    /// R-11 tie-break.
    public static func positionKey(of state: GameState) -> UInt64 {
        hash(of: state)
    }

    private struct Table {
        let island: [UInt64]
        let seaCanoe: [[UInt64]]
        let homeCanoe: [UInt64]
        let landedCanoe: [UInt64]
        let toMoveP1: UInt64
        let toMoveP2: UInt64
        let pool: [UInt64]
        let stuckTurns: [UInt64]

        init(seed: UInt64) {
            var rng = SeededRNG(seed: seed)
            func vector(_ count: Int) -> [UInt64] {
                (0..<count).map { _ in rng.nextUInt64() }
            }
            island = vector(maxCells)
            var sea: [[UInt64]] = []
            for _ in 0..<(2 * Balance.canoesPerPlayer) {
                sea.append(vector(maxCells))
            }
            seaCanoe = sea
            homeCanoe = vector(2 * Balance.canoesPerPlayer)
            landedCanoe = vector(2 * Balance.canoesPerPlayer)
            toMoveP1 = rng.nextUInt64()
            toMoveP2 = rng.nextUInt64()
            pool = vector(Balance.islandPool + 1)
            stuckTurns = vector(8)
        }
    }
}
