// MARK: - Action

/// An action that can be taken in a match (roadmap §5 schema).
public enum Action: Codable, Hashable, Sendable {
    /// Roll the dice.
    case roll
    /// Move a piece; the destination is derived from the pending roll (R-3).
    case move(PieceID)
    /// Offer a double (doubling cube, R-10).
    case offerDouble
    /// Accept a pending double (R-10).
    case acceptDouble
    /// Concede: the current player resigns; while a double is pending, the
    /// offered player declines the double at the current stake (R-10).
    case concede
    /// Play an omen (R-12).
    case playOmen(omenId: String)
    /// Set the initial stake (R-9, before the match begins).
    case setStake(Int)
}
