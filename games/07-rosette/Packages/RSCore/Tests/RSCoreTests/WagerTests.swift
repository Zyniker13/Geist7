import XCTest
@testable import RSCore

/// R-9 (stake), R-10 (cube), R-11 (gammon), R-21 (once per turn, omen first),
/// R-22 (Crawford).
final class WagerTests: XCTestCase {
  // MARK: R-9

  func testR9_StakeAgreedBeforeMatch() throws {
    let start = TestSupport.state(player0: Array(repeating: -1, count: 7), player1: Array(repeating: -1, count: 7))
    let (staked, events) = try TestSupport.apply(.setStake(5), to: start)
    XCTAssertEqual(staked.stake.value, 5)
    XCTAssertTrue(events.contains(Event.stakeSet(value: 5)))
  }

  func testR9_StakeMustBePositive() throws {
    let start = TestSupport.state(player0: Array(repeating: -1, count: 7), player1: Array(repeating: -1, count: 7))
    XCTAssertThrowsError(try TestSupport.apply(.setStake(0), to: start))
    XCTAssertThrowsError(try TestSupport.apply(.setStake(-3), to: start))
  }

  func testR9_StakeLockedOncePlayBegins() throws {
    let start = TestSupport.state(
      dice: TestSupport.loaded(1),
      player0: [2, -1, -1, -1, -1, -1, -1],
      player1: Array(repeating: -1, count: 7)
    )
    let moved = try TestSupport.rollAndMove(start, diceSeed: 3).state
    XCTAssertThrowsError(try TestSupport.apply(.setStake(9), to: moved))
  }

  // MARK: R-10

  func testR10_OfferIsProposalOnlyAcceptDoublesStakeAndPassesCube() throws {
    let start = TestSupport.state(player0: Array(repeating: -1, count: 7), player1: Array(repeating: -1, count: 7), stake: 2)
    let (offered, offerEvents) = try TestSupport.apply(.offerDouble, to: start)
    XCTAssertTrue(offered.doubleOffered)
    XCTAssertEqual(offered.stake.value, 2, "the stake changes only on acceptance")
    XCTAssertEqual(offered.cube.value, 1, "the cube changes only on acceptance")
    XCTAssertTrue(offerEvents.contains(Event.doubleOffered(by: .player0)))

    let (accepted, acceptEvents) = try TestSupport.apply(.acceptDouble, to: offered)
    XCTAssertEqual(accepted.stake.value, 4)
    XCTAssertEqual(accepted.cube.value, 2)
    XCTAssertEqual(accepted.cube.owner, PlayerID.player1.rawValue, "the cube passes to the accepter")
    XCTAssertFalse(accepted.doubleOffered)
    XCTAssertTrue(acceptEvents.contains(Event.cubeDoubled(newValue: 2, newOwner: .player1)))
  }

  func testR10_OnlyCubeOwnerOrCentredMayOffer() throws {
    let start = TestSupport.state(
      player0: Array(repeating: -1, count: 7),
      player1: Array(repeating: -1, count: 7),
      cube: DoublingCube(value: 2, owner: PlayerID.player1.rawValue)
    )
    XCTAssertThrowsError(try TestSupport.apply(.offerDouble, to: start)) { error in
      guard case RuleError.cubeError(.notOwner) = error else {
        return XCTFail("expected cubeError(.notOwner), got \(error)")
      }
    }
  }

  func testR10_CubeCapsAt64() throws {
    let start = TestSupport.state(
      player0: Array(repeating: -1, count: 7),
      player1: Array(repeating: -1, count: 7),
      cube: DoublingCube(value: 64, owner: -1)
    )
    XCTAssertThrowsError(try TestSupport.apply(.offerDouble, to: start)) { error in
      guard case RuleError.cubeError(.maxExceeded) = error else {
        return XCTFail("expected cubeError(.maxExceeded), got \(error)")
      }
    }
  }

  func testR10_DeclineByConcedeLosesCurrentStake() throws {
    let start = TestSupport.state(player0: Array(repeating: -1, count: 7), player1: Array(repeating: -1, count: 7), stake: 2)
    let (offered, _) = try TestSupport.apply(.offerDouble, to: start)
    let (conceded, events) = try TestSupport.apply(.concede, to: offered)
    XCTAssertTrue(conceded.isComplete)
    XCTAssertEqual(conceded.outcome?.winner, .player0)
    XCTAssertEqual(conceded.outcome?.cubeValue, 1, "a decline loses the pre-double stake")
    XCTAssertEqual(conceded.outcome?.score(for: .player1), -2)
    XCTAssertTrue(events.contains(Event.conceded(by: .player1)))
  }

  func testR10_ResignationConcedesAtCurrentStake() throws {
    let start = TestSupport.state(
      player0: [5, -1, -1, -1, -1, -1, -1],
      player1: Array(repeating: -1, count: 7),
      stake: 2,
      cube: DoublingCube(value: 4, owner: -1)
    )
    let (conceded, events) = try TestSupport.apply(.concede, to: start)
    XCTAssertEqual(conceded.outcome?.winner, .player1)
    XCTAssertEqual(conceded.outcome?.score(for: .player0), -8, "2 stake x 4 cube")
    XCTAssertTrue(events.contains(Event.matchWon(winner: .player1, gammon: false)))
  }

  // MARK: R-11

  func testR11_GammonDoublesTheScore() throws {
    let outcome = Outcome(winner: .player0, gammon: true, cubeValue: 2, initialStake: 3, plies: 40)
    XCTAssertEqual(outcome.score(for: .player0), 12, "3 x 2 x 2 gammon")
    XCTAssertEqual(outcome.score(for: .player1), -12)
    let plain = Outcome(winner: .player0, gammon: false, cubeValue: 2, initialStake: 3, plies: 40)
    XCTAssertEqual(plain.score(for: .player0), 6)
  }

  // MARK: R-21

  func testR21_DoubleOnlyBeforeRolling() throws {
    let start = TestSupport.state(
      dice: TestSupport.loaded(1),
      player0: [2, -1, -1, -1, -1, -1, -1],
      player1: Array(repeating: -1, count: 7)
    )
    let (rolled, _) = try TestSupport.apply(.roll, to: start)
    XCTAssertThrowsError(try TestSupport.apply(.offerDouble, to: rolled)) { error in
      guard case RuleError.illegalAction = error else {
        return XCTFail("expected illegalAction, got \(error)")
      }
    }
  }

  func testR21_DoubleOnlyOncePerTurn() throws {
    let start = TestSupport.state(player0: Array(repeating: -1, count: 7), player1: Array(repeating: -1, count: 7), stake: 2)
    let (offered, _) = try TestSupport.apply(.offerDouble, to: start)
    let (accepted, _) = try TestSupport.apply(.acceptDouble, to: offered)
    // Same turn (the offerer has not rolled yet): a second double is illegal.
    XCTAssertThrowsError(try TestSupport.apply(.offerDouble, to: accepted))
  }

  func testR21_OmenThenDoubleBothAllowedInOneTurn() throws {
    let omen = Omen(id: "reroll-1", effect: .reroll(count: 1), cost: 3, label: .invented)
    let start = TestSupport.state(
      player0: Array(repeating: -1, count: 7),
      player1: Array(repeating: -1, count: 7),
      omens0: [omen]
    )
    let (omenPlayed, _) = try TestSupport.apply(.playOmen(omenId: "reroll-1"), to: start)
    let (offered, _) = try TestSupport.apply(.offerDouble, to: omenPlayed)
    XCTAssertTrue(offered.doubleOffered)
    XCTAssertEqual(offered.pendingOmen?.id, "reroll-1", "the omen is still pending for the roll")
  }

  func testR21_DoubleBeforeOmenIsRejected() throws {
    let omen = Omen(id: "reroll-1", effect: .reroll(count: 1), cost: 3, label: .invented)
    let start = TestSupport.state(
      player0: Array(repeating: -1, count: 7),
      player1: Array(repeating: -1, count: 7),
      omens0: [omen]
    )
    let (offered, _) = try TestSupport.apply(.offerDouble, to: start)
    let (accepted, _) = try TestSupport.apply(.acceptDouble, to: offered)
    XCTAssertThrowsError(try TestSupport.apply(.playOmen(omenId: "reroll-1"), to: accepted))
  }

  // MARK: R-22

  func testR22_CrawfordKillsTheCube() throws {
    let start = TestSupport.state(
      player0: Array(repeating: -1, count: 7),
      player1: Array(repeating: -1, count: 7),
      cubeDead: true
    )
    XCTAssertThrowsError(try TestSupport.apply(.offerDouble, to: start)) { error in
      guard case RuleError.illegalAction = error else {
        return XCTFail("expected illegalAction, got \(error)")
      }
    }
  }
}
