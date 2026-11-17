import XCTest

@testable import RSCore

/// Circuit simulation over a fixture circuit mirroring the content shape
/// (3 regions × 4 taverns, stakes 5/10/20 by region). The G3 gate's
/// 1,000-run check over the real content lives in RSContentTests; these
/// tests pin the circuit state machine itself (R-13, R-14, INV-3).
final class CircuitSimulationTests: XCTestCase {

    // MARK: Fixture circuit

    /// 12 fixture taverns mirroring taverns.json's shape and stakes.
    static func fixtureTaverns() -> [Tavern] {
        let regionStakes: [(region: String, minStake: Int, buyIns: [Int], rulesets: [String])] = [
            ("sumer", 5, [5, 6, 8, 10], ["finkel", "finkel", "masters", "house_rules"]),
            ("egypt", 10, [10, 12, 15, 18], ["tablet", "tablet", "senet_like", "house_rules"]),
            ("mexica", 20, [20, 24, 30, 40], ["patolli", "patolli", "masters", "house_rules"]),
        ]
        var taverns: [Tavern] = []
        for (index, region) in regionStakes.enumerated() {
            for slot in 0..<4 {
                taverns.append(
                    Tavern(
                        id: "\(region.region)_t\(slot)",
                        name: "Tavern \(index * 4 + slot)",
                        region: region.region,
                        rulesetId: region.rulesets[slot],
                        opponentId: "\(region.region)_opp_\(slot)",
                        minStake: region.minStake,
                        buyIn: region.buyIns[slot],
                        gammonRule: slot >= 2,
                        label: .invented
                    ))
            }
        }
        return taverns
    }

    /// Engine rulesets for the fixture ids (constructed inline; the real
    /// content mapping is exercised in RSContentTests).
    static func fixtureRulesets() -> [String: RuleSet] {
        [
            "finkel": .finkel,
            "masters": RuleSet(
                id: "masters", label: "Masters (fixture)", trackLength: 18, pieces: 7,
                rosettes: [4, 9, 17], safeRosettes: [9], diceModel: "tetra4",
                exactBearOff: true, extraRollOnRosette: true, captureRule: .standard,
                moveGenerator: "ur", source: "fixture", historyLabel: .reconstructed),
            "house_rules": RuleSet(
                id: "house_rules", label: "House (fixture)", trackLength: 14, pieces: 7,
                rosettes: [3, 7, 13], safeRosettes: [], diceModel: "tetra4",
                exactBearOff: false, extraRollOnRosette: true, captureRule: .standard,
                moveGenerator: "ur", source: "fixture", historyLabel: .invented),
            "tablet": RuleSet(
                id: "tablet", label: "Tablet (fixture)", trackLength: 14, pieces: 5,
                rosettes: [3, 7, 13], safeRosettes: [7], diceModel: "astragal4",
                exactBearOff: true, extraRollOnRosette: true, captureRule: .standard,
                moveGenerator: "ur", source: "fixture", historyLabel: .reconstructed),
            "senet_like": RuleSet(
                id: "senet_like", label: "Senet-like (fixture)", trackLength: 30, pieces: 7,
                rosettes: [], safeRosettes: [], diceModel: "stick4",
                exactBearOff: true, extraRollOnRosette: false, captureRule: .none,
                moveGenerator: "senet-like", source: "fixture", historyLabel: .reconstructed),
            "patolli": RuleSet(
                id: "patolli", label: "Patolli (fixture)", trackLength: 52, pieces: 7,
                rosettes: [], safeRosettes: [], diceModel: "beans5",
                exactBearOff: true, extraRollOnRosette: false, captureRule: .standard,
                moveGenerator: "patolli-like", source: "fixture", historyLabel: .reconstructed),
        ]
    }

    static func fixtureDice() -> [String: DiceModel] {
        [
            "tetra4": .tetra4,
            "astragal4": .astragal4,
            "stick4": .stick4,
            "beans5": .beans5,
        ]
    }

    /// Play one bot-vs-bot match at a tavern.
    func playBotMatch(
        seed: UInt64,
        tavern: Tavern,
        rulesets: [String: RuleSet],
        dice: [String: DiceModel],
        stake: Int,
        strength: Int,
        playerPersonality: Personality = .careful
    ) throws -> MatchState {
        guard let ruleset = rulesets[tavern.rulesetId], let model = dice[ruleset.diceModel] else {
            throw RuleError.illegalAction("fixture missing for \(tavern.rulesetId)")
        }
        let record = try BotMatch.play(
            seed: seed,
            ruleset: ruleset,
            dice: model,
            stake: stake,
            bot0: RosetteBot(personality: playerPersonality, strength: strength),
            bot1: RosetteBot(personality: .greedy, strength: strength),
            maxActions: 10_000
        )
        XCTAssertTrue(record.finalState.isComplete, "Match should not softlock at seed \(seed)")
        return record.finalState
    }

    /// Walk a full circuit run with bots (R-13: entry costs and purse).
    /// A win advances; a loss re-challenges the same tavern. Returns
    /// (final circuit, matches played).
    func simulateCircuitRun(
        seed: UInt64,
        startPurse: Int = 40,
        strength: Int
    ) throws -> (circuit: CircuitState, matches: Int) {
        let rulesets = Self.fixtureRulesets()
        let dice = Self.fixtureDice()
        var circuit = CircuitState(
            taverns: Self.fixtureTaverns(),
            startPurse: startPurse,
            finalCrawford: true
        )
        var matches = 0

        while let tavern = circuit.currentTavern, !circuit.isRunEnded {
            XCTAssertTrue(circuit.payBuyIn(), "entry is affordable while the run continues")
            let stake = circuit.stake(for: tavern)
            XCTAssertGreaterThanOrEqual(stake, tavern.minStake, "stake meets the minimum")
            let matchSeed =
                seed &* 1_000_003 &+ UInt64(circuit.tavernIndex) &* 1_009 &+ 42
            let final = try playBotMatch(
                seed: matchSeed,
                tavern: tavern,
                rulesets: rulesets,
                dice: dice,
                stake: stake,
                strength: strength
            )
            let won = final.outcome?.winner == .player0
            circuit.recordResult(
                won: won,
                stake: stake,
                gammon: final.outcome?.gammon == true
            )
            matches += 1
            XCTAssertGreaterThanOrEqual(
                circuit.purse.balance, 0, "purse never negative (INV-3)")
            if won {
                circuit.advanceTavern()
            }
        }

        XCTAssertTrue(
            circuit.isComplete || circuit.isRunEnded,
            "the run must end by completing the circuit or running out of purse")
        return (circuit, matches)
    }

    // MARK: Runs complete or end cleanly (no softlocks)

    func testCircuitRunsCompleteOrEndCleanly() throws {
        for seed: UInt64 in 1...100 {
            let (circuit, matches) = try simulateCircuitRun(seed: seed, strength: 3)
            XCTAssertGreaterThan(matches, 0, "run \(seed) must play at least one match")
        }
    }

    func testCircuitPurseNeverNegativeAcrossRuns() throws {
        for seed: UInt64 in 1...50 {
            let (circuit, _) = try simulateCircuitRun(seed: seed, strength: 2)
            XCTAssertGreaterThanOrEqual(
                circuit.purse.balance, 0, "purse negative at run \(seed) (INV-3)")
        }
    }

    func testEveryTavernReachableAcrossRuns() throws {
        // Across seeds with a strong player and a deep purse, every tavern
        // index must be visited (RS-P3.1: each tavern reachable).
        var visited = Set<Int>()
        for seed: UInt64 in 1...20 {
            let (circuit, _) = try simulateCircuitRun(seed: seed, startPurse: 500, strength: 4)
            for index in 0..<circuit.tavernsCompleted {
                visited.insert(index)
            }
        }
        XCTAssertEqual(visited, Set(0..<12), "every tavern must be reachable")
    }

    // MARK: R-13 / R-14 semantics

    func testRunEndsWhenPurseCannotReenter() throws {
        // A player who keeps losing re-challenges the same tavern, paying
        // again each time; when the purse can no longer cover the re-entry
        // (buy-in + minimum stake), the run ends (R-13).
        var circuit = CircuitState(
            taverns: Self.fixtureTaverns(), startPurse: 20, finalCrawford: true)
        var matches = 0
        while let tavern = circuit.currentTavern, !circuit.isRunEnded {
            XCTAssertTrue(circuit.payBuyIn())
            circuit.recordResult(won: false, stake: circuit.stake(for: tavern))
            matches += 1
        }
        XCTAssertEqual(matches, 2, "two losses at tavern 0 drain 20 to 0")
        XCTAssertTrue(circuit.isRunEnded)
        XCTAssertFalse(circuit.isComplete)
        XCTAssertTrue(circuit.isOver)
        XCTAssertEqual(circuit.tavernsCompleted, 0, "a player who never wins never advances")
    }

    func testWinAdvancesAndLossStaysAtTheTavern() {
        var circuit = CircuitState(
            taverns: Self.fixtureTaverns(), startPurse: 40, finalCrawford: true)
        XCTAssertTrue(circuit.payBuyIn())
        circuit.recordResult(won: false, stake: circuit.stake(for: circuit.taverns[0]))
        XCTAssertEqual(circuit.tavernIndex, 0, "a loss leaves the player at the tavern")
        circuit.recordResult(won: true, stake: circuit.stake(for: circuit.taverns[0]))
        XCTAssertEqual(circuit.tavernIndex, 0, "recording a win does not advance by itself")
        XCTAssertTrue(circuit.advanceTavern())
        XCTAssertEqual(circuit.tavernIndex, 1, "the win advances the ladder")
    }

    func testBuyInRejectedWhenUnaffordable() {
        var circuit = CircuitState(
            taverns: Self.fixtureTaverns(), startPurse: 4, finalCrawford: true)
        XCTAssertEqual(circuit.purse.balance, 4, "sanity: the purse starts at 4")
        XCTAssertFalse(circuit.payBuyIn(), "4 < buy-in 5")
        XCTAssertEqual(circuit.purse.balance, 4)
        XCTAssertTrue(circuit.isRunEnded)
    }

    func testOmenPurchaseLimitsAndCosts() {
        var circuit = CircuitState(
            taverns: Self.fixtureTaverns(), startPurse: 40, finalCrawford: true)
        let expensive = OmenDef(
            id: "omen_a", name: "A", cost: 30, effect: .reroll(count: 1), label: .invented)
        let cheap = OmenDef(
            id: "omen_b", name: "B", cost: 5, effect: .split(count: 1), label: .invented)
        XCTAssertTrue(circuit.buyOmen(expensive))
        XCTAssertEqual(circuit.heldOmens, ["omen_a"])
        XCTAssertEqual(circuit.purse.balance, 10, "the cost is paid from the purse")
        XCTAssertTrue(circuit.buyOmen(cheap))
        XCTAssertEqual(circuit.heldOmens.count, 2, "R-12: at most two held")
        XCTAssertFalse(circuit.buyOmen(cheap), "a third omen is refused")
        // A fresh purse too small for any omen cannot buy one.
        var poor = CircuitState(
            taverns: Self.fixtureTaverns(), startPurse: 4, finalCrawford: true)
        XCTAssertFalse(poor.buyOmen(cheap), "unaffordable omens are refused")
    }

    func testTellLearnedOnceAndPaid() {
        var circuit = CircuitState(
            taverns: Self.fixtureTaverns(), startPurse: 40, finalCrawford: true)
        let opponent = OpponentDef(
            id: "opp", name: "Opp", ai: "greedy", cubeAggression: 4, omens: [],
            tellCost: 10, label: .invented)
        XCTAssertTrue(circuit.learnTell(opponent))
        XCTAssertEqual(circuit.learnedTells, ["opp"])
        XCTAssertFalse(circuit.learnTell(opponent), "a tell is learned once")
        XCTAssertEqual(circuit.purse.balance, 30)
    }

    func testGammonDoublesLossOnlyWhenTavernEnables() {
        var circuit = CircuitState(
            taverns: Self.fixtureTaverns(), startPurse: 40, finalCrawford: true)
        circuit.advanceTavern()  // slot 1, gammon off
        circuit.recordResult(won: false, stake: 5, gammon: true)
        XCTAssertEqual(circuit.purse.balance, 35, "gammon off: single stake")
        var gammonCircuit = CircuitState(
            taverns: Self.fixtureTaverns(), startPurse: 40, finalCrawford: true)
        for _ in 0..<3 { gammonCircuit.advanceTavern() }  // slot 3, gammon on
        gammonCircuit.recordResult(won: false, stake: 5, gammon: true)
        XCTAssertEqual(gammonCircuit.purse.balance, 30, "gammon on: double stake")
    }

    func testStakeNeverAbovePurse() {
        let circuit = CircuitState(
            taverns: Self.fixtureTaverns(), startPurse: 2, finalCrawford: true)
        XCTAssertEqual(circuit.stake(for: circuit.taverns[0]), 2, "stake clamps to purse")
    }

    // MARK: RosetteBot behaviour

    func testBotNeverReturnsIllegalMoveAndHandlesEmpty() throws {
        let state = TestSupport.state(
            player0: [3, 5, -1, -1, -1, -2, -2],
            player1: [7, -1, -1, -1, -1, -1, -1]
        )
        let moves = MoveGen.legalMoves(
            for: .player0, amount: 2, pieces: state.pieces, track: state.track,
            rules: state.ruleset)
        XCTAssertFalse(moves.isEmpty)
        for personality in Personality.allCases {
            var rng = SeededRNG(seed: 7)
            let bot = RosetteBot(personality: personality, strength: 3)
            let chosen = bot.chooseMove(
                from: moves, pieces: state.pieces, track: state.track, rng: &rng)
            XCTAssertNotNil(chosen)
            XCTAssertTrue(moves.contains { $0.piece == chosen?.piece })
        }
        var rng = SeededRNG(seed: 7)
        let bot = RosetteBot(personality: .greedy, strength: 3)
        XCTAssertNil(bot.chooseMove(from: [], pieces: state.pieces, track: state.track, rng: &rng))
    }

    func testBotIsDeterministic() throws {
        let state = TestSupport.state(
            player0: [3, 5, -1, -1, -1, -2, -2],
            player1: [7, -1, -1, -1, -1, -1, -1]
        )
        let moves = MoveGen.legalMoves(
            for: .player0, amount: 3, pieces: state.pieces, track: state.track,
            rules: state.ruleset)
        var rngA = SeededRNG(seed: 99)
        var rngB = SeededRNG(seed: 99)
        let bot = RosetteBot(personality: .bluffer, strength: 2)
        let a = bot.chooseMove(from: moves, pieces: state.pieces, track: state.track, rng: &rngA)
        let b = bot.chooseMove(from: moves, pieces: state.pieces, track: state.track, rng: &rngB)
        XCTAssertEqual(a?.piece, b?.piece)
    }
}
