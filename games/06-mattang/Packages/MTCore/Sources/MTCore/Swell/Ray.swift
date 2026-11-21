// Ray.swift — one swell ray and how its trace ended.
//
// R-3..R-5, R-12..R-16: a ray starts on an edge cell of its swell's
// entry side and travels hex direction by hex direction. It reflects
// off island and atoll faces (R-12, at most 3 reflections), refracts
// around islands it passes (R-13/R-14, at most once per island per
// ray), and terminates when it leaves the ocean, after its third
// reflection, or after 40 steps (R-5).
//
// Schema per ROADMAP A.3: { swell, cells, reflections, termination }.

public enum RayEnd: String, Hashable, Codable, Sendable {
    /// The ray's next step would leave the ocean.
    case leftOcean
    /// The ray made its third reflection; R-5 ends it there.
    case maxReflections
    /// The 40-step cap stopped the ray.
    case maxSteps
}

public struct RayPath: Hashable, Codable, Sendable {
    /// The swell id this ray belongs to.
    public let swell: String
    /// Cells visited in order, starting with the entry edge cell.
    /// Island and atoll cells never appear; a reflection retraces the
    /// line in the opposite direction.
    public let cells: [Hex]
    /// How many reflections the ray made so far.
    public let reflections: Int
    public let termination: RayEnd

    public init(swell: String, cells: [Hex], reflections: Int, termination: RayEnd) {
        self.swell = swell
        self.cells = cells
        self.reflections = reflections
        self.termination = termination
    }

    /// The edge cell the ray starts on (`cells.first`).
    public var start: Hex? { cells.first }
}
