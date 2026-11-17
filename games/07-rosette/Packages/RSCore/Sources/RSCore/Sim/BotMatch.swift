// MARK: - BotMatch

/// Deterministic bot-vs-bot match driver: like `RandomMatch`, but move
/// choices come from `RosetteBot` personalities instead of uniform picks.
/// Used by the circuit simulation (G3: bot circuit runs) and by tests that
/// exercise personality behaviour. Three independent streams derive from one
/// seed (dice, omen, and driver bookkeeping) so replaying the recorded
/// actions through the reducer alone reproduces the match bit for bit.
public enum BotMatch {
    /// The full record of one played match.
    public struct Record: Sendable {
        public let actions: [Action]
        public let events: [Event]
        public let finalState: MatchState
    }

    /// Play one full match between two bots. The cube is left centred and
    /// untouched (cube play enters with the P4 policies); omens are held but
    /// not played by the driver.
    public static func play(
        seed: UInt64,
        ruleset: RuleSet,
        dice: DiceModel,
        stake: Int,
        bot0: RosetteBot,
        bot1: RosetteBot,
        fortunes: [FortuneSquare] = [],
        omens0: [Omen] = [],
        omens1: [Omen] = [],
        maxActions: Int = 100_000
    ) throws -> Record {
        var state = MatchState.newMatch(
            ruleset: ruleset,
            dice: dice,
            stake: stake,
            omens: [],
            fortunes: fortunes
        )
        // Give each side its held omens.
        state.omensHeld[.player0] = omens0
        state.omensHeld[.player1] = omens1

        var rng = SeededRNG(seed: seed)
        var omenRng = SeededRNG(seed: seed &+ 0x9E37_79B9_7F4A_7C15)
        var actions: [Action] = []
        var events: [Event] = []

        for _ in 0..<maxActions {
            if state.isComplete { break }
            let action: Action
            if !state.hasRolled {
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
                var pickRng = SeededRNG(seed: seed &+ UInt64(state.plies) &+ 0x2545_F491_4F6C_DD1D)
                let bot = state.currentPlayer == .player0 ? bot0 : bot1
                guard
                    let move = bot.chooseMove(
                        from: moves,
                        pieces: state.pieces,
                        track: state.track,
                        rng: &pickRng
                    )
                else {
                    throw RuleError.illegalAction("Bot returned no move with legal moves available")
                }
                action = .move(move.piece)
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
