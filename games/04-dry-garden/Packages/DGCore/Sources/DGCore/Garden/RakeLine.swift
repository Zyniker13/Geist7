// RakeLine.swift — a raked run of cells (R-5, R-22, R-23).

/// How a rake line is drawn. Patterns are display-only at launch (R-23):
/// every pattern follows identical rules.
public enum RakePattern: String, Codable, Hashable, Sendable, CaseIterable {
    case straight
    case ripple
    case wave
}

/// One raked line: the cells (2–5 of them, R-5), the owner, the anchoring
/// stone's cell (R-5's adjacent stone, kept adjacent for the whole game,
/// R-22), and the display pattern (R-23).
public struct RakeLine: Codable, Hashable, Sendable {
    /// Owning player.
    public var owner: PlayerID
    /// The raked cells in order from the anchor outward.
    public var cells: [Hex]
    /// The anchoring stone's cell; adjacent to `cells.first` (R-5, R-22).
    public var anchor: Hex
    /// Display-only pattern (R-23).
    public var pattern: RakePattern

    public init(
        owner: PlayerID, cells: [Hex], anchor: Hex,
        pattern: RakePattern = .straight
    ) {
        self.owner = owner
        self.cells = cells
        self.anchor = anchor
        self.pattern = pattern
    }
}
