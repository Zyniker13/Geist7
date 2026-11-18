// MARK: - MatchBot

/// A bot that can be driven by `BotMatch`. The heuristic `RosetteBot`
/// conforms directly; RSAI's table and expectiminimax bots conform too, so
/// one driver serves every tier (ROADMAP §7; ADR-0011).
///
/// The driver owns the game flow: it rolls on fresh turns, computes the
/// legal moves, and asks the bot only for its choices — a move, an omen to
/// play, a cube offer, and an answer to a pending double. All methods must
/// be deterministic given the seeded stream (INV-4: recorded actions replay
/// through the reducer alone, so bots never touch the dice or omen streams).
public protocol MatchBot {
    /// Choose a move from the legal moves. The driver guarantees a
    /// non-empty list; returning nil is a bot failure the driver reports.
    func chooseMove(
        from moves: [Move],
        pieces: [Piece],
        track: Track,
        rng: inout SeededRNG
    ) -> Move?

    /// Choose a move given the full state (the driver's preferred entry
    /// point; search bots need the state, the dice, and the pending omen).
    /// The default bridges to the piece-list form.
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
}

public extension MatchBot {
    func chooseMove(
        from state: MatchState,
        moves: [Move],
        rng: inout SeededRNG
    ) -> Move? {
        chooseMove(from: moves, pieces: state.pieces, track: state.track, rng: &rng)
    }

    /// Default cube policy: always accept, never offer (the pre-P4
    /// behaviour; personalities and equity policies override).
    func decideDouble(state: MatchState, rng: inout SeededRNG) -> Bool { true }
    func wantsDouble(state: MatchState, rng: inout SeededRNG) -> Bool { false }
}

extension RosetteBot: MatchBot {}
