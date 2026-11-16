// MARK: - OmenEffect

/// The effect of an omen (R-12: a closed set of effect kinds; R-23: effects
/// act only on choices, never on dice probabilities).
public struct OmenEffect: Sendable, Equatable, Codable {
    /// The kind of effect.
    public let kind: OmenKind
    /// Additional parameters (e.g., number of re-rolls).
    public let parameters: [String: Int]

    public init(kind: OmenKind, parameters: [String: Int]) {
        self.kind = kind
        self.parameters = parameters
    }

    /// Create a re-roll omen effect.
    public static func reroll(count: Int) -> OmenEffect {
        OmenEffect(kind: .reroll, parameters: ["count": count])
    }

    /// Create a safety-toggle omen effect.
    public static func unsafeRosettes(count: Int) -> OmenEffect {
        OmenEffect(kind: .unsafeRosettes, parameters: ["count": count])
    }

    /// Create a split-move omen effect.
    public static func split(count: Int) -> OmenEffect {
        OmenEffect(kind: .split, parameters: ["count": count])
    }
}

// MARK: - OmenKind

/// The kind of omen effect.
public enum OmenKind: String, Sendable, Codable, CaseIterable {
    /// Re-roll the dice once; the replacement draw comes from the omen stream.
    case reroll
    /// Treat safe rosettes as unsafe for this turn (captures allowed there).
    case unsafeRosettes
    /// Split the roll between two pieces.
    case split
}

// MARK: - Omen

/// A single omen held by a player (R-12).
public struct Omen: Sendable, Equatable, Codable {
    /// Unique identifier (matches OmenDef.id in the content data).
    public let id: String
    /// The omen's effect.
    public let effect: OmenEffect
    /// Cost to acquire.
    public let cost: Int
    /// History label.
    public let label: HistoryLabel

    public init(id: String, effect: OmenEffect, cost: Int, label: HistoryLabel) {
        self.id = id
        self.effect = effect
        self.cost = cost
        self.label = label
    }
}
