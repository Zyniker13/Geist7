// MARK: - CircuitState

/// State of the tavern circuit (R-13, R-14).
public struct CircuitState: Sendable, Equatable {
    /// Current tavern.
    public var currentTavern: Tavern
    /// Player's score in the circuit.
    public var circuitScore: Int
    /// Number of taverns completed.
    public var tavernsCompleted: Int
    /// Total games played in the circuit.
    public var totalGames: Int
    /// Total wins.
    public var totalWins: Int
    /// Omens collected.
    public var collectedOmens: [String]
    /// Current purse (winnings).
    public var purse: Purse

    /// Create a new circuit state.
    public static func newCircuit() -> CircuitState {
        CircuitState(
            currentTavern: Tavern.firstTavern(),
            circuitScore: 0,
            tavernsCompleted: 0,
            totalGames: 0,
            totalWins: 0,
            collectedOmens: [],
            purse: Purse()
        )
    }

    /// Record a game result.
    public mutating func recordResult(won: Bool, stake: Int) {
        totalGames += 1
        if won {
            totalWins += 1
            circuitScore += stake
            purse.add(stake)
        } else {
            circuitScore -= stake
            if !purse.pay(stake) {
                purse.balance = 0 // Can't go negative
            }
        }
    }

    /// Advance to the next tavern.
    @discardableResult
    public mutating func advanceTavern() -> Tavern {
        tavernsCompleted += 1
        let oldTavern = currentTavern
        currentTavern = currentTavern.nextTavern()
        return oldTavern
    }

    /// Check if the circuit is complete.
    public var isComplete: Bool {
        currentTavern.isFinal
    }

    /// Check if the player can afford the current stake.
    public var canAffordStake: Bool {
        purse.balance >= currentTavern.stake
    }

    /// The win rate in the circuit.
    public var winRate: Double {
        totalGames == 0 ? 0.0 : Double(totalWins) / Double(totalGames)
    }

    /// Reset the circuit (keep omens).
    public mutating func reset() {
        circuitScore = 0
        tavernsCompleted = 0
        totalGames = 0
        totalWins = 0
        purse = Purse()
        currentTavern = Tavern.firstTavern()
    }
}
