// MARK: - DiceOutcome

/// A single outcome of a dice roll with its weight (R-17).
public struct DiceOutcome: Sendable, Equatable, Codable {
    /// The move value (number of squares).
    public let value: Int
    /// How many ways this outcome can occur.
    public let weight: Int

    public init(value: Int, weight: Int) {
        self.value = value
        self.weight = weight
    }
}

// MARK: - DiceModel

/// A dice model defined by outcome weights (R-17: a data table of
/// `(outcome, weight)` pairs whose weights sum to the denominator).
public struct DiceModel: Sendable, Equatable, Codable {
    /// Unique identifier.
    public let id: String
    /// Human-readable label.
    public let label: String
    /// All possible outcomes and their weights.
    public let outcomes: [DiceOutcome]
    /// Sum of all weights (denominator for probability).
    public let denominator: Int
    /// Description note.
    public let note: String

    public init(id: String, label: String, outcomes: [DiceOutcome], denominator: Int, note: String)
    {
        self.id = id
        self.label = label
        self.outcomes = outcomes
        self.denominator = denominator
        self.note = note
    }

    /// R-2: four binary tetrahedra; the roll counts marked tips up (0-4),
    /// reconstructed from the excavated Ur sets.
    public static let tetra4 = DiceModel(
        id: "tetra4",
        label: "Four binary tetrahedra",
        outcomes: [
            DiceOutcome(value: 0, weight: 1),
            DiceOutcome(value: 1, weight: 4),
            DiceOutcome(value: 2, weight: 6),
            DiceOutcome(value: 3, weight: 4),
            DiceOutcome(value: 4, weight: 1),
        ],
        denominator: 16,
        note: "Marked-tip counts from the excavated Ur sets (R-2, reconstructed)."
    )

    /// Four astragals (knucklebones) for the Tablet ruleset (R-16): the
    /// tablet attests astragal dice, but not the face-to-value mapping or the
    /// face odds — both are Reconstructed placeholders (A.9 default 1) flagged
    /// for HIST review.
    public static let astragal4 = DiceModel(
        id: "astragal4",
        label: "Four astragals (knucklebones)",
        outcomes: [
            DiceOutcome(value: 1, weight: 10),
            DiceOutcome(value: 2, weight: 40),
            DiceOutcome(value: 3, weight: 40),
            DiceOutcome(value: 4, weight: 10),
        ],
        denominator: 100,
        note:
            "Placeholder face odds pending HIST review; the tablet attests astragals but not these values (R-16)."
    )

    /// Four two-sided throw sticks for the Senet-like ruleset: Kendall's
    /// reconstruction, one of several (labelled Reconstructed). Four binary
    /// sticks give the same 1-4-6-4-1 profile as the Ur tetrahedra.
    public static let stick4 = DiceModel(
        id: "stick4",
        label: "Four two-sided throw sticks",
        outcomes: [
            DiceOutcome(value: 0, weight: 1),
            DiceOutcome(value: 1, weight: 4),
            DiceOutcome(value: 2, weight: 6),
            DiceOutcome(value: 3, weight: 4),
            DiceOutcome(value: 4, weight: 1),
        ],
        denominator: 16,
        note: "Four binary throw sticks (Kendall's Senet reconstruction, one of several)."
    )

    /// Five binary beans for the Patolli ruleset (Durán's account): each bean
    /// lands marked or blank, and the marked count is the move (0-5).
    public static let beans5 = DiceModel(
        id: "beans5",
        label: "Five binary beans",
        outcomes: [
            DiceOutcome(value: 0, weight: 1),
            DiceOutcome(value: 1, weight: 5),
            DiceOutcome(value: 2, weight: 10),
            DiceOutcome(value: 3, weight: 10),
            DiceOutcome(value: 4, weight: 5),
            DiceOutcome(value: 5, weight: 1),
        ],
        denominator: 32,
        note: "Five beans per Durán's account of Patolli; marked faces count (Reconstructed)."
    )

    /// Look up a dice model by its content identifier (rulesets.json `dice`).
    public static func model(forID id: String) -> DiceModel? {
        switch id {
        case "tetra4": return .tetra4
        case "astragal4": return .astragal4
        case "stick4": return .stick4
        case "beans5": return .beans5
        default: return nil
        }
    }

    /// Total weight (sum of all outcome weights).
    public var totalWeight: Int {
        outcomes.reduce(0) { $0 + $1.weight }
    }

    /// Roll a single dice value using the seeded RNG.
    public func roll(rng: inout SeededRNG) -> Int {
        let target = rng.next(UInt64(totalWeight))
        var cumulative = 0
        for outcome in outcomes {
            cumulative += outcome.weight
            if target < UInt64(cumulative) {
                return outcome.value
            }
        }
        fatalError("unreachable: target \(target) >= totalWeight \(totalWeight)")
    }

    /// Roll `count` dice and return the sum.
    public func roll(count: Int, rng: inout SeededRNG) -> Int {
        var total = 0
        for _ in 0..<count {
            total += roll(rng: &rng)
        }
        return total
    }
}
