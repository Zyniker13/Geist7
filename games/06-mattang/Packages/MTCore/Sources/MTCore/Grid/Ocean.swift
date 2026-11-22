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

    /// Ocean's identity is its radius. (Kept as an explicit conformance
    /// so a future cache member can't silently break synthesis the way
    /// Chart's memo box did.)
    public static func == (lhs: Ocean, rhs: Ocean) -> Bool {
        lhs.radius == rhs.radius
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(radius)
    }

    /// All ocean cells in canonical row-major order (r ascending, then
    /// q ascending). This is the enumeration order every deterministic
    /// listing in the game uses. The list is rebuilt per call — a
    /// stored cache would break the struct's value semantics unless
    /// ==/hash ignored it (the Chart memo-box pattern); callers that
    /// loop over cells repeatedly pass the list down or memoize at the
    /// chart level (Chart.swellEntryEdges), so the O(R²) rebuild runs
    /// once per decision point, not per ray step.
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
    ///
    /// `edge` is a pure function of radius and side; the tracer's inner
    /// loop calls it once per retrace of each swell. It scans all cells
    /// and tests distance per cell — O(R²) with zero allocations beyond
    /// the result. Memoizing it would need a mutable cache inside a
    /// Hashable struct (hand-written ==/hash like Chart's, for the same
    /// reason); the arc is small and the tracer's cost is elsewhere.
    public func edge(_ side: Int) -> [Hex] {
        let d = flooredMod(side, 6)
        return allCells.filter { !contains($0.neighbor(d)) }
    }
}
