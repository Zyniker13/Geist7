import XCTest

@testable import RSCore

/// A bot with fixed cube answers, for driving the cube flow deterministically.
/// Moves: always the first legal move.
final class ScriptedBot: MatchBot, @unchecked Sendable {
    let offersDouble: Bool
    let takesDouble: Bool

    init(offersDouble: Bool = false, takesDouble: Bool = true) {
        self.offersDouble = offersDouble
        self.takesDouble = takesDouble
    }

    func chooseMove(
        from state: MatchState,
        moves: [Move],
        rng: inout SeededRNG
    ) -> Move? {
        moves.first
    }

    func decideDouble(state: MatchState, rng: inout SeededRNG) -> Bool {
        takesDouble
    }

    func wantsDouble(state: MatchState, rng: inout SeededRNG) -> Bool {
        offersDouble
    }

    func chooseOmen(
        state: MatchState,
        options: [Omen],
        rng: inout SeededRNG
    ) -> Omen? {
        nil
    }
}

/// R-10 cube flow through `BotMatch`: offer eligibility (R-21 once per turn,
/// R-22 dead cube, R-10 ownership and the 64 cap), offer-accept raising the
/// stake and passing cube ownership, a decline ending the match at the
/// current stake, and replay determinism (INV-4) with cube actions present.
final class MatchBotTests: XCTestCase {
    // MARK: canOfferDouble (R-10, R-21, R-22)

    func testCanOfferDouble_CentredCubeAnyPlayer() {
        let state = TestSupport.state(
            player0: [3, -1, -1, -1, -1, -1, -1],
            player1: [7, -1, -1, -1, -1, -1, -1]
        )
        XCTAssertTrue(BotMatch.canOfferDouble(in: state))
        let other = state.with(currentPlayer: .player1)
        XCTAssertTrue(BotMatch.canOfferDouble(in: other))
    }

    func testCanOfferDouble_OwnerOnly() {
        let owned = TestSupport.state(
            player0: [3, -1, -1, -1, -1, -1, -1],
            player1: [7, -1, -1, -1, -1, -1, -1],
            currentPlayer: .player0,
            cube: DoublingCube(value: 2, owner: PlayerID.player1.rawValue)
        )
        XCTAssertFalse(
            BotMatch.canOfferDouble(in: owned),
            "player0 does not own the cube")
        let owner = owned.with(currentPlayer: .player1)
        XCTAssertTrue(BotMatch.canOfferDouble(in: owner))
    }

    func testCanOfferDouble_DeadCubeAfterFirstDouble() {
        let state = TestSupport.state(
            player0: [3, -1, -1, -1, -1, -1, -1],
            player1: [7, -1, -1, -1, -1, -1, -1],
            cubeDead: true
        )
        XCTAssertFalse(
            BotMatch.canOfferDouble(in: state),
            "the Crawford cube is dead (R-22)")
    }

    func testCanOfferDouble_OncePerTurn() {
        var state = TestSupport.state(
            player0: [3, -1, -1, -1, -1, -1, -1],
            player1: [7, -1, -1, -1, -1, -1, -1]
        )
        XCTAssertTrue(BotMatch.canOfferDouble(in: state))
        state.hasDoubledThisTurn = true
        XCTAssertFalse(
            BotMatch.canOfferDouble(in: state),
            "R-21: one double per turn")
    }

    func testCanOfferDouble_MaxCubeCap() {
        let atCap = TestSupport.state(
            player0: [3, -1, -1, -1, -1, -1, -1],
            player1: [7, -1, -1, -1, -1, -1, -1],
            cube: DoublingCube(value: 64, owner: -1)
        )
        XCTAssertFalse(
            BotMatch.canOfferDouble(in: atCap),
            "the value may not pass 64 (R-10)")
        let belowCap = TestSupport.state(
            player0: [3, -1, -1, -1, -1, -1, -1],
            player1: [7, -1, -1, -1, -1, -1, -1],
            cube: DoublingCube(value: 32, owner: -1)
        )
        XCTAssertTrue(BotMatch.canOfferDouble(in: belowCap))
    }

    // MARK: Cube flow in matches

    func testCubeFlow_OfferAndAcceptDoublesStakeOnce() throws {
        // bot0 offers every fresh turn; bot1 accepts but never re-offers:
        // the cube rises exactly once, from 1 to 2, and ownership passes
        // to the accepter (R-10).
        let record = try BotMatch.play(
            seed: 77,
            ruleset: .finkel,
            dice: .tetra4,
            stake: 2,
            bot0: ScriptedBot(offersDouble: true, takesDouble: true),
            bot1: ScriptedBot(offersDouble: false, takesDouble: true)
        )
        XCTAssertTrue(record.finalState.isComplete)
        XCTAssertEqual(record.finalState.cube.value, 2, "one accept, cube 1 → 2")
        XCTAssertEqual(record.finalState.cube.owner, PlayerID.player1.rawValue)
        XCTAssertEqual(record.finalState.stake.value, 4, "the stake doubles on accept")
        XCTAssertEqual(record.finalState.outcome?.cubeValue, 2)
        XCTAssertTrue(record.actions.contains(.offerDouble))
        XCTAssertTrue(record.actions.contains(.acceptDouble))
        XCTAssertFalse(record.actions.contains(.concede))
    }

    func testCubeFlow_RepeatedOffersClimbTowardCap() throws {
        // Both bots offer and always accept: the cube climbs rung by rung
        // and may not pass 64 (R-10). The stake always equals twice the cube.
        let record = try BotMatch.play(
            seed: 78,
            ruleset: .finkel,
            dice: .tetra4,
            stake: 2,
            bot0: ScriptedBot(offersDouble: true, takesDouble: true),
            bot1: ScriptedBot(offersDouble: true, takesDouble: true)
        )
        XCTAssertTrue(record.finalState.isComplete)
        let cube = record.finalState.cube.value
        XCTAssertTrue((2...64).contains(cube), "cube climbed to \(cube)")
        XCTAssertLessThanOrEqual(cube, 64)
        XCTAssertEqual(record.finalState.stake.value, 2 * cube)
        XCTAssertEqual(record.finalState.outcome?.cubeValue, cube)
    }

    func testCubeFlow_DeclineEndsMatchAtCurrentStake() throws {
        // bot0 offers on its first turn; bot1 declines (concedes). The match
        // ends at the current stake: the cube stays 1, the stake stays 2,
        // and the offerer wins (R-10 via ADR-0005).
        let record = try BotMatch.play(
            seed: 79,
            ruleset: .finkel,
            dice: .tetra4,
            stake: 2,
            bot0: ScriptedBot(offersDouble: true, takesDouble: true),
            bot1: ScriptedBot(offersDouble: false, takesDouble: false)
        )
        XCTAssertTrue(record.finalState.isComplete)
        XCTAssertEqual(record.finalState.outcome?.winner, .player0)
        XCTAssertEqual(record.finalState.outcome?.cubeValue, 1, "a decline never moves the cube")
        XCTAssertEqual(record.finalState.stake.value, 2, "a decline keeps the current stake")
        XCTAssertTrue(record.actions.contains(.offerDouble))
        XCTAssertTrue(record.actions.contains(.concede))
    }

    func testCubeFlow_ReplayDeterminism() throws {
        for seed: UInt64 in [80, 81] {
            let first = try BotMatch.play(
                seed: seed,
                ruleset: .finkel,
                dice: .tetra4,
                stake: 2,
                bot0: ScriptedBot(offersDouble: true, takesDouble: true),
                bot1: ScriptedBot(offersDouble: false, takesDouble: true)
            )
            let second = try BotMatch.play(
                seed: seed,
                ruleset: .finkel,
                dice: .tetra4,
                stake: 2,
                bot0: ScriptedBot(offersDouble: true, takesDouble: true),
                bot1: ScriptedBot(offersDouble: false, takesDouble: true)
            )
            XCTAssertEqual(first.actions, second.actions)
            XCTAssertEqual(first.events, second.events)
            XCTAssertEqual(first.finalState, second.finalState)
            XCTAssertEqual(first.finalState.stateHash, second.finalState.stateHash)
        }
    }

    func testCubeFlow_MatchesStillComplete() throws {
        // Cube play must not stall the driver: full matches with cube
        // activity complete within the action guard (INV-1/INV-4 harness).
        for seed: UInt64 in [82, 83, 84] {
            let record = try BotMatch.play(
                seed: seed,
                ruleset: .finkel,
                dice: .tetra4,
                stake: 2,
                bot0: ScriptedBot(offersDouble: true, takesDouble: true),
                bot1: ScriptedBot(offersDouble: false, takesDouble: true)
            )
            XCTAssertTrue(record.finalState.isComplete, "seed \(seed)")
            XCTAssertTrue(record.finalState.pieceConservationValid, "seed \(seed)")
            XCTAssertLessThan(record.actions.count, 100_000)
        }
    }
    func testFixedDiceSequenceDrivesRolls() throws {
        // A caller-supplied dice sequence (the daily match, P5) must drive
        // every roll: the k-th diceRolled event equals the k-th sequence
        // value, independent of the RNG seed. A full Finkel match takes
        // ~400 rolls, so 5000 values never exhaust mid-match.
        var rng = SeededRNG(seed: 7)
        let sequence = (0..<5000).map { _ in DiceModel.tetra4.roll(rng: &rng) }
        let record = try BotMatch.play(
            seed: 99,
            ruleset: .finkel,
            dice: .tetra4,
            stake: 2,
            bot0: RosetteBot(personality: .careful, strength: 2),
            bot1: RosetteBot(personality: .careful, strength: 2),
            diceSequence: sequence
        )
        let rolls = record.events.compactMap { event -> Int? in
            if case .diceRolled(let value) = event { return value }
            return nil
        }
        XCTAssertFalse(rolls.isEmpty)
        XCTAssertLessThanOrEqual(rolls.count, sequence.count)
        for (index, value) in rolls.enumerated() {
            XCTAssertEqual(value, sequence[index], "roll \(index)")
        }
    }

    func testDiceSequenceIdenticalAcrossBotPolicies() throws {
        // "Same for everyone": two players facing the same date draw the
        // same dice stream no matter how they play. The k-th roll of each
        // match equals the shared sequence prefix.
        var rng = SeededRNG(seed: 1234)
        let sequence = (0..<5000).map { _ in DiceModel.tetra4.roll(rng: &rng) }
        let a = try BotMatch.play(
            seed: 5,
            ruleset: .finkel,
            dice: .tetra4,
            stake: 2,
            bot0: RosetteBot(personality: .careful, strength: 1),
            bot1: RosetteBot(personality: .careful, strength: 4),
            diceSequence: sequence
        )
        let b = try BotMatch.play(
            seed: 5,
            ruleset: .finkel,
            dice: .tetra4,
            stake: 2,
            bot0: RosetteBot(personality: .careful, strength: 4),
            bot1: RosetteBot(personality: .careful, strength: 1),
            diceSequence: sequence
        )
        func rolls(_ record: BotMatch.Record) -> [Int] {
            record.events.compactMap { event -> Int? in
                if case .diceRolled(let value) = event { return value }
                return nil
            }
        }
        let ra = rolls(a), rb = rolls(b)
        let shared = min(ra.count, rb.count)
        XCTAssertGreaterThanOrEqual(shared, 10)
        for index in 0..<shared {
            XCTAssertEqual(ra[index], rb[index], "shared roll \(index)")
            XCTAssertEqual(ra[index], sequence[index], "sequence roll \(index)")
        }
    }

    func testDiceSequenceExhaustionFallsBackToRNG() throws {
        // A sequence shorter than the match falls back to the seeded RNG
        // rather than crashing (INV-1: the match still completes).
        let record = try BotMatch.play(
            seed: 42,
            ruleset: .finkel,
            dice: .tetra4,
            stake: 2,
            bot0: RosetteBot(personality: .careful, strength: 2),
            bot1: RosetteBot(personality: .careful, strength: 2),
            diceSequence: [2, 0]
        )
        XCTAssertTrue(record.finalState.isComplete)
        XCTAssertTrue(record.finalState.pieceConservationValid)
    }
}

extension MatchState {
    /// A copy with a different current player (test helper).
    func with(currentPlayer: PlayerID) -> MatchState {
        var copy = self
        copy.currentPlayer = currentPlayer
        return copy
    }
}
