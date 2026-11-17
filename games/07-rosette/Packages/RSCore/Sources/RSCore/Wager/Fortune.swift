// MARK: - FortuneDeck

/// The two fortune decks on the Tablet ruleset's squares (R-16: the tablet
/// attests that squares carry fortunes; which squares and the in-game
/// effects are Invented — see docs/DECISIONS.md ADR-0008).
public enum FortuneDeck: String, Sendable, Codable, CaseIterable {
    /// A favourable fortune: the landing piece rolls again.
    case good = "fortune_good"
    /// An unfavourable fortune: the landing piece is sent home.
    case bad = "fortune_bad"
}

// MARK: - FortuneSquare

/// A square carrying a fortune (R-16). Part of match state so replays are
/// deterministic (INV-4): the effect depends only on the square landed on.
public struct FortuneSquare: Sendable, Equatable, Codable {
    /// The ruleset these fortunes belong to.
    public let rulesetId: String
    /// The path square (0-based) carrying the fortune.
    public let square: Int
    /// Which deck the square draws from.
    public let deck: FortuneDeck

    public init(rulesetId: String, square: Int, deck: FortuneDeck) {
        self.rulesetId = rulesetId
        self.square = square
        self.deck = deck
    }
}
