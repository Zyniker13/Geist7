// MARK: - MatchBot

/// A bot that can be driven by `BotMatch`. The heuristic `RosetteBot`
/// conforms directly; RSAI's table and expectiminimax bots conform too, so
/// one driver serves every tier (ROADMAP §7; ADR-0010).
///
/// The driver owns the game flow: it rolls on fresh turns, computes the
/// legal moves, and asks the bot only for its choices — a move, an omen to
/// play, a cube offer, and an answer to a pending double. All methods must
/// be deterministic given the seeded stream (INV-4: recorded actions replay
/// through the reducer alone, so bots never touch the dice or omen streams).
public protocol MatchBot {
    /// Choose a move given the full state (the driver's preferred entry
    /// point; search bots need the state, the dice, and the pending omen).
    /// The driver guarantees a non-empty list; returning nil is a bot
    /// failure the driver reports.
    func chooseMove(
        from state: MatchState,
        moves: [Move],
        rng: inout SeededRNG
    ) -> Move?

    /// Answer a pending double as the decider (the opponent of the player
    /// who offered). `true` accepts (stake doubles, cube passes to the
    /// decider); `false` concedes and loses the current stake (R-10).
    func decideDouble(state: MatchState, rng: inout SeededRNG) -> Bool

    /// Whether to offer a double before rolling this turn (R-10). The
    /// driver checks eligibility first (cube ownership, R-21 once per turn,
    /// R-22 Crawford dead cube, the 64 cap) and asks only when offering is
    /// legal.
    func wantsDouble(state: MatchState, rng: inout SeededRNG) -> Bool

    /// Which held omen to play on a fresh turn before rolling (R-12), or
    /// nil to play none. The driver asks only when the player holds omens,
    /// nothing is pending, and the turn has not rolled yet. The default is
    /// to play none (the pre-P4 behaviour; equity policies override).
    func chooseOmen(
        state: MatchState,
        options: [Omen],
        rng: inout SeededRNG
    ) -> Omen?
}

extension MatchBot {
    /// The piece-list form, bridged to the state form for bots that only
    /// look at the pieces and the track (the pre-P4 heuristic bots).
    public func chooseMove(
        from moves: [Move],
        pieces: [Piece],
        track: Track,
        rng: inout SeededRNG
    ) -> Move? { nil }

    /// Default cube policy: always accept, never offer (the pre-P4
    /// behaviour; personalities and equity policies override).
    public func decideDouble(state: MatchState, rng: inout SeededRNG) -> Bool { true }
    public func wantsDouble(state: MatchState, rng: inout SeededRNG) -> Bool { false }

    /// Default omen policy: play none (the pre-P4 behaviour; equity
    /// policies override).
    public func chooseOmen(
        state: MatchState,
        options: [Omen],
        rng: inout SeededRNG
    ) -> Omen? { nil }
}
