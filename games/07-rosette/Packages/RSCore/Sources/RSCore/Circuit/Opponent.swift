// MARK: - Opponent

/// An AI opponent in the circuit (R-13/R-14): a personality with cube
/// aggression, omens it may hold, and a tell the player can buy (R-24).
public struct Opponent: Sendable, Equatable {
    /// Unique identifier.
    public let id: String
    /// Display name.
    public let name: String
    /// The personality (roadmap §7: careful, greedy, bluffer, gambler).
    public let personality: Personality
    /// How readily this opponent doubles (content-scale int; the cube
    /// thresholds come from this in P4).
    public let cubeAggression: Int
    /// Omen ids this opponent may hold (R-12).
    public let omenIds: [String]
    /// R-14/R-24: the cost to learn this opponent's tell.
    public let tellCost: Int
    /// HIST3.1: the opponent's history label.
    public let label: HistoryLabel
    /// HIST3.1: the opponent's in-game historical note, if any.
    public let historyNote: String?

    /// Create from a definition.
    public init(def: OpponentDef) {
        self.id = def.id
        self.name = def.name
        self.personality = Personality(rawValue: def.ai) ?? .careful
        self.cubeAggression = def.cubeAggression
        self.omenIds = def.omens
        self.tellCost = def.tellCost
        self.label = def.label
        self.historyNote = def.historyNote
    }

    /// Create directly (test fixtures).
    public init(
        id: String,
        name: String,
        personality: Personality,
        cubeAggression: Int,
        omenIds: [String] = [],
        tellCost: Int,
        label: HistoryLabel,
        historyNote: String? = nil
    ) {
        self.id = id
        self.name = name
        self.personality = personality
        self.cubeAggression = cubeAggression
        self.omenIds = omenIds
        self.tellCost = tellCost
        self.label = label
        self.historyNote = historyNote
    }

    /// R-24: the opponent's tell — its doubling and take thresholds, rounded
    /// to 5%. Derived from cubeAggression until P4 wires real thresholds.
    public func tell() -> String {
        let aggression = max(0, min(10, cubeAggression))
        let doublePct = 70 - aggression * 2  // 70% down to 50%
        let rounded = (doublePct / 5) * 5
        let takePct = ((25 + aggression) / 5) * 5
        return "Doubles near \(rounded)%, takes near \(takePct)%."
    }

    /// Build the circuit bot for this opponent at the tavern's strength.
    public func makeBot(strength: Int) -> RosetteBot {
        RosetteBot(personality: personality, strength: strength)
    }
}

// MARK: - Personality

/// The AI opponent personalities (roadmap §7: data-driven — careful, greedy,
/// bluffer, gambler — as deviations from optimal).
public enum Personality: String, Sendable, Codable, CaseIterable {
    /// Plays positionally and safely; doubles late.
    case careful
    /// Prefers captures and aggressive races.
    case greedy
    /// Doubles early to pressure (bluff), mixed play.
    case bluffer
    /// Takes risks; doubles early and often.
    case gambler
}
