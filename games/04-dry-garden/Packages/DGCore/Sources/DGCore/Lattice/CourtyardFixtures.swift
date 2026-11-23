// CourtyardFixtures.swift — the built-in courtyard masks for P1 (the
// default courtyard and one axis-bearing test yard). Tools/sim and the
// golden replays reconstruct the yard from these, self-contained.

public enum CourtyardFixtures {
    /// The default courtyard (ADR-0004): 44 cells, irregular outline,
    /// two features; zero in-play axes at the 70% filter.
    public static let defaultMask: [String] = [
        "..####.....",
        "...####....",
        ".....#####.",
        "##.........",
        "..######...",
        "...######..",
        "...........",
        "..######...",
        "...#####...",
        "##.........",
        "..####.....",
    ]

    public static let defaultFeatures: [Feature] = [
        Feature(cell: Hex(0, 4), kind: "moss"),
        Feature(cell: Hex(3, 7), kind: "basin"),
    ]

    /// A deliberately rectangular courtyard for symmetry-law fixtures
    /// (P1 tests need axes IN PLAY; the default yard has none).
    public static let rectangleMask: [String] = [
        "#####",
        "#####",
        "#####",
        "#####",
        "#####",
    ]

    public static func rectangle() throws -> Courtyard {
        try Courtyard.parse(
            id: "rectangle", name: "Rectangle", mask: rectangleMask,
            features: [], veranda: "bottom")
    }

    public static func longWall() throws -> Courtyard {
        try Courtyard.parse(
            id: "long_wall", name: "Long Wall", mask: defaultMask,
            features: defaultFeatures, veranda: "bottom")
    }
}
