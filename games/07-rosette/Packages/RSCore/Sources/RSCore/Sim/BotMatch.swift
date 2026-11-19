// MARK: - BotMatch

/// Deterministic bot-vs-bot match driver: like `RandomMatch`, but choices
/// come from `MatchBot` bots — the heuristic `RosetteBot` personalities, or
/// RSAI's table and expectiminimax bots (ADR-0010). Used by the circuit
/// simulation (G3: bot circuit runs; G4: AI completion metrics) and by tests
/// that exercise bot behaviour. Three independent streams derive from one
/// seed (dice, omen, and driver bookkeeping) so replaying the recorded
/// actions through the reducer alone reproduces the match bit for bit.
public enum BotMatch {
    /// The full record of one played match.
    public struct Record: Sendable {
        public let actions: [Action]
        public let events: [Event]
        public let finalState: MatchState
    }

    /// Play one full match between two bots. On fresh turns the driver asks
    /// the bot whether to offer a double before rolling (R-10) and, on a
    /// pending double, asks the decider to accept or concede; otherwise it
    /// rolls and lets the bot choose among the legal moves. Omens are held
    /// but not played by the driver (P5 wires omen play into the UI flow;
    /// the driver keeps them pending for the recorded replay).
    ///
    /// `diceSequence` (P5 daily match): a fixed dice stream that drives
    /// every roll before the seeded RNG; the k-th roll is the k-th value
    /// for every player facing the same sequence.
    public static func play(
        seed: UInt64,
        ruleset: RuleSet,
        dice: DiceModel,
        stake: Int,
        bot0: any MatchBot,
        bot1: any MatchBot,
        fortunes: [FortuneSquare] = [],
        omens0: [Omen] = [],
        omens1: [Omen] = [],
        maxCube: Int = 64,
        maxActions: Int = 100_000,
        diceSequence: [Int]? = nil,
        onAction: ((Action, PlayerID) -> Void)? = nil
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
        // A caller-supplied dice sequence (the daily match) drives every
        // roll before the seeded RNG does; exhaustion falls back to the RNG.
        let diceSource: DiceSource? = diceSequence.map { DiceSource(values: $0) }
        var actions: [Action] = []
        var events: [Event] = []

        for _ in 0..<maxActions {
            if state.isComplete { break }
            let action: Action
            let actor: PlayerID
            if state.doubleOffered {
                // A pending double: the decider (the opponent of the player
                // who offered) accepts or concedes (R-10).
                let decider: PlayerID = state.currentPlayer == .player0 ? .player1 : .player0
                actor = decider
                let bot = decider == .player0 ? bot0 : bot1
                var pickRng = SeededRNG(
                    seed: seed &+ UInt64(state.plies) &+ 0x2545_F491_4F6C_DD1D)
                action =
                    bot.decideDouble(state: state, rng: &pickRng)
                    ? .acceptDouble : .concede
            } else if !state.hasRolled {
                // A fresh turn: first omen play (R-12) — the bot may invoke
                // a held omen before rolling, since the effects shape the
                // upcoming roll (re-roll, split, unsafe rosettes). Then the
                // cube question (R-10), then the roll.
                actor = state.currentPlayer
                let bot = state.currentPlayer == .player0 ? bot0 : bot1
                var pickRng = SeededRNG(
                    seed: seed &+ UInt64(state.plies) &+ 0x2545_F491_4F6C_DD1D)
                let held = state.omensHeld[state.currentPlayer] ?? []
                if state.pendingOmen == nil, !held.isEmpty,
                    let omen = bot.chooseOmen(state: state, options: held, rng: &pickRng),
                    held.contains(omen)
                {
                    action = .playOmen(omenId: omen.id)
                } else if canOfferDouble(in: state, maxCube: maxCube),
                    bot.wantsDouble(state: state, rng: &pickRng)
                {
                    action = .offerDouble
                } else {
                    action = .roll
                }
            } else {
                actor = state.currentPlayer
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
                        from: state,
                        moves: moves,
                        rng: &pickRng
                    )
                else {
                    throw RuleError.illegalAction("Bot returned no move with legal moves available")
                }
                action = .move(move.piece)
            }
            let result = try Reducer.apply(
                action,
                to: state,
                rng: &rng,
                omenRng: &omenRng,
                diceSource: diceSource
            )
            state = result.state
            actions.append(action)
            events.append(contentsOf: result.events)
            onAction?(action, actor)
        }

        guard state.isComplete else {
            throw RuleError.illegalAction("Match did not complete within \(maxActions) actions")
        }
        return Record(actions: actions, events: events, finalState: state)
    }

    /// Whether the current player may offer a double right now: the cube is
    /// not dead (R-22 Crawford), no double has been offered or accepted this
    /// turn (R-21), the player owns the cube or it is centred, and the value
    /// may not pass `maxCube` (R-10).
    public static func canOfferDouble(in state: MatchState, maxCube: Int = 64) -> Bool {
        !state.cubeDead
            && !state.hasDoubledThisTurn
            && state.cube.validateOffer(by: state.currentPlayer, maxCube: maxCube) == nil
    }
}
