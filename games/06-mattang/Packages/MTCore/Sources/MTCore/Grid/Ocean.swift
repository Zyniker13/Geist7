// Ocean.swift — the hex ocean region and its edges.
//
// The board is a hexagon of radius R (7 for the standard chart): every
// axial cell whose distance from the origin is ≤ R. Edges are the rim
// cells whose neighbor in a given direction lies outside; swell rays
// enter the ocean from those edge cells (R-3).

public struct Ocean: Hashable, Sendable {
    public let radius: Int

    public init(radius: Int) {
        precondition(radius >= 1, "ocean radius must be at least 1")
        self.radius = radius
    }

    public var center: Hex { Hex(0, 0) }

    public func contains(_ h: Hex) -> Bool {
        h.distance(to: center) <= radius
    }

    /// All ocean cells in canonical row-major order (r ascending, then
    /// q ascending). This is the enumeration order every deterministic
    /// listing in the game uses.
    public var allCells: [Hex] {
        var cells: [Hex] = []
        for r in -radius...radius {
            let lo = max(-radius, -radius - r)
            let hi = min(radius, radius - r)
            for q in lo...hi {
                cells.append(Hex(q, r))
            }
        }
        return cells
    }

    /// Edge cells of a side (R-3): the rim cells whose neighbor in
    /// direction `side` lies outside the ocean, in row-major order. For
    /// a radius-R hexagon this is the corner-to-corner arc facing
    /// `side`, 2R+1 cells — a swell entering from that side sweeps
    /// every row of the ocean when it travels straight in.
    public func edge(_ side: Int) -> [Hex] {
        let d = flooredMod(side, 6)
        return allCells.filter { !contains($0.neighbor(d)) }
    }
}
