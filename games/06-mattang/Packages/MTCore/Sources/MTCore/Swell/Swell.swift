// Swell.swift — one swell on the chart.
//
// R-2/R-3: a swell enters from one board side and emits one ray from
// every edge cell on that side, each ray travelling in the swell's
// direction. Weights (R-1, A.4): the dominant swell weighs 2, a minor
// swell weighs 1; a cell's strength is the sum over distinct swells
// crossing it (R-6, R-15).

public struct Swell: Hashable, Codable, Sendable {
    public static let majorWeight = 2
    public static let minorWeight = 1

    /// Stable identifier, e.g. "east_dom".
    public let id: String
    public let entrySide: Int
    public let direction: Int
    public let weight: Int

    public init(id: String, entrySide: Int, direction: Int, weight: Int) {
        precondition((0..<6).contains(entrySide), "entrySide must be 0–5")
        precondition((0..<6).contains(direction), "direction must be 0–5")
        self.id = id
        self.entrySide = entrySide
        self.direction = direction
        self.weight = weight
    }

    public static func major(id: String, entrySide: Int, direction: Int) -> Swell {
        Swell(id: id, entrySide: entrySide, direction: direction, weight: majorWeight)
    }

    public static func minor(id: String, entrySide: Int, direction: Int) -> Swell {
        Swell(id: id, entrySide: entrySide, direction: direction, weight: minorWeight)
    }
}
