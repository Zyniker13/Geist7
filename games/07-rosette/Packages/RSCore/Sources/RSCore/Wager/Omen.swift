// MARK: - OmenEffect

/// The effect of an omen (R-12: a closed set of effect kinds; R-23: effects
/// act only on choices, never on dice probabilities).
///
/// Coded as the roadmap's sample row shows: `{"kind": "reroll", "n": 1}` —
/// the flat `n` carries the effect's single parameter (re-roll count, split
/// piece count) when the kind takes one.
public struct OmenEffect: Sendable, Equatable {
    /// The kind of effect.
    public let kind: OmenKind
    /// The effect's parameter (re-roll count, split piece count); nil for
    /// kinds that take none.
    public let n: Int?

    public init(kind: OmenKind, n: Int? = nil) {
        self.kind = kind
        self.n = n
    }

    /// Create a re-roll omen effect.
    public static func reroll(count: Int) -> OmenEffect {
        OmenEffect(kind: .reroll, n: count)
    }

    /// Create a safety-toggle omen effect.
    public static func unsafeRosettes(count: Int) -> OmenEffect {
        OmenEffect(kind: .unsafeRosettes, n: count)
    }

    /// Create a split-move omen effect.
    public static func split(count: Int) -> OmenEffect {
        OmenEffect(kind: .split, n: count)
    }
}

// MARK: Codable (flat kind + optional n, per the roadmap sample row)

extension OmenEffect: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case n
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.kind = try container.decode(OmenKind.self, forKey: .kind)
        self.n = try container.decodeIfPresent(Int.self, forKey: .n)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(n, forKey: .n)
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
