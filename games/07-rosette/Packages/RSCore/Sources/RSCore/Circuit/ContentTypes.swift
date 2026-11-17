// MARK: - TavernDef

/// A tavern definition (loaded from content, used to create Tavern).
public struct TavernDef: Sendable, Codable, Equatable {
    public let id: String
    public let name: String
    public let region: String
    public let difficulty: Int
    public let aiLevel: Int
    public let stake: Int
    public let specialRules: [String]
    public let label: HistoryLabel
}

// MARK: - OpponentDef

/// An opponent definition (loaded from content, used to create Opponent).
public struct OpponentDef: Sendable, Codable, Equatable {
    public let id: String
    public let name: String
    public let description: String
    public let difficulty: Int
    public let tavernId: String
    public let style: String
    public let label: HistoryLabel
}

// MARK: - OmenDef

/// An omen definition (loaded from content, used to create Omen).
public struct OmenDef: Sendable, Codable, Equatable {
    public let id: String
    public let name: String
    public let cost: Int
    public let effectKind: String
    public let parameters: [String: Int]
    public let label: HistoryLabel
}

// MARK: - RulesetDef

/// A ruleset definition (loaded from content).
public struct RulesetDef: Sendable, Codable, Equatable {
    public let id: String
    public let name: String
    public let boardSize: Int
    public let pieceCount: Int
    public let startOffset: Int
    public let hasRosettes: Bool
    public let allowsCaptures: Bool
    public let allowsGammons: Bool
    public let label: HistoryLabel
}

// MARK: - TutorialLessonDef

/// A tutorial lesson definition (loaded from content).
public struct TutorialLessonDef: Sendable, Codable, Equatable {
    public let id: String
    public let title: String
    public let steps: [String]
    public let rulesetId: String
    public let isFirst: Bool
    public let label: HistoryLabel?
}

// MARK: - BalanceDef

/// Balance data for the game.
public struct BalanceDef: Sendable, Codable {
    public let diceModifier: [String: Int]
    public let winProbability: [String: Double]
    public let avgGameLength: [String: Int]
}
