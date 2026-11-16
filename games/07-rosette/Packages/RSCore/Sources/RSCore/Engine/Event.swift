// MARK: - Event

/// An event emitted by the reducer when a state change occurs.
public enum Event: Equatable, Sendable {
    /// A dice roll occurred with the given value.
    case diceRolled(value: Int)
    /// A piece was moved.
    case pieceMoved(piece: PieceID, from: Int, to: Int)
    /// A piece was captured.
    case pieceCaptured(piece: PieceID, by: PlayerID)
    /// A piece was borne off.
    case pieceBorneOff(piece: PieceID, player: PlayerID)
    /// A rosette was landed on, granting an extra roll (R-6).
    case rosetteLanded(player: PlayerID)
    /// A double was offered (R-10).
    case doubleOffered(by: PlayerID)
    /// The doubling cube was doubled and passed to the accepter (R-10).
    case cubeDoubled(newValue: Int, newOwner: PlayerID)
    /// A player conceded (R-10).
    case conceded(by: PlayerID)
    /// A match ended (R-8).
    case matchWon(winner: PlayerID, gammon: Bool)
    /// An omen was played (R-12).
    case omenPlayed(omenId: String, player: PlayerID)
    /// A stake was set (R-9).
    case stakeSet(value: Int)
    /// A turn passed (roll of 0 or no legal moves, R-3).
    case turnPassed
}
