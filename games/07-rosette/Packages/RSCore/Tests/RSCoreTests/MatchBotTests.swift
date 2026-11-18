import XCTest

@testable import RSCore

/// A bot with fixed cube answers, for driving the cube flow deterministically.
/// Moves: always the first legal move.
final class ScriptedBot: MatchBot {
    let offersDouble: Bool
    let takesDouble: Bool

    init(offersDouble: Bool = false, takesDouble: Bool = true) {
        self.offersDouble = offersDouble
        self.takesDouble = takesDouble
    }

    func chooseMove(
        from moves: [Move],
        pieces: [Piece],
        track: Track,
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
}

extension MatchState {
    /// A copy with a different current player (test helper).
    func with(currentPlayer: PlayerID) -> MatchState {
        var copy = self
        copy.currentPlayer = currentPlayer
        return copy
    }
}
