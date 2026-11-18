import Foundation
import RSCore

/// The tier-3 optimal bot (§7, ADR-0010): when the solved table covers the
/// current state it decides by table lookup, otherwise by bounded
/// expectiminimax. Cube decisions use Finkel's equity thresholds (double
/// at 70% or more, take at 25% or more). Omen play evaluates each held
/// omen by the same equity source and plays the best strictly-improving
/// candidate.
///
/// All decisions are deterministic: the seeded stream is accepted but not
/// consumed, so equal states always produce equal choices (INV-4).
public struct OptimalBot: MatchBot, Sendable {

    /// The solved table, when one ships or has been computed on device.
    public let table: SolvedTableStore

    /// The expectiminimax search used where the table does not cover.
    public let emm: Expectiminimax

    public init(table: SolvedTableStore = SolvedTableStore(), depth: Int = 3) {
        self.table = table
        self.emm = Expectiminimax(depth: depth)
    }

    /// The equity for `me`: the table's probability for the roller about
    /// to roll when it covers this state, else the expectiminimax value of
    /// the chance node. `searchDepth` defaults to the bot's configured
    /// depth; cube decisions pass 2 (ADR-0010) to keep fresh-turn equity
    /// inside the latency budget.
    public func equity(
        of state: MatchState, for me: PlayerID, searchDepth: Int? = nil
    ) -> Double? {
        if let position = TableBridge.position(from: state),
            let probability = table.winProbability(forRoller: position)
        {
            return state.currentPlayer == me ? probability : 1 - probability
        }
        return emm.value(of: state, for: me, searchDepth: searchDepth)
    }

    public func chooseMove(from state: MatchState, moves: [Move], rng: inout SeededRNG) -> Move? {
        _ = rng
        guard !moves.isEmpty else { return nil }
        guard let (move, _) = emm.bestMove(from: state, for: state.currentPlayer) else {
            return moves[0]
        }
        return move
    }

    public func decideDouble(state: MatchState, rng: inout SeededRNG) -> Bool {
        _ = rng
        let decider: PlayerID = state.currentPlayer == .player0 ? .player1 : .player0
        guard let equity = equity(of: state, for: decider, searchDepth: 2) else { return true }
        return CubePolicy.shouldTake(winProbability: equity)
    }

    public func wantsDouble(state: MatchState, rng: inout SeededRNG) -> Bool {
        _ = rng
        // R-21: the cube may be used at most once per turn; never offer when
        // this turn already doubled or the cube is dead. R-10: only the cube
        // owner (or anyone, when centred) may offer.
        guard !state.hasDoubledThisTurn, !state.cubeDead else { return false }
        guard state.cube.owner == -1 || state.cube.owner == state.currentPlayer.rawValue else {
            return false
        }
        guard let equity = equity(of: state, for: state.currentPlayer, searchDepth: 2)
        else { return false }
        return CubePolicy.shouldOffer(winProbability: equity)
    }

    public func chooseOmen(
        state: MatchState,
        options: [Omen],
        rng: inout SeededRNG
    ) -> Omen? {
        _ = rng
        let me = state.currentPlayer
        guard let baseline = equity(of: state, for: me) else { return nil }
        var best: (omen: Omen, value: Double)?
        for omen in options.sorted(by: { $0.id < $1.id }) {
            guard let (played, _) = try? Reducer.applyOmen(to: state, omenId: omen.id)
            else { continue }
            guard let value = equity(of: played, for: me) else { continue }
            // Play an omen only when it clearly improves the position; a
            // held omen otherwise keeps its later-turn value.
            if value > baseline + 0.02, value > (best?.value ?? 0) {
                best = (omen, value)
            }
        }
        return best?.omen
    }
}

/// The tier-2 variant bot (§7, ADR-0010): moves by bounded expectiminimax
/// (depth 2–3), cube decisions by Monte Carlo rollouts through the real
/// reducer (200 rollouts for cube decisions, 64 per omen candidate per
/// A.5), omens by the same rollout evaluation.
///
/// Determinism (INV-4): rollout batches derive their streams from a seed
/// mixed with the decision state's replay hash, so the same state always
/// produces the same batch and the same choice.
public struct VariantBot: MatchBot, Sendable {

    public let emm: Expectiminimax
    public let cubeRollouts: Int
    public let omenRollouts: Int
    public let doubleThreshold: Double
    public let takeThreshold: Double
    public let salt: UInt64

    public init(
        depth: Int = 3,
        cubeRollouts: Int = 200,
        omenRollouts: Int = 64,
        doubleThreshold: Double = CubePolicy.doubleThreshold,
        takeThreshold: Double = CubePolicy.takeThreshold,
        salt: UInt64 = 0x5EED_C0DE_0000_0001
    ) {
        self.emm = Expectiminimax(depth: depth)
        self.cubeRollouts = cubeRollouts
        self.omenRollouts = omenRollouts
        self.doubleThreshold = doubleThreshold
        self.takeThreshold = takeThreshold
        self.salt = salt
    }

    /// The seed for the rollout batch at `state` — state-derived so the
    /// batch is reproducible (INV-4) without depending on the match stream.
    func rolloutSeed(_ state: MatchState) -> UInt64 {
        state.stateHash &+ salt
    }

    public func chooseMove(from state: MatchState, moves: [Move], rng: inout SeededRNG) -> Move? {
        _ = rng
        guard !moves.isEmpty else { return nil }
        guard let (move, _) = emm.bestMove(from: state, for: state.currentPlayer) else {
            return moves[0]
        }
        return move
    }

    public func decideDouble(state: MatchState, rng: inout SeededRNG) -> Bool {
        _ = rng
        let decider: PlayerID = state.currentPlayer == .player0 ? .player1 : .player0
        let result = Rollouts.run(
            from: state, me: decider, count: cubeRollouts, seed: rolloutSeed(state))
        return result.winRate >= takeThreshold
    }

    public func wantsDouble(state: MatchState, rng: inout SeededRNG) -> Bool {
        _ = rng
        // R-21: the cube may be used at most once per turn; never offer when
        // this turn already doubled or the cube is dead.
        guard !state.hasDoubledThisTurn, !state.cubeDead else { return false }
        guard state.cube.owner == -1 || state.cube.owner == state.currentPlayer.rawValue else {
            return false
        }
        let result = Rollouts.run(
            from: state, me: state.currentPlayer, count: cubeRollouts,
            seed: rolloutSeed(state))
        return result.winRate >= doubleThreshold
    }

    public func chooseOmen(
        state: MatchState,
        options: [Omen],
        rng: inout SeededRNG
    ) -> Omen? {
        _ = rng
        let me = state.currentPlayer
        let baseline = Rollouts.run(
            from: state, me: me, count: omenRollouts, seed: rolloutSeed(state)
        ).winRate
        var best: (omen: Omen, value: Double)?
        for omen in options.sorted(by: { $0.id < $1.id }) {
            guard let (played, _) = try? Reducer.applyOmen(to: state, omenId: omen.id)
            else { continue }
            // A stable per-omen salt: FNV-1a over the id (Swift's hashValue
            // is not stable across processes, so it must not seed games).
            var salt = FNV1a64.digest(Data(omen.id.utf8))
            salt = salt &* 0x9E37_79B9_7F4A_7C15
            let value = Rollouts.run(
                from: played, me: me, count: omenRollouts,
                seed: rolloutSeed(state) &+ salt
            ).winRate
            if value > baseline + 0.02, value > (best?.value ?? 0) {
                best = (omen, value)
            }
        }
        return best?.omen
    }
}
