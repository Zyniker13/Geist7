// Chart.swift — a Mattang board plus its swell pattern.
//
// A chart owns the immutable geometry of a game: ocean radius, swell
// entries, pre-placed islands, home atolls, and the symmetry used by
// INV-6 (§5 ChartDef). Charts are immutable value types; everything
// that changes during play lives in GameState.

/// Chart symmetry (§5 ChartDef "symmetry"), exercised by INV-6.
/// - `none`: no symmetry requirement; the image map is the identity.
/// - `mirror`: reflection across the east–west axis through the board
///   centre: Hex(q, r) ↦ Hex(q + r, -r), edge side s ↦ (6 - s) mod 6.
/// - `rotate180`: half turn: Hex(q, r) ↦ Hex(-q, -r), side s ↦
///   (s + 3) mod 6.
public enum ChartSymmetry: String, Hashable, Codable, Sendable {
    case none
    case mirror
    case rotate180
}

public struct Chart: Hashable, Codable, Sendable {
    public let id: String
    public let radius: Int
    /// The swell pattern: at least one entry, distinct ids (§5).
    public let swells: [Swell]
    /// Islands pre-placed at chart start; they never move (§5).
    public let preIslands: Set<Hex>
    /// Home atolls; exactly two, first = player 1, second = player 2 (§5).
    public let atolls: [Atoll]
    public let symmetry: ChartSymmetry

    public init(
        id: String, radius: Int, swells: [Swell],
        preIslands: Set<Hex>, atolls: [Atoll], symmetry: ChartSymmetry
    ) {
        self.id = id
        self.radius = radius
        self.swells = swells
        self.preIslands = preIslands
        self.atolls = atolls
        self.symmetry = symmetry
    }

    public var ocean: Ocean { Ocean(radius: radius) }

    public var atollCells: Set<Hex> { Set(atolls.flatMap(\.cells)) }

    /// The home atoll of a player; charts always carry exactly one each.
    public func atoll(for player: PlayerID) -> Atoll {
        let match = atolls.filter { $0.player == player }
        precondition(match.count == 1, "chart \(id) must have exactly one atoll per player")
        return match[0]
    }

    /// INV-6: the symmetry image of a cell (identity for `none`).
    public func symmetryImage(of cell: Hex) -> Hex {
        switch symmetry {
        case .none:
            return cell
        case .mirror:
            return Hex(q: cell.q + cell.r, r: -cell.r)
        case .rotate180:
            return Hex(q: -cell.q, r: -cell.r)
        }
    }

    /// INV-6: the symmetry image of an edge side (identity for `none`).
    public func symmetryImage(of side: Int) -> Int {
        switch symmetry {
        case .none:
            return side
        case .mirror:
            return flooredMod(6 - side, 6)
        case .rotate180:
            return flooredMod(side + 3, 6)
        }
    }

    /// Structural validation of chart data (§5 ChartDef guard).
    /// Returns a list of problems; an empty list means the chart is
    /// well-formed enough to start a game.
    public func validate() -> [String] {
        var problems: [String] = []
        if radius < 2 { problems.append("radius must be at least 2") }
        if swells.isEmpty { problems.append("chart needs at least one swell") }
        if Set(swells.map(\.id)).count != swells.count {
            problems.append("swell ids must be distinct")
        }
        if atolls.count != 2 {
            problems.append("chart needs exactly two home atolls")
        }
        if Set(atolls.map(\.player)).count != atolls.count {
            problems.append("home atolls must belong to distinct players")
        }
        for atoll in atolls where !atoll.cells.allSatisfy(ocean.contains) {
            problems.append("atoll for \(atoll.player.rawValue) leaves the ocean")
        }
        for cell in preIslands where !ocean.contains(cell) {
            problems.append("pre-placed island \(cell) is outside the ocean")
        }
        let preoccupied = preIslands.intersection(atollCells)
        if !preoccupied.isEmpty {
            problems.append("pre-placed islands overlap an atoll: \(preoccupied)")
        }
        for atoll in atolls {
            // Every home atoll needs at least one launchable sea cell: an
            // adjacent ocean cell that is neither island nor atoll (R-17).
            let launchable = atoll.cells.flatMap { $0.neighbors() }.filter {
                ocean.contains($0) && !preIslands.contains($0) && !atollCells.contains($0)
            }
            if launchable.isEmpty {
                problems.append(
                    "atoll for \(atoll.player.rawValue) has no launchable sea cell")
            }
        }
        return problems
    }
}

// MARK: - Stable Codable (ADR-0009)
//
// Hand-written so that equal charts encode to identical bytes: the
// synthesized conformance would serialize `preIslands` and the atoll
// cell sets in hash order, which differs between processes.

extension Chart {
    private enum CodingKeys: String, CodingKey {
        case id, radius, swells, preIslands, atolls, symmetry
    }

    private struct AtollRecord: Codable {
        let player: String
        let cells: [[Int]]

        init(player: PlayerID, cells: Set<Hex>) {
            self.player = player.rawValue
            self.cells = cells.sorted(by: Hex.rowMajor).map { [$0.q, $0.r] }
        }

        func atoll() throws -> Atoll {
            guard let playerID = PlayerID(rawValue: player) else {
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: [],
                        debugDescription: "unknown atoll player \(player)"))
            }
            return Atoll(
                player: playerID,
                cells: Set(cells.map { Hex($0[0], $0[1]) }))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(radius, forKey: .radius)
        try c.encode(swells, forKey: .swells)
        try c.encode(
            preIslands.sorted(by: Hex.rowMajor).map { [$0.q, $0.r] },
            forKey: .preIslands)
        try c.encode(
            atolls.sorted { $0.player.rawValue < $1.player.rawValue }
                .map { AtollRecord(player: $0.player, cells: $0.cells) },
            forKey: .atolls)
        try c.encode(symmetry.rawValue, forKey: .symmetry)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        radius = try c.decode(Int.self, forKey: .radius)
        swells = try c.decode([Swell].self, forKey: .swells)
        preIslands = Set(
            try c.decode([[Int]].self, forKey: .preIslands)
                .map { Hex($0[0], $0[1]) })
        atolls = try c.decode([AtollRecord].self, forKey: .atolls).map { try $0.atoll() }
        let symmetryRaw = try c.decode(String.self, forKey: .symmetry)
        symmetry = ChartSymmetry(rawValue: symmetryRaw) ?? .none
    }
}
