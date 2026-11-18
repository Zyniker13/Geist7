// RSContent — content loader, integrity, and G3 simulation tests.
//
// The G3 gate requires 1,000 bot circuit runs over the real content with
// no softlocks; that is `testG3_1000BotCircuitRunsWithoutSoftlocks`.

import XCTest

@testable import RSContent
@testable import RSCore

final class RSContentTests: XCTestCase {

    // MARK: Validation and counts (§5, G5 levels)

    func testValidateAllIsClean() throws {
        let result = try ContentLoader().validateAll()
        XCTAssertTrue(result.isValid, "content must validate: \(result.errors)")
    }

    func testCountsMatchTheAuthoredTables() throws {
        let loader = ContentLoader()
        XCTAssertEqual(try loader.loadDice().count, 4, "four dice models")
        XCTAssertEqual(try loader.loadRulesets().count, 6, "six rulesets")
        XCTAssertEqual(try loader.loadTaverns().count, 12, "12 taverns (3 regions × 4)")
        XCTAssertEqual(try loader.loadOpponents().count, 12, "12 opponents")
        XCTAssertEqual(try loader.loadOmens().count, 12, "twelve omens (G5)")
        XCTAssertEqual(try loader.loadFortunes().count, 4, "four fortune squares")
        XCTAssertEqual(try loader.loadTutorial().count, 3, "three tutorial lessons")
    }

    func testCircuitWalksThreeRegionsInOrder() throws {
        let loader = ContentLoader()
        let circuit = try loader.loadCircuit()
        XCTAssertEqual(circuit.regions.map(\.id), ["sumer", "egypt", "mexica"])
        let ordered = try loader.loadCircuitTaverns()
        XCTAssertEqual(ordered.count, 12)
        XCTAssertEqual(
            ordered.map(\.region),
            [
                "sumer", "sumer", "sumer", "sumer",
                "egypt", "egypt", "egypt", "egypt",
                "mexica", "mexica", "mexica", "mexica",
            ])
        XCTAssertEqual(ordered.first?.id, "ur_harbor")
    }

    // MARK: HIST3.1 — history labels

    func testRulesetsCarryHistoryLabels() throws {
        let loader = ContentLoader()
        let defs = try loader.loadRulesets()
        let byID = Dictionary(uniqueKeysWithValues: defs.map { ($0.id, $0) })
        XCTAssertEqual(byID["finkel"]?.label, .reconstructed)
        XCTAssertEqual(byID["house_rules"]?.label, .invented)
        for def in defs {
            XCTAssertFalse(def.source.isEmpty, "\(def.id) must cite its source")
        }
    }

    func testTavernsAreMarkedInvented() throws {
        let loader = ContentLoader()
        for tavern in try loader.loadTaverns() {
            XCTAssertEqual(tavern.label, .invented, "taverns are invented content")
            XCTAssertFalse(tavern.name.isEmpty)
            XCTAssertGreaterThan(tavern.minStake, 0)
            XCTAssertGreaterThan(tavern.buyIn, 0)
        }
    }

    // MARK: Referential integrity and dice resolution

    func testEveryRulesetResolvesItsDiceModel() throws {
        let loader = ContentLoader()
        let dice = try loader.loadDice()
        let diceIds = Set(dice.map(\.id))
        for ruleset in try loader.loadRulesets() {
            XCTAssertTrue(diceIds.contains(ruleset.dice), "\(ruleset.id) → \(ruleset.dice)")
        }
        for model in dice {
            XCTAssertEqual(
                model.outcomes.reduce(0) { $0 + $1.weight }, model.denominator,
                "\(model.id): weights must sum to the denominator (R-17)")
        }
    }

    func testContentFinkelMatchesTheEngineRuleset() throws {
        let loader = ContentLoader()
        let engine = try loader.loadEngineRuleSets()
        let finkel = try XCTUnwrap(engine.first(where: { $0.id == "finkel" }))
        XCTAssertEqual(finkel.trackLength, RuleSet.finkel.trackLength)
        XCTAssertEqual(finkel.pieces, RuleSet.finkel.pieces)
        XCTAssertEqual(finkel.rosettes, RuleSet.finkel.rosettes)
        XCTAssertEqual(finkel.safeRosettes, RuleSet.finkel.safeRosettes)
        XCTAssertEqual(finkel.diceModel, RuleSet.finkel.diceModel)
        XCTAssertEqual(finkel.exactBearOff, RuleSet.finkel.exactBearOff)
    }

    func testOmenCostsAreWithinTheSixDollarBand() throws {
        for omen in try ContentLoader().loadOmens() {
            XCTAssertGreaterThanOrEqual(omen.cost, 5, "\(omen.id) below the §6 floor")
            XCTAssertLessThanOrEqual(omen.cost, 40, "\(omen.id) above the §6 ceiling")
        }
    }

    // MARK: Simulation over the real content

    /// Play one full circuit run with bots over the real content. A win
    /// advances; a loss re-challenges. The opponent holds its content omens.
    func simulateRealCircuitRun(seed: UInt64, strength: Int) throws -> (CircuitState, Int) {
        let loader = ContentLoader()
        let validation = try loader.validateAll()
        XCTAssertTrue(validation.isValid, "content must validate before simulation")
        let rulesetByID = Dictionary(
            uniqueKeysWithValues: try loader.loadEngineRuleSets().map { ($0.id, $0) })
        let diceByID = Dictionary(
            uniqueKeysWithValues: try loader.loadDice().map { ($0.id, loader.makeDiceModel($0)) })
        let opponentByID = Dictionary(
            uniqueKeysWithValues: try loader.loadOpponents().map { ($0.id, $0) })
        var circuit = try loader.newCircuitState()
        var matches = 0

        while let tavern = circuit.currentTavern, !circuit.isRunEnded {
            XCTAssertTrue(circuit.payBuyIn(), "entry is affordable while the run continues")
            let ruleset = try XCTUnwrap(rulesetByID[tavern.rulesetId])
            let dice = try XCTUnwrap(diceByID[ruleset.diceModel])
            let stake = circuit.stake(for: tavern)
            let opponent = try XCTUnwrap(opponentByID[tavern.opponentId])
            let record = try BotMatch.play(
                seed: seed &* 6_364_136_223_846_793_005 &+ UInt64(matches) &+ 1,
                ruleset: ruleset,
                dice: dice,
                stake: stake,
                bot0: RosetteBot(personality: .careful, strength: strength),
                bot1: RosetteBot(personality: .greedy, strength: strength),
                omens1: try loader.omens(forOpponent: opponent),
                maxActions: 50_000
            )
            XCTAssertTrue(record.finalState.isComplete, "no match may softlock (seed \(seed))")
            let won = record.finalState.outcome?.winner == .player0
            circuit.recordResult(
                won: won,
                stake: stake,
                gammon: record.finalState.outcome?.gammon == true
            )
            matches += 1
            XCTAssertGreaterThanOrEqual(circuit.purse.balance, 0, "INV-3")
            if won {
                circuit.advanceTavern()
            }
        }

        XCTAssertTrue(
            circuit.isComplete || circuit.isRunEnded,
            "the run must end by completing the circuit or running out of purse")
        return (circuit, matches)
    }

    func testCircuitRunSampleIsSane() throws {
        for seed: UInt64 in 1...20 {
            let (circuit, matches) = try simulateRealCircuitRun(seed: seed, strength: 3)
            XCTAssertGreaterThan(matches, 0, "run \(seed) must play at least one match")
        }
    }

    /// G3: 1,000 bot circuit runs over the real content. Every run must
    /// terminate cleanly (circuit completed or purse-broken) with no
    /// softlocks and a purse that never goes negative (R-13, INV-3). The
    /// G4 balance target ("optimal bot completes the circuit 55–70%") is
    /// tuned later; G3 only requires clean termination.
    func testG3_1000BotCircuitRunsWithoutSoftlocks() throws {
        var completed = 0
        var totalMatches = 0
        for seed: UInt64 in 1...1_000 {
            let (circuit, matches) = try simulateRealCircuitRun(seed: seed, strength: 3)
            XCTAssertTrue(circuit.isComplete || circuit.isRunEnded)
            XCTAssertGreaterThanOrEqual(circuit.purse.balance, 0)
            totalMatches += matches
            if circuit.isComplete { completed += 1 }
        }
        XCTAssertGreaterThan(totalMatches, 1_000, "runs must play real matches")
        print("G3 simulation: 1,000 runs, \(totalMatches) matches, \(completed) full completions")
    }

    /// RS-P3.1: each tavern is reachable. With a deep purse (bypassing the
    /// start-purse economy, which G4 tunes) a strong player must be able to
    /// visit every tavern in the real circuit.
    func testEveryRealTavernIsReachableWithADeepPurse() throws {
        var visited = Set<Int>()
        for seed: UInt64 in 1...10 {
            let loader = ContentLoader()
            let rulesetByID = Dictionary(
                uniqueKeysWithValues: try loader.loadEngineRuleSets().map { ($0.id, $0) })
            let diceByID = Dictionary(
                uniqueKeysWithValues: try loader.loadDice().map {
                    ($0.id, loader.makeDiceModel($0))
                })
            var circuit = CircuitState(
                taverns: try loader.loadCircuitTaverns(),
                startPurse: 800,
                finalCrawford: true
            )
            var matches = 0
            while let tavern = circuit.currentTavern, !circuit.isRunEnded {
                XCTAssertTrue(circuit.payBuyIn())
                let ruleset = try XCTUnwrap(rulesetByID[tavern.rulesetId])
                let dice = try XCTUnwrap(diceByID[ruleset.diceModel])
                let stake = circuit.stake(for: tavern)
                let record = try BotMatch.play(
                    seed: seed &* 6_364_136_223_846_793_005 &+ UInt64(matches) &+ 7,
                    ruleset: ruleset,
                    dice: dice,
                    stake: stake,
                    bot0: RosetteBot(personality: .careful, strength: 4),
                    bot1: RosetteBot(personality: .greedy, strength: 3),
                    maxActions: 50_000
                )
                let won = record.finalState.outcome?.winner == .player0
                circuit.recordResult(won: won, stake: stake)
                matches += 1
                if won { circuit.advanceTavern() }
            }
            for index in 0..<circuit.tavernsCompleted {
                visited.insert(index)
            }
        }
        XCTAssertEqual(visited, Set(0..<12), "every tavern must be reachable over real content")
    }
}
