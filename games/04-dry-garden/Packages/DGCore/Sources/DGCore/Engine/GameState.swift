// GameState.swift — the full game state value type (S1.1, R-1–R-3).
//
// A value type, Codable/Equatable/Hashable/Sendable (_CONVENTIONS
// §4.2). State changes happen only through the reducer.

public struct GameState: Codable, Hashable, Sendable {
    /// Which courtyard is in play (R-1; content resolves the id).
    public var courtyardID: String
    /// The placed stones, in placement order.
    public var stones: [Stone]
    /// The raked lines, in raking order.
    public var rakes: [RakeLine]
    /// Remaining stone supplies per player (R-2).
    public var supplies: [PlayerID: Supply]
    /// Remaining rake lines per player (R-2: at most rakesPerPlayer).
    public var rakesUsed: [PlayerID: Int]
    /// Player to move.
    public var toMove: PlayerID
    /// Consecutive pass count (R-15's end condition: 2 ends the game).
    public var passes: Int
    /// Season id (R-29; seasons arrive in P3/P5, P1 carries the field).
    public var season: String
    /// Total plies played (used by seasons' fixed turns, R-29).
    public var plies: Int
    /// True once the game has ended (R-15).
    public var isOver: Bool
    /// Scores at game end (R-14); empty until over.
    public var finalScores: [PlayerID: Int]

    public init(
        courtyardID: String, stones: [Stone] = [], rakes: [RakeLine] = [],
        supplies: [PlayerID: Supply] = [:],
        rakesUsed: [PlayerID: Int] = [:],
        toMove: PlayerID = .one, passes: Int = 0, season: String = "spring",
        plies: Int = 0, isOver: Bool = false,
        finalScores: [PlayerID: Int] = [:]
    ) {
        self.courtyardID = courtyardID
        self.stones = stones
        self.rakes = rakes
        self.supplies = supplies
        self.rakesUsed = rakesUsed
        self.toMove = toMove
        self.passes = passes
        self.season = season
        self.plies = plies
        self.isOver = isOver
        self.finalScores = finalScores
    }

    /// A fresh state: standard supplies (R-2), P1 to move (R-3).
    public static func fresh(
        courtyardID: String, balance: Balance = .standard()
    ) -> GameState {
        GameState(
            courtyardID: courtyardID,
            supplies: [
                .one: Supply(
                    large: balance.supply[.large] ?? 2,
                    medium: balance.supply[.medium] ?? 3,
                    small: balance.supply[.small] ?? 4),
                .two: Supply(
                    large: balance.supply[.large] ?? 2,
                    medium: balance.supply[.medium] ?? 3,
                    small: balance.supply[.small] ?? 4),
            ],
            rakesUsed: [.one: 0, .two: 0])
    }

    /// The stones of one player.
    public func stones(of player: PlayerID) -> [Stone] {
        stones.filter { $0.owner == player }
    }

    /// The stone standing on a cell, if any.
    public func stone(at cell: Hex) -> Stone? {
        stones.first { $0.cell == cell }
    }

    /// Cells already covered by any rake line (R-5: cannot receive
    /// stones; R-21: crossing rules consult single-cell overlap).
    public var rakedCells: [Hex: PlayerID] {
        var result: [Hex: PlayerID] = [:]
        for rake in rakes {
            for cell in rake.cells {
                // R-21: a crossing cell belongs to neither rake for
                // future crossings; the FIRST raker keeps the record,
                // which is what "raked by the opponent" tests against.
                if result[cell] == nil {
                    result[cell] = rake.owner
                }
            }
        }
        return result
    }

    /// True when the player has no stones left of any size (R-6's
    /// "no legal placement" precondition contributor).
    public func supplySpent(_ player: PlayerID) -> Bool {
        (supplies[player] ?? Supply(large: 0, medium: 0, small: 0)).isSpent
    }

    /// True when the player has used all their rake lines (R-2, R-6).
    public func rakesSpent(_ player: PlayerID, balance: Balance) -> Bool {
        (rakesUsed[player] ?? 0) >= balance.rakesPerPlayer
    }
}
