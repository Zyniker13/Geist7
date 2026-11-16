// MARK: - Tavern

/// A tavern in the circuit.
struct Tavern: Sendable, Equatable, Codable {
    /// The tavern's name.
    let name: String
    /// The difficulty level.
    let difficulty: Int  // 1-5
    /// The AI opponent's level.
    let aiLevel: Int  // 1-5
    /// The starting stake.
    let stake: Int
    /// Any special rules.
    let specialRules: [String]

    /// Create a new tavern.
    static func newTavern() -> Tavern {
        Tavern(name: "The Ancient Scribe", difficulty: 1, aiLevel: 1, stake: 1, specialRules: [])
    }

    /// Advance to the next tavern.
    static func nextTavern(from current: Tavern) -> Tavern {
        let nextLevel = min(current.difficulty + 1, 5)
        let names = [
            "The Ancient Scribe",
            "The Temple Guard",
            "The Merchant Quarter",
            "The Royal Court",
            "The High Priest"
        ]
        let name = names[min(nextLevel - 1, names.count - 1)]
        return Tavern(
            name: name,
            difficulty: nextLevel,
            aiLevel: nextLevel,
            stake: current.stake * 2,
            specialRules: current.specialRules
        )
    }

    /// The final tavern.
    static func finalTavern() -> Tavern {
        Tavern(name: "The High Priest", difficulty: 5, aiLevel: 5, stake: 16, specialRules: [])
    }
}
