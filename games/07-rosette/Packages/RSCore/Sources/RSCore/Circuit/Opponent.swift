// MARK: - Opponent

/// An AI opponent in the circuit.
public struct Opponent: Sendable, Equatable {
    /// Unique identifier.
    public let id: String
    /// Display name.
    public let name: String
    /// Description.
    public let description: String
    /// Difficulty tier (1–5).
    public let difficulty: Int
    /// Tavern this opponent guards.
    public let tavernId: String
    /// Strategy style.
    public let style: StrategyStyle
    /// History label.
    public let label: HistoryLabel

    /// Create from a definition.
    public init(def: OpponentDef) {
        self.id = def.id
        self.name = def.name
        self.description = def.description
        self.difficulty = def.difficulty
        self.tavernId = def.tavernId
        self.style = StrategyStyle(rawValue: def.style) ?? .balanced
        self.label = def.label
    }

    /// Create directly (for hardcoded opponents).
    public init(
        id: String,
        name: String,
        description: String,
        difficulty: Int,
        tavernId: String,
        style: StrategyStyle,
        label: HistoryLabel
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.difficulty = difficulty
        self.tavernId = tavernId
        self.style = style
        self.label = label
    }

    /// The default opponent (apprentice).
    public static func defaultOpponent() -> Opponent {
        Opponent(
            id: "apprentice",
            name: "The Apprentice",
            description: "A young student still learning the game's basics.",
            difficulty: 1,
            tavernId: "thebes_scribe",
            style: .aggressive,
            label: .reconstructed
        )
    }

    /// Create a bot opponent at a given difficulty.
    public func makeBot() -> RosetteBot {
        RosetteBot(difficulty: difficulty, style: style)
    }
}

// MARK: - StrategyStyle

/// The AI opponent's strategy style.
public enum StrategyStyle: String, Sendable, Codable, CaseIterable {
    /// Prefers captures and aggressive moves.
    case aggressive
    /// Prefers positional play and defense.
    case positional
    /// Balanced between aggressive and defensive.
    case balanced
    /// Plays randomly (beginner).
    case random
}
