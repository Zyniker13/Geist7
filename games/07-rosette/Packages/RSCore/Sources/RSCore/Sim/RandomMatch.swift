// MARK: - RandomMatch

/// Deterministic random-legal-move match driver used by the headless sim
/// CLI, golden replays, and invariant property tests.
///
/// Three independent streams derive from one seed: dice draws (`rng`), omen
/// draws (`omenRng`, INV-7), and the driver's own move picks (`pickRng`) so
/// that replaying recorded actions through the reducer alone reproduces the
/// match bit for bit.
public enum RandomMatch {
    /// The omen stream seed derived from a match seed.
    public static func omenSeed(for seed: UInt64) -> UInt64 {
        seed &+ 0x9E37_79B9_7F4A_7C15
    }

    /// The driver's pick stream seed derived from a match seed.
    public static func pickSeed(for seed: UInt64) -> UInt64 {
        seed &+ 0x2545_F491_4F6C_DD1D
    }

    /// The full record of one played match.
    public struct Record: Sendable {
        public let actions: [Action]
        public let events: [Event]
        public let finalState: MatchState
    }

    /// Play one full match with random legal moves; a pending double is
    /// always accepted. Throws if the match does not complete.
    public static func play(
        seed: UInt64,
        ruleset: RuleSet = .finkel,
        dice: DiceModel = .tetra4,
        stake: Int = 2,
        maxActions: Int = 100_000
    ) throws -> Record {
        var state = MatchState(
            ruleset: ruleset,
            track: ruleset.makeTrack(),
            dice: dice,
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
            omensHeld: [:],
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
        var rng = SeededRNG(seed: seed)
        var omenRng = SeededRNG(seed: omenSeed(for: seed))
        var pickRng = SeededRNG(seed: pickSeed(for: seed))
        var actions: [Action] = []
        var events: [Event] = []

        for _ in 0..<maxActions {
            if state.isComplete { break }
            let action: Action
            if state.doubleOffered {
                action = .acceptDouble
            } else if !state.hasRolled {
                action = .roll
            } else {
                let moves = MoveGen.legalMoves(
                    for: state.currentPlayer,
                    amount: state.diceValue ?? 0,
                    pieces: state.pieces,
                    track: state.track,
                    rules: state.ruleset,
                    unsafeRosettesActive: state.pendingOmen?.effect.kind == .unsafeRosettes
                )
                guard !moves.isEmpty else {
                    throw RuleError.illegalAction("No legal moves but the turn did not pass")
                }
                action = .move(moves[Int(pickRng.next(UInt64(moves.count)))].piece)
            }
            let result = try Reducer.apply(action, to: state, rng: &rng, omenRng: &omenRng)
            state = result.state
            actions.append(action)
            events.append(contentsOf: result.events)
        }

        guard state.isComplete else {
            throw RuleError.illegalAction("Match did not complete within \(maxActions) actions")
        }
        return Record(actions: actions, events: events, finalState: state)
    }
}
