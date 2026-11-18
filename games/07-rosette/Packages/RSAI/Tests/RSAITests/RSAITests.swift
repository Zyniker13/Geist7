import Foundation
import RSContent
import RSCore
import Testing

@testable import RSAI

// MARK: - Test support

/// A fresh pre-roll match state on the Finkel ruleset.
private func freshState(pieces: Int = 7) -> MatchState {
    MatchState(
        ruleset: .finkel,
        track: RuleSet.finkel.makeTrack(),
        dice: .tetra4,
        pieces: (0..<pieces).flatMap { id in
            PlayerID.allCases.map { Piece.making(id: id, owner: $0) }
        },
        currentPlayer: .player0,
        diceValue: nil,
        movablePieceIds: [],
        extraRoll: false,
        stake: Stake(value: 2),
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
}

/// A state rolled for the current player (dice set, moves available).
private func rolledState(pieces: Int = 7, amount: Int = 2) -> MatchState {
    var state = freshState(pieces: pieces)
    state.hasRolled = true
    state.diceValue = amount
    let moves = MoveGen.legalMoves(
        for: state.currentPlayer,
        amount: amount,
        pieces: state.pieces,
        track: state.track,
        rules: state.ruleset
    )
    state.movablePieceIds = Set(moves.map(\.piece))
    return state
}

@Suite("Evaluator")
struct EvaluatorTests {

    /// R-4 regression: own exposed pieces must REDUCE the score. P0's lone
    /// board piece on shared square 8 stands 3 steps ahead of P1's piece on
    /// square 5 (tetra4: p(3) = 4/16 = 0.25). All other pieces wait in hand,
    /// so pip and rosette terms cancel and the expected score is
    /// 2·(9 − 6) − 2·0.25 = 5.5. The inverted-sign bug produced 6.5.
    @Test func rawScoreWeightsOwnExposureNegatively() {
        var state = freshState()
        var pieces = state.pieces
        pieces[0].position = 8  // P0 piece, shared square, exposed to the piece 3 behind
        pieces[1].position = 5  // P1 piece, shared square, 3 steps behind P0's piece
        state.pieces = pieces
        let p3: Double = 4.0 / 16.0
        let raw = Evaluator.rawScore(of: state, for: .player0)
        #expect(abs(raw - (2.0 * 3.0 - 2.0 * p3)) < 1e-9)
    }
}

@Suite("CubePolicy")
struct CubePolicyTests {

    @Test func finkelThresholds() {
        #expect(CubePolicy.doubleThreshold == 0.70)
        #expect(CubePolicy.takeThreshold == 0.25)
        #expect(CubePolicy.doublePoint(aggression: 0) == 0.70)
    }

    @Test func offerBoundaries() {
        #expect(CubePolicy.shouldOffer(winProbability: 0.70))
        #expect(!CubePolicy.shouldOffer(winProbability: 0.69))
        #expect(CubePolicy.shouldOffer(winProbability: 0.95))
        #expect(!CubePolicy.shouldOffer(winProbability: 0.5, aggression: -25))
    }

    @Test func takeBoundaries() {
        #expect(CubePolicy.shouldTake(winProbability: 0.25))
        #expect(!CubePolicy.shouldTake(winProbability: 0.24))
    }

    @Test func doublePointClamps() {
        // Aggression moves the point down, caution up, both clamped.
        // Tolerance: the points are computed in binary floating point.
        func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }
        #expect(near(CubePolicy.doublePoint(aggression: 100), 0.50))
        #expect(near(CubePolicy.doublePoint(aggression: -100), 0.95))
        #expect(near(CubePolicy.doublePoint(aggression: 20), 0.50))
        #expect(near(CubePolicy.doublePoint(aggression: -20), 0.90))
    }
}

@Suite("Expectiminimax")
struct ExpectiminimaxTests {

    @Test func valueIsAProbability() {
        let emm = Expectiminimax(depth: 3)
        let state = freshState()
        let forP0 = emm.value(of: state, for: .player0)
        #expect(forP0 >= 0 && forP0 <= 1)
    }

    @Test func complementaryValues() {
        let emm = Expectiminimax(depth: 2)
        let state = freshState()
        let p0 = emm.value(of: state, for: .player0)
        let p1 = emm.value(of: state, for: .player1)
        #expect(abs((p0 + p1) - 1) < 1e-9)
    }

    @Test func deterministic() {
        let emm = Expectiminimax(depth: 3)
        let state = rolledState()
        #expect(emm.value(of: state, for: .player0) == emm.value(of: state, for: .player0))
    }

    @Test func boundedSearchCompletes() {
        // The depth fix: a depth-1 search from a fresh chance node must
        // terminate over the 5-outcome dice model immediately (the old bug
        // recursed without decrementing and would run for minutes).
        let emm = Expectiminimax(depth: 1)
        // swiftlint:disable:next banned_api
        let start = Date()
        _ = emm.value(of: freshState(), for: .player0)
        // swiftlint:disable:next banned_api
        #expect(Date().timeIntervalSince(start) < 2.0)
    }

    @Test func deeperSearchSeesMore() {
        // Deeper search never loses the immediate material view: from a
        // rolled state both depths agree the game is still close (both
        // probabilities inside the unit interval), and depth 3 runs.
        let state = rolledState()
        let shallow = Expectiminimax(depth: 2).value(of: state, for: .player0)
        let deep = Expectiminimax(depth: 3).value(of: state, for: .player0)
        #expect(shallow >= 0 && shallow <= 1)
        #expect(deep >= 0 && deep <= 1)
    }

    @Test func bestMoveReturnsALegalMove() {
        let emm = Expectiminimax(depth: 2)
        let state = rolledState()
        let moves = MoveGen.legalMoves(
            for: state.currentPlayer, amount: state.diceValue ?? 0,
            pieces: state.pieces, track: state.track, rules: state.ruleset)
        #expect(!moves.isEmpty)
        guard let (move, value) = emm.bestMove(from: state, for: .player0) else {
            Issue.record("bestMove returned nil with legal moves available")
            return
        }
        #expect(moves.contains(move))
        #expect(value >= 0 && value <= 1)
    }
}

@Suite("Rollouts")
struct RolloutsTests {

    @Test func batchesAreReproducible() {
        let state = freshState()
        let a = Rollouts.run(from: state, me: .player0, count: 20, seed: 7)
        let b = Rollouts.run(from: state, me: .player0, count: 20, seed: 7)
        #expect(a == b)
    }

    @Test func winRateIsPlausible() {
        let state = freshState()
        let result = Rollouts.run(from: state, me: .player0, count: 50, seed: 11)
        #expect(result.winRate >= 0 && result.winRate <= 1)
        #expect(!result.isEmpty)
    }

    @Test func nextActionAnswersDoubles() {
        // A pending double on the even start: the decider's equity is about
        // one half, above the 25% take point, so the rollout policy accepts.
        var state = freshState()
        state.doubleOffered = true
        var rng = SeededRNG(seed: 1)
        var omenRng = SeededRNG(seed: 2)
        let action = Rollouts.nextAction(in: state, rng: &rng, omenRng: &omenRng)
        guard case .acceptDouble = action else {
            Issue.record(
                "expected .acceptDouble at even equity, got \(action.map(String.init(describing:)) ?? "nil")"
            )
            return
        }
    }
}

@Suite("SolvedTableStore")
struct SolvedTableStoreTests {

    @Test func fixtureLoads() {
        let store = SolvedTableStore()
        #expect(store.isAvailable)
        #expect(store.table != nil)
    }

    @Test func coverageRejectsForeignPieceCounts() {
        // The shipped fixture is a small solve; a full 7-piece position is
        // outside its coverage and must answer nil, never an out-of-range
        // index (the crash-risk guard).
        let store = SolvedTableStore()
        guard let table = store.table else {
            Issue.record("fixture table missing")
            return
        }
        if table.pieces == 7 { return }  // a 7-piece fixture would cover it
        let state = freshState(pieces: 7)
        guard let position = TableBridge.position(from: state) else {
            Issue.record("bridge could not read a fresh 7-piece position")
            return
        }
        #expect(!table.covers(position))
        #expect(store.winProbability(forRoller: position) == nil)
    }

    @Test func coveredPositionAnswers() {
        let store = SolvedTableStore()
        guard let table = store.table else {
            Issue.record("fixture table missing")
            return
        }
        // A fresh state with exactly the table's stone count sits at the
        // table's opening position and must answer a probability.
        let state = freshState(pieces: table.pieces)
        guard let position = TableBridge.position(from: state) else {
            Issue.record("bridge could not read the fresh \(table.pieces)-piece position")
            return
        }
        #expect(table.covers(position))
        let probability = store.winProbability(forRoller: position)
        #expect(probability != nil)
        if let probability {
            #expect(probability >= 0 && probability <= 1)
        }
    }
}

@Suite("AI Bots")
struct AIBotsTests {

    @Test func optimalBotChoosesALegalMove() {
        let bot = OptimalBot(depth: 2)
        let state = rolledState()
        let moves = MoveGen.legalMoves(
            for: state.currentPlayer, amount: state.diceValue ?? 0,
            pieces: state.pieces, track: state.track, rules: state.ruleset)
        var rng = SeededRNG(seed: 3)
        if let move = bot.chooseMove(from: state, moves: moves, rng: &rng),
            moves.contains(move)
        {
            // move is legal
        } else {
            #expect(false, "OptimalBot returned nil or an illegal move")
        }
    }

    @Test func optimalBotIsDeterministic() {
        let bot = OptimalBot(depth: 2)
        let state = rolledState()
        let moves = MoveGen.legalMoves(
            for: state.currentPlayer, amount: state.diceValue ?? 0,
            pieces: state.pieces, track: state.track, rules: state.ruleset)
        var rngA = SeededRNG(seed: 3)
        var rngB = SeededRNG(seed: 9)
        #expect(
            bot.chooseMove(from: state, moves: moves, rng: &rngA)
                == bot.chooseMove(from: state, moves: moves, rng: &rngB))
    }

    @Test func optimalBotFallsBackToEMMOffTable() {
        // On a 7-piece state the shipped fixture does not cover, the
        // optimal bot's equity comes from expectiminimax and still lands
        // in the unit interval.
        let bot = OptimalBot(depth: 2)
        let equity = bot.equity(of: freshState(pieces: 7), for: .player0)
        #expect(equity != nil)
        if let equity {
            #expect(equity >= 0 && equity <= 1)
        }
    }

    @Test func optimalBotUsesTableWhenCovered() {
        let store = SolvedTableStore()
        guard let table = store.table else { return }
        let bot = OptimalBot(table: store, depth: 2)
        // On the table's own piece count the equity equals the table's
        // opening probability for the roller.
        let state = freshState(pieces: table.pieces)
        guard
            let position = TableBridge.position(from: state),
            let expected = store.winProbability(forRoller: position)
        else { return }
        #expect(bot.equity(of: state, for: state.currentPlayer) == expected)
    }

    @Test func optimalBotCubeAnswersOnEvenStart() {
        // Even start: never offer (below 70%), always take (above 25%).
        let bot = OptimalBot(depth: 2)
        var state = freshState()
        var rng = SeededRNG(seed: 4)
        #expect(!bot.wantsDouble(state: state, rng: &rng))
        state.doubleOffered = true
        #expect(bot.decideDouble(state: state, rng: &rng))
    }

    /// R-21 regression: a bot must never offer a second double in the same
    /// turn even when its raw equity clears the offer threshold. The first
    /// version of this test passed on the unguarded bot because an even
    /// start sits below 70%; this state is engineered above it.
    @Test func optimalBotNeverOffersAfterCubeUsed() {
        let bot = OptimalBot(depth: 2)
        var state = freshState()
        // Player 0 is one piece from winning; player 1 has not moved.
        // freshState orders pieces id-major: even indices are player 0.
        for i in stride(from: 0, to: 12, by: 2) { state.pieces[i].position = -2 }
        state.pieces[12].position = 12
        for i in stride(from: 1, to: 14, by: 2) { state.pieces[i].position = 0 }
        state.borneOff[.player0] = 6
        // Sanity: the engineered state really is above the offer threshold,
        // so this test would fail against the pre-guard bot.
        let equity = bot.equity(of: state, for: .player0, searchDepth: 2) ?? 0
        #expect(equity >= 0.70)
        var rng = SeededRNG(seed: 5)
        state.hasDoubledThisTurn = true
        #expect(!bot.wantsDouble(state: state, rng: &rng))
        state.hasDoubledThisTurn = false
        state.cubeDead = true
        #expect(!bot.wantsDouble(state: state, rng: &rng))
        // Ownership rule (R-10): a player who does not own the cube (and the
        // cube is not centred) may never offer.
        state.cubeDead = false
        state.cube = DoublingCube(value: 2, owner: 1)
        #expect(!bot.wantsDouble(state: state, rng: &rng))
        state.cube = DoublingCube(value: 2, owner: 0)
        #expect(bot.wantsDouble(state: state, rng: &rng))
    }

    @Test func variantBotChoosesALegalMove() {
        let bot = VariantBot(depth: 2, cubeRollouts: 10, omenRollouts: 5)
        let state = rolledState()
        let moves = MoveGen.legalMoves(
            for: state.currentPlayer, amount: state.diceValue ?? 0,
            pieces: state.pieces, track: state.track, rules: state.ruleset)
        var rng = SeededRNG(seed: 5)
        if let move = bot.chooseMove(from: state, moves: moves, rng: &rng),
            moves.contains(move)
        {
            // move is legal
        } else {
            #expect(false, "VariantBot returned nil or an illegal move")
        }
    }

    @Test func variantBotIsDeterministicAcrossStreams() {
        // INV-4: the rollout seeds derive from the state hash, so equal
        // states give equal decisions regardless of the caller's stream.
        let bot = VariantBot(depth: 2, cubeRollouts: 15, omenRollouts: 5)
        let state = rolledState()
        let moves = MoveGen.legalMoves(
            for: state.currentPlayer, amount: state.diceValue ?? 0,
            pieces: state.pieces, track: state.track, rules: state.ruleset)
        var rngA = SeededRNG(seed: 100)
        var rngB = SeededRNG(seed: 200)
        #expect(
            bot.chooseMove(from: state, moves: moves, rng: &rngA)
                == bot.chooseMove(from: state, moves: moves, rng: &rngB))
    }

    @Test func variantBotCubeAnswersOnEvenStart() {
        let bot = VariantBot(depth: 2, cubeRollouts: 30, omenRollouts: 10)
        var state = freshState()
        var rng = SeededRNG(seed: 6)
        #expect(!bot.wantsDouble(state: state, rng: &rng))
        state.doubleOffered = true
        #expect(bot.decideDouble(state: state, rng: &rng))
    }

    @Test func variantBotDecisionLatency() {
        // Depth-3 move choice on a real mid-roll position stays far below
        // the variant budget (the G4 harness enforces the 600 ms p95 on
        // device; this guard catches a pathological search blowup).
        let bot = VariantBot(depth: 3, cubeRollouts: 20, omenRollouts: 8)
        let state = rolledState()
        let moves = MoveGen.legalMoves(
            for: state.currentPlayer, amount: state.diceValue ?? 0,
            pieces: state.pieces, track: state.track, rules: state.ruleset)
        var rng = SeededRNG(seed: 7)
        // swiftlint:disable:next banned_api
        let start = Date()
        _ = bot.chooseMove(from: state, moves: moves, rng: &rng)
        // swiftlint:disable:next banned_api
        #expect(Date().timeIntervalSince(start) < 2.0)
    }
}

@Suite("Bot vs Bot end to end")
struct BotMatchAITests {

    @Test func optimalAgainstVariantCompletesAndReplays() throws {
        // A full match between the two AI bots: the driver drives them
        // through cube offers, answers, omen holds, and moves; the recorded
        // actions then replay bit for bit through the reducer (INV-4).
        let record = try BotMatch.play(
            seed: 42,
            ruleset: .finkel,
            dice: .tetra4,
            stake: 2,
            bot0: OptimalBot(depth: 2),
            bot1: VariantBot(depth: 2, cubeRollouts: 20, omenRollouts: 8),
            maxActions: 60_000
        )
        #expect(record.finalState.isComplete)

        var state = MatchState.newMatch(
            ruleset: .finkel, dice: .tetra4, stake: 2, omens: [], fortunes: [])
        var rng = SeededRNG(seed: 42)
        var omenRng = SeededRNG(seed: 42 &+ 0x9E37_79B9_7F4A_7C15)
        for action in record.actions {
            let result = try Reducer.apply(action, to: state, rng: &rng, omenRng: &omenRng)
            state = result.state
        }
        #expect(state.stateHash == record.finalState.stateHash)
    }

    @Test func heuristicAgainstOptimalCompletes() throws {
        // The P3 heuristic circuit bot (now a MatchBot) against the tier-3
        // optimal bot: one driver, two tiers.
        let record = try BotMatch.play(
            seed: 7,
            ruleset: .finkel,
            dice: .tetra4,
            stake: 2,
            bot0: RosetteBot(personality: .greedy, strength: 3),
            bot1: OptimalBot(depth: 2),
            maxActions: 60_000
        )
        #expect(record.finalState.isComplete)
        #expect(!record.actions.isEmpty)
    }

    // MARK: - G4: circuit completion (A.6: completes circuit 55–70% / 5–15%)

    /// One circuit run's evidence.
    struct CircuitRunResult: Sendable {
        let seed: UInt64
        let completed: Bool
        let matches: Int
        let finalPurse: Int
    }

    /// Tavern opponent strength by region for the calibration harness
    /// (ADR-0011 / BALANCE.md G4: Sumer 3, Egypt 4, Mexica 4).
    private static func tavernStrength(region: String) -> Int {
        switch region {
        case "sumer": return 3
        case "egypt": return 4
        case "mexica": return 4
        default: return 3
        }
    }

    /// Play one full circuit run over the real content circuit (starting
    /// purse 40, A.6 economy). The player is bot0 at every tavern; the
    /// opponent is the tavern's content opponent. Settlement uses the final
    /// cube value (R-9/R-11: gammon doubles the loss where the tavern
    /// enables it). Bots play omenless matches: omen purchases are the
    /// player's meta-choice (R-12/R-14), not part of the G4 calibration.
    static func runCircuit(
        seed: UInt64,
        makePlayer: @escaping @Sendable () -> any MatchBot & Sendable,
        purse: Int? = nil,
        strengthFor: (@Sendable (String) -> Int)? = nil,
        report: (@Sendable (String) -> Void)? = nil
    ) async throws -> CircuitRunResult {
        let loader = ContentLoader()
        let taverns = try loader.loadCircuitTaverns()
        let rulesets = try loader.loadEngineRuleSets()
        let opponentDefs = try loader.loadOpponents()
        let opponents = Dictionary(uniqueKeysWithValues: opponentDefs.map { ($0.id, $0) })
        var circuit = try loader.newCircuitState()
        if let purse {
            // Calibration sweep only (roadmap §balance: purse tunable 20–80).
            circuit = CircuitState(
                taverns: taverns, startPurse: purse, finalCrawford: circuit.finalCrawford)
        }
        let player = makePlayer()
        var matches = 0
        var attempts = 0

        while let tavern = circuit.currentTavern, !circuit.isRunEnded {
            guard circuit.payBuyIn() else { break }
            let stake = circuit.stake(for: tavern)
            guard let ruleset = rulesets.first(where: { $0.id == tavern.rulesetId }),
                let dice = try loader.diceModel(forRulesetID: tavern.rulesetId),
                let opponentDef = opponents[tavern.opponentId]
            else {
                Issue.record("content missing for tavern \(tavern.id)")
                break
            }
            let opponent = Opponent(def: opponentDef)
                .makeBot(
                    strength: strengthFor?(tavern.region) ?? tavernStrength(region: tavern.region))
            // ADR-0009: a loss re-challenges the same tavern, so the attempt
            // index must enter the match seed or the replay would repeat an
            // identical match (deterministic bots would then lose forever).
            let matchSeed =
                seed &* 1_000_003 &+ UInt64(circuit.tavernIndex) &* 1_009
                &+ UInt64(attempts) &* 7_919 &+ 42
            attempts += 1
            let record = try BotMatch.play(
                seed: matchSeed,
                ruleset: ruleset,
                dice: dice,
                stake: stake,
                bot0: player,
                bot1: opponent,
                maxActions: 10_000
            )
            matches += 1
            guard let outcome = record.finalState.outcome else { break }
            let won = outcome.winner == .player0
            circuit.recordResult(
                won: won,
                stake: stake * outcome.cubeValue,
                gammon: outcome.gammon && tavern.gammonRule
            )
            #expect(circuit.purse.balance >= 0, "purse never negative (INV-3)")
            if won { _ = circuit.advanceTavern() }
            report?(
                "seed=\(seed) tavern=\(tavern.id) ruleset=\(tavern.rulesetId) stake=\(stake) won=\(won) cube=\(outcome.cubeValue) gammon=\(outcome.gammon) purse=\(circuit.purse.balance) plies=\(record.actions.count)"
            )
        }

        #expect(
            circuit.isComplete || circuit.isRunEnded,
            "the run must end by completing the circuit or running out of purse")
        return CircuitRunResult(
            seed: seed,
            completed: circuit.isComplete,
            matches: matches,
            finalPurse: circuit.purse.balance
        )
    }

    /// Run `count` seeded circuit runs concurrently.
    private static func collectCircuitRuns(
        count: Int,
        baseSeed: UInt64,
        makePlayer: @escaping @Sendable () -> any MatchBot & Sendable
    ) async throws -> [CircuitRunResult] {
        try await withThrowingTaskGroup(of: CircuitRunResult.self) { group in
            for index in 0..<count {
                let seed = baseSeed &+ UInt64(index &* 9_977)
                group.addTask {
                    try await runCircuit(seed: seed, makePlayer: makePlayer)
                }
            }
            var runs: [CircuitRunResult] = []
            for try await run in group { runs.append(run) }
            return runs.sorted { $0.seed < $1.seed }
        }
    }

    @Test func optimalCircuitCompletion() async throws {
        // G4/A.6: with the real content circuit (calibrated purse 80), the
        // tier-3 optimal bot completes the circuit 55–70% of the time. This
        // regression assertion uses a wide plausibility band so binomial
        // noise across 24 runs cannot flake the suite; the measured gate
        // value against the roadmap band is recorded in docs/STATUS.md.
        let store = SolvedTableStore()
        let runs = try await Self.collectCircuitRuns(count: 24, baseSeed: 900_001) {
            OptimalBot(table: store, depth: 2)
        }
        let completed = runs.filter { $0.completed }.count
        let rate = Double(completed) / Double(runs.count)
        #expect(runs.allSatisfy { $0.matches > 0 }, "every run plays matches")
        #expect(rate >= 0.40, "optimal circuit completion \(rate) collapsed")
    }

    @Test func naiveCircuitCompletion() async throws {
        // G4/A.6: the naive bot completes the circuit 5–15% of the time.
        // The benchmark player is the careful heuristic bot at strength 2
        // (an untrained player, not the weakest bot); 0.30 is a wide
        // plausibility bound so 24-run binomial noise cannot flake CI.
        let runs = try await Self.collectCircuitRuns(count: 24, baseSeed: 700_001) {
            RosetteBot(personality: .careful, strength: 2)
        }
        let completed = runs.filter { $0.completed }.count
        let rate = Double(completed) / Double(runs.count)
        #expect(rate <= 0.30, "naive circuit completion \(rate) too high")
    }
}
