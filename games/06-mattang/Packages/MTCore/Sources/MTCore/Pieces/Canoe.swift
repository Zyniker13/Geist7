// Canoe.swift — players, canoe identities, and canoe state.
//
// R-8: each player starts with four canoes in the home atoll and
// moves them across cells of strength 1 or more. R-9: a canoe is
// becalmed exactly when its sea cell has strength 0 (INV-8: becalmed
// is a pure function of the field and the canoe's position). R-10:
// entering a rival atoll cell lands the canoe.

public enum PlayerID: String, Hashable, Codable, CaseIterable, Sendable {
    case p1
    case p2
}

/// The other player.
extension PlayerID {
    public var opponent: PlayerID { self == .p1 ? .p2 : .p1 }
}

/// Stable identity for one canoe (each player has four, R-8).
public struct CanoeID: Hashable, Codable, Sendable {
    public let player: PlayerID
    public let index: Int

    public init(player: PlayerID, index: Int) {
        self.player = player
        self.index = index
    }
}

public enum CanoeLocation: Hashable, Codable, Sendable {
    /// In the home atoll, waiting to launch.
    case home
    /// At sea on this cell.
    case sea(Hex)
    /// Landed on the rival atoll (R-10); out of play.
    case landed
}

public struct CanoeState: Hashable, Codable, Sendable {
    public let owner: PlayerID
    public let location: CanoeLocation
    /// R-9: true exactly when at sea on a cell of strength 0 (INV-8).
    public let becalmed: Bool

    public init(owner: PlayerID, location: CanoeLocation, becalmed: Bool) {
        self.owner = owner
        self.location = location
        self.becalmed = becalmed
    }
}
