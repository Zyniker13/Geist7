// Action.swift — the four actions a player may take, plus events.
//
// One player action per turn (R-11 turn cycle). Actions are small
// value types; the reducer validates them against GameState and turns
// legal ones into Events.

/// One player action (R-7, R-17, R-8, R-19, R-11). `sail` carries the
/// full ordered path of cells the canoe ENTERS (not including the
/// start cell) so a replay is exact without recomputing player intent
/// (ADR-0012).
public enum Action: Hashable, Codable, Sendable {
    /// R-7: place one island token on an empty sea cell.
    case placeIsland(Hex)
    /// R-17: launch a home canoe onto a strength ≥ 1 cell adjacent to
    /// the home atoll.
    case launch(Hex)
    /// R-8: sail a canoe along an ordered path.
    case sail(CanoeID, [Hex])
    /// R-19: tow a becalmed canoe one step to an adjacent empty cell.
    case tow(CanoeID, Hex)
    /// R-11: give up the turn; legal only when nothing else is (ADR-0011).
    case pass

    public var isPass: Bool {
        if case .pass = self { return true }
        return false
    }
}

/// What a legal action did (R-7, R-17, R-8, R-19, R-9, R-10, R-11).
/// Events are the observable trace of a turn; the replay log stores
/// actions, and events let the UI and tests verify outcomes without
/// re-deriving them.
public enum Event: Hashable, Codable, Sendable {
    case islandPlaced(Hex)
    case launched(CanoeID, Hex)
    case sailed(CanoeID, [Hex])
    case towed(CanoeID, Hex)
    /// A canoe just becalmed: now at sea on a strength-0 cell (R-9).
    case becameBecalmed(CanoeID)
    /// A canoe landed on the rival atoll and left the board (R-10).
    case landed(CanoeID)
    /// The game ended: outright win or tie-break result (R-11).
    case gameEnded(GameStatus)
}

/// Why an action is illegal. Every reason maps to exactly one rule
/// text in docs/RULES.md; tests reference these by rule id.
public enum IllegalReason: Hashable, Codable, Sendable {
    // Island placement (R-7, R-21)
    case cellNotInOcean(Hex)
    case cellOccupied(Hex)
    case adjacentToIsland(Hex)
    case adjacentToAtoll(Hex)
    case poolEmpty
    case fullyEncloses(CanoeID)
    // Launch (R-17)
    case noHomeCanoe(PlayerID)
    case notAdjacentToHomeAtoll(Hex)
    case cellStrengthZero(Hex)
    // Sail (R-8, R-9, R-18)
    case notOwnedByMover(CanoeID)
    case notOnBoard(CanoeID)
    case becalmedCanoe(CanoeID)
    case pathEmpty
    case badPathStep(Hex, Hex)
    case cellHasCanoe(Hex)
    /// A path cell carries no swell (R-8: every cell the canoe
    /// enters must lie on at least one swell).
    case pathCellCalm(Hex)
    case pathTooLong(cost: Int)
    case nodeExit(Hex)
    case landingMidPath(Hex)
    case landingFromNode(Hex)
    // Tow (R-19)
    case notBecalmed(CanoeID)
    case towTargetIllegal(Hex)
    case noAdjacentTower(CanoeID)
    // Pass (R-11, ADR-0011)
    case passNotForced
    // Reducer
    case gameAlreadyOver
}

/// The error the reducer throws for an illegal action.
public struct ReducerError: Error, Hashable, Sendable {
    public let action: Action
    public let reason: IllegalReason

    public init(action: Action, reason: IllegalReason) {
        self.action = action
        self.reason = reason
    }
}
