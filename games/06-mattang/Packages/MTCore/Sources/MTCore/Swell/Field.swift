// Field.swift — the swell field: which swells reach each sea cell, at
// what strength, and the ray paths that produced them (A.3).
//
// R-6: a cell's swell set is the set of distinct swell ids whose rays
// pass through it, and its strength is the sum of those swells'
// weights; a node is a cell with two or more distinct swells. R-15:
// rays of the same swell do not interact and a cell counts each swell
// id once no matter how many of that swell's rays pass through it.
// Rays never enter island or atoll cells, so every entry here is a
// sea cell.

public typealias SwellMask = Set<String>

public struct Field: Hashable, Codable, Sendable {
    /// The swell ids reaching each sea cell (R-6).
    public let swells: [Hex: SwellMask]
    /// Strength per sea cell: the sum of the reaching swells' weights (R-6).
    public let strength: [Hex: Int]
    /// Every traced ray, in swell order then edge row-major order.
    public let rays: [RayPath]

    public init(swells: [Hex: SwellMask], strength: [Hex: Int], rays: [RayPath]) {
        self.swells = swells
        self.strength = strength
        self.rays = rays
    }

    /// Strength at a cell; 0 where no swell reaches (R-6).
    public func strength(at cell: Hex) -> Int { strength[cell] ?? 0 }

    /// The swell ids reaching a cell; empty where none reach.
    public func swells(at cell: Hex) -> SwellMask { swells[cell] ?? [] }

    /// R-6: nodes are the cells with two or more distinct swells.
    public var nodes: Set<Hex> {
        Set(swells.filter { $0.value.count >= 2 }.keys)
    }

    /// R-6: is this cell a node — reached by two or more distinct
    /// swells?
    public func isNode(_ cell: Hex) -> Bool {
        (swells[cell]?.count ?? 0) >= 2
    }

    /// Trace every swell's rays over the ocean and aggregate the
    /// field (R-3..R-6, R-12..R-16). Atoll cells behave as islands
    /// for tracing (R-16); an island or atoll cell on a swell's entry
    /// side blocks that entry and emits no ray.
    ///
    /// The swells must have distinct ids; their array order is part
    /// of the traced field (rays follow it).
    public static func compute(
        ocean: Ocean,
        swells: [Swell],
        islands: Set<Hex>,
        atollCells: Set<Hex>
    ) -> Field {
        let ids = swells.map(\.id)
        precondition(Set(ids).count == ids.count, "swell ids must be distinct")

        let rays = Tracer.trace(
            ocean: ocean, swells: swells,
            islands: islands, atollCells: atollCells)

        var weights: [String: Int] = [:]
        for swell in swells { weights[swell.id] = swell.weight }

        var masks: [Hex: SwellMask] = [:]
        for ray in rays {
            for cell in ray.cells {
                masks[cell, default: []].insert(ray.swell)
            }
        }

        var strength: [Hex: Int] = [:]
        for (cell, mask) in masks {
            strength[cell] = mask.reduce(0) { $0 + (weights[$1] ?? 0) }
        }

        return Field(swells: masks, strength: strength, rays: rays)
    }
}

// ADR-0009: hand-written Codable with stable orderings so that
// encoding is byte-stable across processes and platforms (INV-4):
// dictionaries serialize as arrays sorted by row-major cell order,
// masks serialize as sorted id arrays.
extension Field {
    private enum CodingKeys: String, CodingKey {
        case swells, strength, rays
    }

    private struct CellEntry: Codable {
        let q: Int
        let r: Int
        let ids: [String]
    }

    private struct StrengthEntry: Codable {
        let q: Int
        let r: Int
        let value: Int
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        let swellEntries =
            swells
            .map { cell, mask in CellEntry(q: cell.q, r: cell.r, ids: mask.sorted()) }
            .sorted { ($0.r, $0.q) < ($1.r, $1.q) }
        try c.encode(swellEntries, forKey: .swells)
        let strengthEntries =
            strength
            .map { cell, value in StrengthEntry(q: cell.q, r: cell.r, value: value) }
            .sorted { ($0.r, $0.q) < ($1.r, $1.q) }
        try c.encode(strengthEntries, forKey: .strength)
        try c.encode(rays, forKey: .rays)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let swellEntries = try c.decode([CellEntry].self, forKey: .swells)
        swells = Dictionary(
            swellEntries.map { (Hex(q: $0.q, r: $0.r), Set($0.ids)) },
            uniquingKeysWith: { _, _ in preconditionFailure("duplicate cell in swells") })
        let strengthEntries = try c.decode([StrengthEntry].self, forKey: .strength)
        strength = Dictionary(
            strengthEntries.map { (Hex(q: $0.q, r: $0.r), $0.value) },
            uniquingKeysWith: { _, _ in preconditionFailure("duplicate cell in strength") })
        rays = try c.decode([RayPath].self, forKey: .rays)
    }
}
