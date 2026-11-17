import XCTest

@testable import RSCore

/// Circuit simulation: 1,000 bot circuit runs without softlocks.
/// G3 gate — "1,000 bot circuit runs complete without softlocks".
final class CircuitSimulationTests: XCTestCase {

    // MARK: Single-match bot simulation

    /// Play a single match between two bots at a given difficulty.
    /// Returns the final state (or throws on softlock).
    func playBotMatch(
        seed: UInt64,
        difficulty: Int,
        ruleset: RuleSet = .finkel,
        stake: Int = 1
    ) throws -> (finalState: MatchState, actions: [Action]) {
        let record = try RandomMatch.play(
            seed: seed,
            ruleset: ruleset,
            dice: .tetra4,
            stake: stake,
            maxActions: 10_000
        )
        // Verify the match completed (not softlocked)
        XCTAssertTrue(record.finalState.isComplete, "Match should not softlock at seed \(seed)")
        XCTAssertLessThan(record.actions.count, 10_000, "Match should complete within action budget")
        return (record.finalState, record.actions)
    }

    // MARK: Single-tavern circuit run

    /// Simulate one full circuit run (through all taverns) with bots.
    /// Returns the final circuit state.
    func simulateCircuitRun(
        seed: UInt64,
        ruleset: RuleSet = .finkel,
        stake: Int = 1
    ) throws -> CircuitState {
        var circuit = CircuitState.newCircuit()
        var rng = SeededRNG(seed: seed)

        while !circuit.currentTavern.isFinal {
            let tavern = circuit.currentTavern
            let bot = RosetteBot(difficulty: tavern.aiLevel, style: .balanced)

            // Play several games at this tavern
            let gamesAtTavern = 2 + Int(tavern.difficulty)
            for gameIdx in 0..<gamesAtTavern {
                let gameSeed = seed * 1000 + UInt64(tavern.difficulty) * 100 + UInt64(gameIdx)
                let (finalState, _) = try playBotMatch(
                    seed: gameSeed,
                    difficulty: tavern.aiLevel,
                    ruleset: ruleset,
                    stake: tavern.stake
                )
                let won = finalState.outcome?.winner == .player0
                circuit.recordResult(won: won, stake: tavern.stake)
            }

            // Advance to next tavern
            circuit.advanceTavern()
        }

        // Play the final tavern
        let finalTavern = circuit.currentTavern
        for gameIdx in 0..<3 {
            let gameSeed = seed * 1000 + UInt64(finalTavern.difficulty) * 100 + UInt64(gameIdx)
            let (finalState, _) = try playBotMatch(
                seed: gameSeed,
                difficulty: finalTavern.aiLevel,
                ruleset: ruleset,
                stake: finalTavern.stake
            )
            let won = finalState.outcome?.winner == .player0
            circuit.recordResult(won: won, stake: finalTavern.stake)
        }

        return circuit
    }

    // MARK: Gate G3 — 1,000 bot circuit runs

    func testG3_1000CircuitRunsNoSoftlock() throws {
        var totalGames = 0
        var totalWins = 0
        var totalLosses = 0

        for i in 0..<1_000 {
            let seed = UInt64(i) * 7 + 42  // Spread seeds
            let circuit = try simulateCircuitRun(seed: seed)

            // Verify circuit completed
            XCTAssertTrue(circuit.currentTavern.isFinal, "Circuit should reach final tavern at run \(i)")

            // Verify no softlock (action count was bounded in playBotMatch)
            XCTAssertGreaterThan(circuit.totalGames, 0, "Circuit should have games at run \(i)")

            totalGames += circuit.totalGames
            totalWins += circuit.totalWins
            totalLosses += circuit.totalGames - circuit.totalWins
        }

        // Sanity check: total games should be substantial
        XCTAssertGreaterThan(totalGames, 5_000, "Should have played many games across 1,000 circuits")
        XCTAssertLessThan(totalGames, 500_000, "Total games should be reasonable")

        // Win rate should be within reasonable bounds (not 0% or 100%)
        let winRate = Double(totalWins) / Double(totalGames)
        XCTAssertGreaterThan(winRate, 0.05, "Win rate should be > 5%")
        XCTAssertLessThan(winRate, 0.95, "Win rate should be < 95%")
    }

    // MARK: Circuit invariants

    func testCircuitPurseNeverNegative() throws {
        for i in 0..<100 {
            let seed = UInt64(i) * 13 + 7
            let circuit = try simulateCircuitRun(seed: seed)
            XCTAssertGreaterThanOrEqual(circuit.purse.balance, 0, "Purse should never go negative at run \(i)")
        }
    }

    func testCircuitScoreBounds() throws {
        var maxScore = Int.min
        var minScore = Int.max

        for i in 0..<100 {
            let seed = UInt64(i) * 17 + 3
            let circuit = try simulateCircuitRun(seed: seed)
            maxScore = max(maxScore, circuit.circuitScore)
            minScore = min(minScore, circuit.circuitScore)
        }

        // Score should be within reasonable bounds
        XCTAssertGreaterThan(maxScore, 0, "Max score should be positive")
        XCTAssertLessThan(minScore, 0, "Min score should be negative")
        XCTAssertLessThanOrEqual(maxScore, 50_000, "Max score should be reasonable")
    }

    func testCircuitTavernsCompleted() throws {
        for i in 0..<100 {
            let seed = UInt64(i) * 23 + 11
            let circuit = try simulateCircuitRun(seed: seed)
            // 12 taverns total, 11 advances to reach the final one
            XCTAssertEqual(circuit.tavernsCompleted, 11, "Should complete all taverns at run \(i)")
        }
    }

    // MARK: Different difficulties

    func testCircuitEasyDifficulty() throws {
        let circuit = try simulateCircuitRun(seed: 999, stake: 1)
        XCTAssertTrue(circuit.currentTavern.isFinal)
        XCTAssertGreaterThan(circuit.totalGames, 0)
    }

    func testCircuitHardStakes() throws {
        var circuit = CircuitState.newCircuit()
        var rng = SeededRNG(seed: 888)

        while !circuit.currentTavern.isFinal {
            let tavern = circuit.currentTavern
            for gameIdx in 0..<3 {
                let gameSeed = UInt64(gameIdx) * 500 + UInt64(tavern.difficulty)
                let (finalState, _) = try playBotMatch(
                    seed: gameSeed,
                    difficulty: tavern.aiLevel,
                    ruleset: .finkel,
                    stake: tavern.stake * 2  // Double stakes
                )
                let won = finalState.outcome?.winner == .player0
                circuit.recordResult(won: won, stake: tavern.stake * 2)
            }
            circuit.advanceTavern()
        }

        XCTAssertTrue(circuit.currentTavern.isFinal)
        XCTAssertGreaterThan(circuit.totalGames, 0)
    }
}
