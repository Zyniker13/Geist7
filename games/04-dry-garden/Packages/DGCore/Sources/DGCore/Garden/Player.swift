// Player.swift — the two players (R-3).

/// The two gardeners. Player 1 is basalt (dark) and moves first (R-3);
/// Player 2 is granite. Raw values are stable JSON identities.
public enum PlayerID: Int, Codable, Hashable, Sendable, CaseIterable {
    case one = 1
    case two = 2

    /// The other player.
    public var opponent: PlayerID {
        self == .one ? .two : .one
    }
}
