// Hex.swift — axial hex grid for the swell field.
//
// R-12 direction convention: directions 0–5 run clockwise from east.
// The board uses a pointy-top hex layout with axial coordinates (q, r),
// r increasing screen-down; in that layout the six axial neighbor
// deltas map exactly to east / southeast / southwest / west /
// northwest / northeast, so "clockwise from east" indexes the deltas
// below directly.
//
// Face normals: face k of a cell is the side shared with
// `neighbor(k)`; its outward normal points in direction k.

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

    // MARK: Directions (R-12: 0–5 clockwise from east)

    /// Axial deltas for directions 0–5, clockwise from east:
    /// 0 E (+1, 0), 1 SE (0, +1), 2 SW (−1, +1),
    /// 3 W (−1, 0), 4 NW (0, −1), 5 NE (+1, −1).
    public static let directionVectors: [Hex] = [
        Hex(1, 0), Hex(0, 1), Hex(-1, 1),
        Hex(-1, 0), Hex(0, -1), Hex(1, -1),
    ]

    /// Human-readable direction names, indexed 0–5 (R-12).
    public static let directionNames: [String] = [
        "E", "SE", "SW", "W", "NW", "NE",
    ]

    public static func opposite(_ d: Int) -> Int {
        flooredMod(d + 3, 6)
    }

    /// The neighbor of `self` in direction `d` (0–5).
    public func neighbor(_ d: Int) -> Hex {
        let v = Self.directionVectors[flooredMod(d, 6)]
        return Hex(q + v.q, r + v.r)
    }

    // MARK: Face normals

    /// Outward normal direction of face `k` is direction `k` itself
    /// (face k borders neighbor(k)). `faceStruck(by:)` gives the face
    /// of a cell that a ray travelling in direction `d` crosses when
    /// it enters the cell: the face whose outward normal points back
    /// along the travel direction, (d + 3) mod 6.
    public static func faceStruck(by d: Int) -> Int {
        flooredMod(d + 3, 6)
    }

    // MARK: Reflection (R-12)

    /// Reflection off an island face: incoming direction `d` striking
    /// the face whose outward normal is `n` leaves in direction
    /// `(2n − d + 3) mod 6`. Vertex entries (two faces equidistant)
    /// reverse: `(d + 3) mod 6`.
    ///
    /// Both agree for a straight entry into a cell (struck face
    /// n = (d+3) mod 6 → reversal); the general formula matters for
    /// corner strikes tracked by the ray tracer.
    @inlinable
    public static func reflect(incoming d: Int, striking n: Int) -> Int {
        flooredMod(2 * n - d + 3, 6)
    }

    /// Vertex-entry reflection: reverse the ray.
    @inlinable
    public static func reflectVertex(incoming d: Int) -> Int {
        flooredMod(d + 3, 6)
    }

    // MARK: Arithmetic

    public static func + (lhs: Hex, rhs: Hex) -> Hex {
        Hex(lhs.q + rhs.q, lhs.r + rhs.r)
    }

    public static func - (lhs: Hex, rhs: Hex) -> Hex {
        Hex(lhs.q - rhs.q, lhs.r - rhs.r)
    }

    /// Axial distance (cube distance).
    public func distance(to other: Hex) -> Int {
        let dq = q - other.q
        let dr = r - other.r
        return (abs(dq) + abs(dr) + abs(dq + dr)) / 2
    }
}
