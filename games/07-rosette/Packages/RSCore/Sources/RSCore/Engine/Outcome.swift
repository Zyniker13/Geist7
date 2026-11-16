// MARK: - Outcome

/// The result of a completed match.
public struct Outcome: Sendable, Equatable {
    /// The winning player.
    public let winner: PlayerID
    /// Whether the loser bore off zero pieces (R-11 gammon-equivalent).
    public let gammon: Bool
    /// The final cube value.
    public let cubeValue: Int
    /// The stake at the start of the match.
    public let initialStake: Int
    /// Total plies (individual piece moves) in the match.
    public let plies: Int

    public init(winner: PlayerID, gammon: Bool, cubeValue: Int, initialStake: Int, plies: Int) {
        self.winner = winner
        self.gammon = gammon
        self.cubeValue = cubeValue
        self.initialStake = initialStake
        self.plies = plies
    }

    /// Score from `player`'s perspective: positive when they won. A gammon
    /// doubles the stake (R-11).
    public func score(for player: PlayerID) -> Int {
        let base = initialStake * cubeValue
        let amount = gammon ? base * 2 : base
        return player == winner ? amount : -amount
    }
}
