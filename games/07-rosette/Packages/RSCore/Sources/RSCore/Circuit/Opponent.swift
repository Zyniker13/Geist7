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
    /// to 5%. The thresholds come from `Personality.cubeThresholds`, the same
    /// source RSAI's CubePolicy plays by, so the tell is honest.
    public func tell() -> String {
        let thresholds = personality.cubeThresholds(aggression: cubeAggression)
        let roundedDouble = (thresholds.double / 5) * 5
        let roundedTake = (thresholds.take / 5) * 5
        return "Doubles near \(roundedDouble)%, takes near \(roundedTake)%."
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

    /// The personality's shift of the doubling threshold, in percentage
    /// points (A.5: gambler −10%, careful +5%; bluffers bluff early, which
    /// reads as the same −10% shift; greedy plays the base line).
    var doubleThresholdShift: Int {
        switch self {
        case .careful: return 5
        case .greedy: return 0
        case .bluffer: return -10
        case .gambler: return -10
        }
    }

    /// This personality's doubling and take thresholds, in integer percent,
    /// for an opponent with content `cubeAggression` 0–10 (A.4/A.5: the
    /// optimal double threshold is 70%; aggression lowers it, and the
    /// personality shifts it further). The take threshold falls with
    /// aggression (riskier players accept more). `Opponent.tell()` reports
    /// these rounded to 5% (R-24), and RSAI's CubePolicy plays by them —
    /// one source of truth so the tell can never lie.
    public func cubeThresholds(aggression: Int) -> (double: Int, take: Int) {
        let level = max(0, min(10, aggression))
        let double = (70 - 2 * level + doubleThresholdShift)
        let take = 25 - level
        return (double: max(45, min(80, double)), take: max(10, min(35, take)))
    }
}
