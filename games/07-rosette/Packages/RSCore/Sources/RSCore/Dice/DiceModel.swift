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

    public init(id: String, label: String, outcomes: [DiceOutcome], denominator: Int, note: String) {
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
            DiceOutcome(value: 4, weight: 1)
        ],
        denominator: 16,
        note: "Marked-tip counts from the excavated Ur sets (R-2, reconstructed)."
    )

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
        return outcomes.last!.value
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
