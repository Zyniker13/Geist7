import Foundation
import RSCore

/// Monte Carlo rollouts through the real reducer (§7: variant cube decisions
/// "via 200-rollout Monte Carlo"; A.5: omen policy "64 rollouts per
/// candidate"). Both sides in a rollout play uniformly random legal moves
/// and answer doubles by the cube policy's equity inequality; omens are not
/// replayed (the omen being evaluated is applied once at the start).
public enum Rollouts {

    /// The result of a rollout batch.
    public struct Result: Sendable, Equatable {
        /// Wins for the measured player.
        public let wins: Int
        /// Of those wins, how many were gammons (the loser bore off nothing).
        public let gammonWins: Int
        /// Losses for the measured player.
        public let losses: Int
        /// Of those losses, how many were gammons against the measured player.
        public let gammonLosses: Int
        /// Total plies rolled out (for cost accounting).
        public let plies: Int

        public var winRate: Double { count > 0 ? Double(wins) / Double(count) : 0 }
        public var gammonWinRate: Double { count > 0 ? Double(gammonWins) / Double(count) : 0 }
        public var gammonLossRate: Double { count > 0 ? Double(gammonLosses) / Double(count) : 0 }
        /// Number of completed rollouts.
        public var count: Int { wins + losses }
    }

    /// Play `count` rollouts from `state`, measuring from `me`'s
    /// perspective. Each rollout derives its streams from one master seed so
    /// batches are reproducible.
    public static func run(
        from state: MatchState,
        me: PlayerID,
        count: Int,
        seed: UInt64
    ) -> Result {
        var wins = 0
        var gammonWins = 0
        var losses = 0
        var gammonLosses = 0
        var plies = 0

        for index in 0..<count {
            let base = seed &+ UInt64(index) &* 0x9E37_79B9_7F4A_7C15
            var rng = SeededRNG(seed: base)
            var omenRng = SeededRNG(seed: base &+ 1)
            var pickRng = SeededRNG(seed: base &+ 2)
            var current = state
            var steps = 0
            while !current.isComplete && steps < 100_000 {
                steps += 1
                let action = Rollouts.nextAction(
                    in: current, rng: &pickRng, omenRng: &omenRng)
                guard let action,
                    let result = try? Reducer.apply(
                        action, to: current, rng: &rng, omenRng: &omenRng)
                else { break }
                current = result.state
            }
            plies += steps
            if current.isComplete, let outcome = current.outcome {
                if outcome.winner == me {
                    wins += 1
                    if outcome.gammon { gammonWins += 1 }
                } else {
                    losses += 1
                    if outcome.gammon { gammonLosses += 1 }
                }
            }
        }
        return Result(
            wins: wins, gammonWins: gammonWins, losses: losses,
            gammonLosses: gammonLosses, plies: plies)
    }

    /// The rollout policy's next action: answer pending doubles by equity,
    /// roll on fresh turns, move uniformly at random otherwise.
    static func nextAction(
        in state: MatchState,
        rng: inout SeededRNG,
        omenRng: inout SeededRNG
    ) -> Action? {
        if state.isComplete { return nil }
        if state.doubleOffered {
            // Random-play take point: the equity inequality with no gammon
            // knowledge — take when the win rate is at least 25%. The inner
            // rollout policy answers from the cheap static evaluator (§7);
            // the bot's top-level take decision is the one that rolls out.
            let decider: PlayerID = state.currentPlayer == .player0 ? .player1 : .player0
            return Evaluator.winProbability(of: state, for: decider) >= 0.25
                ? .acceptDouble : .concede
        }
        if !state.hasRolled { return .roll }
        let unsafeActive = state.pendingOmen?.effect.kind == .unsafeRosettes
        let moves = MoveGen.legalMoves(
            for: state.currentPlayer,
            amount: state.diceValue ?? 0,
            pieces: state.pieces,
            track: state.track,
            rules: state.ruleset,
            unsafeRosettesActive: unsafeActive,
            allowEntry: !state.splitActive
        )
        guard !moves.isEmpty else { return nil }
        return .move(moves[Int(rng.next(UInt64(moves.count)))].piece)
    }
}
