// MARK: - MatchState

/// The complete state of a match. Immutable value type; all changes go
/// through `Reducer`.
public struct MatchState: Sendable, Equatable {
    /// The ruleset in play.
    public let ruleset: RuleSet
    /// The board track.
    public let track: Track
    /// The dice model used for rolls (R-2, R-17).
    public let dice: DiceModel
    /// All pieces (ids are per owner: player 0 and player 1 each use 0..<pieces).
    public var pieces: [Piece]
    /// Whose turn it is.
    public var currentPlayer: PlayerID
    /// The amount the current player still must move this turn (nil before rolling).
    public var diceValue: Int?
    /// Pieces that can still move this turn.
    public var movablePieceIds: Set<PieceID>
    /// Whether the current player earned another roll by landing on a rosette (R-6).
    public var extraRoll: Bool
    /// The current stake (R-9).
    public var stake: Stake
    /// The doubling cube (R-10).
    public var cube: DoublingCube
    /// Whether the cube is dead for this match (R-22 Crawford).
    public var cubeDead: Bool
    /// Whether a double offer is pending this turn (R-10, R-21).
    public var doubleOffered: Bool
    /// Whether a double was offered or accepted this turn (R-21: only once).
    public var hasDoubledThisTurn: Bool
    /// Omens held by each player (R-12: up to 2 each).
    public var omensHeld: [PlayerID: [Omen]]
    /// The omen each player has played this match (R-12: one per match).
    public var omensPlayed: [PlayerID: String]
    /// The omen played for the current turn, not yet consumed.
    public var pendingOmen: Omen?
    /// Remaining amount for the second half of a split move (R-12).
    public var splitRemaining: Int?
    /// Whether the current turn is a split turn awaiting its second move.
    public var splitActive: Bool
    /// Whether the current player has rolled this turn.
    public var hasRolled: Bool
    /// Pieces borne off by each player.
    public var borneOff: [PlayerID: Int]
    /// Total plies (individual piece moves).
    public var plies: Int
    /// Whether the match is over (R-8).
    public var isComplete: Bool
    /// The match outcome (once complete).
    public var outcome: Outcome?

    public init(
        ruleset: RuleSet,
        track: Track,
        dice: DiceModel,
        pieces: [Piece],
        currentPlayer: PlayerID,
        diceValue: Int?,
        movablePieceIds: Set<PieceID>,
        extraRoll: Bool,
        stake: Stake,
        cube: DoublingCube,
        cubeDead: Bool,
        doubleOffered: Bool,
        hasDoubledThisTurn: Bool,
        omensHeld: [PlayerID: [Omen]],
        omensPlayed: [PlayerID: String],
        pendingOmen: Omen?,
        splitRemaining: Int?,
        splitActive: Bool,
        hasRolled: Bool,
        borneOff: [PlayerID: Int],
        plies: Int,
        isComplete: Bool,
        outcome: Outcome?
    ) {
        self.ruleset = ruleset
        self.track = track
        self.dice = dice
        self.pieces = pieces
        self.currentPlayer = currentPlayer
        self.diceValue = diceValue
        self.movablePieceIds = movablePieceIds
        self.extraRoll = extraRoll
        self.stake = stake
        self.cube = cube
        self.cubeDead = cubeDead
        self.doubleOffered = doubleOffered
        self.hasDoubledThisTurn = hasDoubledThisTurn
        self.omensHeld = omensHeld
        self.omensPlayed = omensPlayed
        self.pendingOmen = pendingOmen
        self.splitRemaining = splitRemaining
        self.splitActive = splitActive
        self.hasRolled = hasRolled
        self.borneOff = borneOff
        self.plies = plies
        self.isComplete = isComplete
        self.outcome = outcome
    }

    /// A new Finkel-ruleset match (R-1: 7 pieces each, 14-square path,
    /// rosettes at path positions 4, 8 and 14, the shared one safe).
    public static func finkelMatch(stake: Int, omens: [Omen]) -> MatchState {
        let ruleset = RuleSet.finkel
        return MatchState(
            ruleset: ruleset,
            track: ruleset.makeTrack(),
            dice: .tetra4,
            pieces: (0..<ruleset.pieces).flatMap { id in
                PlayerID.allCases.map { Piece.making(id: id, owner: $0) }
            },
            currentPlayer: .player0,
            diceValue: nil,
            movablePieceIds: [],
            extraRoll: false,
            stake: Stake(value: stake),
            cube: .centered,
            cubeDead: false,
            doubleOffered: false,
            hasDoubledThisTurn: false,
            omensHeld: [.player0: omens, .player1: []],
            omensPlayed: [:],
            pendingOmen: nil,
            splitRemaining: nil,
            splitActive: false,
            hasRolled: false,
            borneOff: [.player0: 0, .player1: 0],
            plies: 0,
            isComplete: false,
            outcome: nil
        )
    }

    /// INV-1: for each player, waiting + on-board + borne off equals the
    /// ruleset's piece count, and the borne-off counter matches the pieces
    /// actually marked borne off.
    public var pieceConservationValid: Bool {
        for player in PlayerID.allCases {
            let waiting = pieces.filter { $0.owner == player && $0.position == -1 }.count
            let onBoard = pieces.filter { $0.owner == player && $0.position >= 0 }.count
            let off = pieces.filter { $0.owner == player && $0.position == -2 }.count
            if waiting + onBoard + off != ruleset.pieces { return false }
            if (borneOff[player] ?? 0) != off { return false }
        }
        return true
    }

    /// A deterministic hash of the gameplay-relevant state (INV-4). FNV-1a
    /// over a fixed field order: `Hasher` is seeded per process and must not
    /// be used, so hashes stay stable across runs and replays.
    public var stateHash: UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        func mix(_ value: UInt64) {
            hash ^= value
            hash &*= 0x0000_0100_0000_01B3
        }
        func mixInt(_ value: Int) {
            mix(UInt64(bitPattern: Int64(value)))
        }
        func mixString(_ string: String) {
            for byte in string.utf8 {
                mix(UInt64(byte))
            }
            mix(0xFF)
        }
        for piece in pieces {
            mixInt(piece.owner.rawValue)
            mixInt(piece.id)
            mixInt(piece.position)
        }
        mixInt(currentPlayer.rawValue)
        mixInt(diceValue ?? -99)
        mixInt(borneOff[.player0] ?? -1)
        mixInt(borneOff[.player1] ?? -1)
        mixInt(plies)
        mixInt(extraRoll ? 1 : 0)
        mixInt(cube.value)
        mixInt(cube.owner)
        mixInt(cubeDead ? 1 : 0)
        mixInt(doubleOffered ? 1 : 0)
        mixInt(hasDoubledThisTurn ? 1 : 0)
        mixInt(stake.value)
        mixInt(splitActive ? 1 : 0)
        mixInt(splitRemaining ?? -99)
        if let pendingOmen {
            mixString(pendingOmen.id)
        } else {
            mixInt(-99)
        }
        for player in PlayerID.allCases {
            if let played = omensPlayed[player] {
                mixString(played)
            } else {
                mixInt(-98)
            }
            for omen in omensHeld[player] ?? [] {
                mixString(omen.id)
            }
            mixInt(-97)
        }
        return hash
    }
}
