// Hex.swift — axial hex coordinates for the gravel lattice (R-16).
//
// Convention (ADR-0003): q is east, r is south-east; the layout is
// pointy-top, so r increases screen-down and the axial neighbor deltas
// map exactly to east / southeast / southwest / west / northwest /
// northeast. Directions 0–5 run clockwise from east (R-4's `facing`,
// R-5's rake direction, and R-12's "three downward directions" all
// index this list).

public struct Hex: Hashable, Codable, Sendable {
    public var q: Int
    public var r: Int

    public init(q: Int, r: Int) {
        self.q = q
        self.r = r
    }

    public init(_ q: Int, _ r: Int) {
        self.init(q: q, r: r)
    }

    // MARK: Directions (0–5, clockwise from east)

    /// Axial deltas for directions 0–5, clockwise from east:
    /// 0 E (+1, 0), 1 SE (0, +1), 2 SW (−1, +1),
    /// 3 W (−1, 0), 4 NW (0, −1), 5 NE (+1, −1).
    public static let directionVectors: [Hex] = [
        Hex(1, 0), Hex(0, 1), Hex(-1, 1),
        Hex(-1, 0), Hex(0, -1), Hex(1, -1),
    ]

    /// Human-readable direction names, indexed 0–5.
    public static let directionNames: [String] = [
        "E", "SE", "SW", "W", "NW", "NE",
    ]

    /// Opposite direction (d + 3) mod 6.
    public static func opposite(_ d: Int) -> Int {
        flooredMod(d + 3, 6)
    }

    /// The neighbor of `self` in direction `d` (0–5).
    public func neighbor(_ d: Int) -> Hex {
        let v = Self.directionVectors[flooredMod(d, 6)]
        return Hex(q + v.q, r + v.r)
    }

    // MARK: Arithmetic and distance (R-16)

    public static func + (lhs: Hex, rhs: Hex) -> Hex {
        Hex(lhs.q + rhs.q, lhs.r + rhs.r)
    }

    public static func - (lhs: Hex, rhs: Hex) -> Hex {
        Hex(lhs.q - rhs.q, lhs.r - rhs.r)
    }

    /// Axial (cube) distance: (|dq| + |dr| + |dq + dr|) / 2 (R-16).
    public func distance(to other: Hex) -> Int {
        let dq = q - other.q
        let dr = r - other.r
        return (abs(dq) + abs(dr) + abs(dq + dr)) / 2
    }
}
