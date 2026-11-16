// MARK: - CircuitState

/// State of the tavern circuit.
struct CircuitState: Sendable, Equatable {
    /// Current tavern.
    var currentTavern: Tavern
    /// Player's score in the circuit.
    var circuitScore: Int
    /// Number of taverns completed.
    var tavernsCompleted: Int
    /// Total games played in the circuit.
    var totalGames: Int
    /// Total wins.
    var totalWins: Int

    /// Create a new circuit state.
    static func newCircuit() -> CircuitState {
        CircuitState(
            currentTavern: Tavern.newTavern(),
            circuitScore: 0,
            tavernsCompleted: 0,
            totalGames: 0,
            totalWins: 0
        )
    }

    /// Record a game result.
    mutating func recordResult(won: Bool, score: Int) {
        totalGames += 1
        circuitScore += won ? score : -score
        if won { totalWins += 1 }
    }

    /// Advance to the next tavern.
    mutating func advanceTavern() {
        tavernsCompleted += 1
        currentTavern = Tavern.nextTavern(from: currentTavern)
    }

    /// Check if the circuit is complete.
    var isComplete: Bool {
        currentTavern == Tavern.finalTavern()
    }
}
