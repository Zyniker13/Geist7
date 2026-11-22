// GameState.swift — the full rules-engine state of one Mattang game.
//
// GameState carries everything that changes during play (§5 of the
// roadmap): islands, the island pool, the eight canoes, landed counts,
// the side to move, the stuck counter, the swell field, the Zobrist
// position keys seen so far (R-23), and the game status. Charts
// (Chart) carry everything that does not.
//
// Codable is implemented by hand (ADR-0009) so that encoding is byte
// stable across processes and platforms — the foundation of INV-4
// stable hashing.

import Foundation

/// How a game ended (§5). `won` is the R-11 three-canoe victory,
/// `tiebreak` is the R-11 tie-break applied when the pool is empty and
/// both players are stuck.
public enum GameStatus: Hashable, Codable, Sendable {
    case ongoing
    case won(PlayerID)
    case tiebreak(PlayerID)

    public var winner: PlayerID? {
        switch self {
        case .ongoing: return nil
        case .won(let p): return p
        case .tiebreak(let p): return p
        }
    }

    public var isOver: Bool { self != .ongoing }
}

/// The complete state of one game (§5 GameState: chartId, islands,
/// poolRemaining, canoes, landed, toMove, stuckTurns, plus the field
/// and status the engine derives from them).
public struct GameState: Hashable, Sendable {
    public let chart: Chart
    /// All island cells: pre-placed plus placed during play.
    public var islands: Set<Hex>
    /// Islands left to place (§5 poolRemaining).
    public var poolRemaining: Int
    /// The eight canoes by id (§5 canoes).
    public var canoes: [CanoeID: CanoeState]
    /// Landed canoe counts per player (§5 landed).
    public var landed: [PlayerID: Int]
    /// Side to move (§5 toMove).
    public var toMove: PlayerID
    /// Consecutive passes, for the R-11 stuck rule (§5 stuckTurns).
    public var stuckTurns: Int
    /// Swell field over the board; derived from islands + chart and
    /// kept up to date incrementally by the reducer (INV-9).
    public var field: Field
    /// Victory / tie-break status.
    public var status: GameStatus
    /// Zobrist position keys seen so far, mapping each key to its
    /// occurrence count, including the current position's (§5; R-23,
    /// ADR-0013). The reducer updates it on every action; derivable
    /// from a replay, stored for O(1) R-23 checks.
    public var visited: [UInt64: Int]

    public init(
        chart: Chart, islands: Set<Hex>, poolRemaining: Int,
        canoes: [CanoeID: CanoeState], landed: [PlayerID: Int],
        toMove: PlayerID, stuckTurns: Int, field: Field, status: GameStatus,
        visited: [UInt64: Int] = [:]
    ) {
        self.chart = chart
        self.islands = islands
        self.poolRemaining = poolRemaining
        self.canoes = canoes
        self.landed = landed
        self.toMove = toMove
        self.stuckTurns = stuckTurns
        self.field = field
        self.status = status
        self.visited = visited
    }

    public var chartID: String { chart.id }

    public func canoe(_ id: CanoeID) -> CanoeState {
        guard let canoe = canoes[id] else {
            preconditionFailure("missing canoe \(id.name)")
        }
        return canoe
    }

    public func atoll(of player: PlayerID) -> Atoll { chart.atoll(for: player) }

    /// First sea canoe occupying `cell`, if any.
    public func canoe(at cell: Hex) -> CanoeID? {
        for id in CanoeID.allCanoeIDs where canoes[id]?.location == .sea(cell) {
            return id
        }
        return nil
    }

    /// A cell is occupied by an island, an atoll, or a canoe.
    public func isOccupied(_ cell: Hex) -> Bool {
        islands.contains(cell)
            || chart.atollCells.contains(cell)
            || canoe(at: cell) != nil
    }

    /// Cells where an island may be considered for placement, in
    /// row-major order: empty sea cells (R-7 filters further).
    ///
    /// Canoe occupancy is a dictionary probe, not an 8-way linear
    /// scan per cell — this runs inside every AI node and quiescence
    /// probe over ~170 cells.
    public func placeableCandidates() -> [Hex] {
        var occupied: Set<Hex> = []
        occupied.reserveCapacity(canoes.count)
        for (_, canoe) in canoes {
            if case .sea(let at) = canoe.location { occupied.insert(at) }
        }
        return chart.ocean.allCells.filter {
            !$0.islandCell(in: self) && !chart.atollCells.contains($0)
                && !occupied.contains($0)
        }
    }

    /// Sea canoes of a player, in stable id order.
    public func seaCanoeIDs(owner: PlayerID) -> [CanoeID] {
        CanoeID.allCanoeIDs.filter { canoe($0).owner == owner && canoe($0).location.isSea }
    }

    /// Canoes of a player still in their home atoll, in stable id order.
    public func homeCanoeIDs(owner: PlayerID) -> [CanoeID] {
        CanoeID.allCanoeIDs.filter { canoe($0).owner == owner && canoe($0).location == .home }
    }
}

// MARK: - CanoeID helpers

extension CanoeID {
    /// The eight canoes in a stable global order: player 1 indices
    /// 0..<4, then player 2. Deterministic everywhere.
    public static let allCanoeIDs: [CanoeID] = [
        CanoeID(player: .p1, index: 0), CanoeID(player: .p1, index: 1),
        CanoeID(player: .p1, index: 2), CanoeID(player: .p1, index: 3),
        CanoeID(player: .p2, index: 0), CanoeID(player: .p2, index: 1),
        CanoeID(player: .p2, index: 2), CanoeID(player: .p2, index: 3),
    ]

    /// Display name, e.g. "p1/0" (§5 canoe naming).
    public var name: String { "\(player.rawValue)/\(index)" }
}

// MARK: - Hex helpers used by the engine

extension Hex {
    /// Row-major order comparator (r ascending, then q ascending) —
    /// the canonical order every deterministic listing uses.
    public static func rowMajor(_ a: Hex, _ b: Hex) -> Bool {
        (a.r, a.q) < (b.r, b.q)
    }

    /// The six adjacent cells in fixed direction order 0–5 (R-12 order).
    public func neighbors() -> [Hex] {
        Self.directionVectors.map { self + $0 }
    }

    /// True when the two cells share an edge.
    public func isAdjacent(to other: Hex) -> Bool {
        distance(to: other) == 1
    }

    /// True when `self` holds an island in `state`.
    public func islandCell(in state: GameState) -> Bool {
        state.islands.contains(self)
    }
}

// MARK: - Stable Codable (ADR-0009)

extension GameState: Codable {
    private enum CodingKeys: String, CodingKey {
        case chart, islands, poolRemaining, canoes, landed, toMove, stuckTurns, field, status
        case visited
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(chart, forKey: .chart)
        // Islands in row-major order (deterministic; sets encode unordered).
        try c.encode(islands.sorted(by: Hex.rowMajor), forKey: .islands)
        try c.encode(poolRemaining, forKey: .poolRemaining)
        // Canoes as a sorted array of {id, state}.
        var canoeArray = ContiguousArray<CanoeRecord>()
        for id in CanoeID.allCanoeIDs {
            canoeArray.append(CanoeRecord(id: id, state: canoe(id)))
        }
        try c.encode(canoeArray, forKey: .canoes)
        // Landed as a fixed two-entry array in PlayerID.allCases order.
        try c.encode(
            landed.map { LandedRecord(player: $0.key, count: $0.value) }
                .sorted { $0.player.rawValue < $1.player.rawValue },
            forKey: .landed)
        try c.encode(toMove, forKey: .toMove)
        try c.encode(stuckTurns, forKey: .stuckTurns)
        try c.encode(field, forKey: .field)
        try c.encode(status, forKey: .status)
        // Keys sorted, with repeats, for byte-stable encoding.
        var keys: [UInt64] = []
        for (key, count) in visited.sorted(by: { $0.key < $1.key }) {
            keys.append(contentsOf: repeatElement(key, count: count))
        }
        try c.encode(keys, forKey: .visited)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        chart = try c.decode(Chart.self, forKey: .chart)
        let islandList = try c.decode([Hex].self, forKey: .islands)
        islands = Set(islandList)
        poolRemaining = try c.decode(Int.self, forKey: .poolRemaining)
        let canoeArray = try c.decode([CanoeRecord].self, forKey: .canoes)
        canoes = Dictionary(
            canoeArray.map { ($0.id, $0.state) },
            uniquingKeysWith: { _, _ in
                preconditionFailure("duplicate canoe id in encoded state")
            })
        let landedArray = try c.decode([LandedRecord].self, forKey: .landed)
        landed = Dictionary(
            landedArray.map { ($0.player, $0.count) },
            uniquingKeysWith: { _, _ in
                preconditionFailure("duplicate player in encoded landed record")
            })
        toMove = try c.decode(PlayerID.self, forKey: .toMove)
        stuckTurns = try c.decode(Int.self, forKey: .stuckTurns)
        field = try c.decode(Field.self, forKey: .field)
        status = try c.decode(GameStatus.self, forKey: .status)
        let visitedKeys = try c.decode([UInt64].self, forKey: .visited)
        var visitedCounts: [UInt64: Int] = [:]
        for key in visitedKeys { visitedCounts[key, default: 0] += 1 }
        visited = visitedCounts
    }
}

/// A canoe as encoded inside GameState (ADR-0009).
public struct CanoeRecord: Codable, Sendable {
    public let id: CanoeID
    public let state: CanoeState
    public init(id: CanoeID, state: CanoeState) {
        self.id = id
        self.state = state
    }
}

/// A landed count as encoded inside GameState (ADR-0009).
public struct LandedRecord: Codable, Sendable {
    public let player: PlayerID
    public let count: Int
    public init(player: PlayerID, count: Int) {
        self.player = player
        self.count = count
    }
}
