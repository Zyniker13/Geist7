import XCTest
@testable import RSCore

/// INV-1 (piece conservation), INV-3 (purse and cube bounds),
/// INV-4 (replay determinism).
final class InvariantTests: XCTestCase {
  // MARK: INV-1

  func testINV1_FreshStateConservesPieces() {
    let state = MatchState.finkelMatch(stake: 2, omens: [])
    XCTAssertTrue(state.pieceConservationValid)
  }

  func testINV1_DetectsCorruptedStates() throws {
    var corrupt = MatchState.finkelMatch(stake: 2, omens: [])
    corrupt.pieces[3] = Piece(id: 3, owner: .player0, position: 99)
    XCTAssertFalse(corrupt.pieceConservationValid)

    var counterMismatch = MatchState.finkelMatch(stake: 2, omens: [])
    counterMismatch.borneOff[.player0] = 3
    XCTAssertFalse(counterMismatch.pieceConservationValid)
  }

  func testINV1_ConservationHoldsThroughWholeRandomMatches() throws {
    for seed: UInt64 in [11, 22, 33, 44, 55] {
      let (final, actions, _) = try TestSupport.playRandomMatch(seed: seed)
      XCTAssertTrue(final.pieceConservationValid, "seed \(seed): conservation broken")
      XCTAssertTrue(final.isComplete, "seed \(seed): match should complete within the guard")
      XCTAssertLessThan(actions.count, 100_000)
    }
  }

  // MARK: INV-3

  func testINV3_PurseNeverGoesNegative() {
    var purse = Purse.newPurse()
    purse.add(10)
    XCTAssertEqual(purse.balance, 10)
    XCTAssertFalse(purse.pay(11), "paying beyond the balance must fail")
    XCTAssertEqual(purse.balance, 10, "the balance is unchanged after a failed payment")
    XCTAssertTrue(purse.pay(10))
    XCTAssertEqual(purse.balance, 0)
    XCTAssertTrue(purse.isEmpty)
    purse.add(-4)
    XCTAssertEqual(purse.balance, 0, "the balance never goes negative")
    XCTAssertEqual(purse.totalEarned, 10)
  }

  func testINV3_CubeValueStaysWithinPowerLadder() throws {
    var cube = DoublingCube.centered
    var nextOfferer: PlayerID?
    for expectedValue in [2, 4, 8, 16, 32, 64] {
      // A centred cube may be offered by anyone; afterwards only its owner.
      let offerer = nextOfferer ?? .player0
      XCTAssertNil(cube.validateOffer(by: offerer, maxCube: 64))
      // On acceptance the stake doubles and the cube passes to the accepter.
      let accepter: PlayerID = offerer == .player0 ? .player1 : .player0
      cube = DoublingCube(value: expectedValue, owner: accepter.rawValue)
      nextOfferer = accepter
    }
    XCTAssertEqual(
      cube.validateOffer(by: nextOfferer ?? .player0, maxCube: 64),
      .maxExceeded,
      "64 is the last rung"
    )
  }

  // MARK: INV-4

  func testINV4_ReplayDeterminism() throws {
    let (firstState, firstActions, firstEvents) = try TestSupport.playRandomMatch(seed: 424_242)
    let (secondState, secondActions, secondEvents) = try TestSupport.playRandomMatch(seed: 424_242)
    XCTAssertEqual(firstActions, secondActions)
    XCTAssertEqual(firstEvents, secondEvents)
    XCTAssertEqual(firstState, secondState)
    XCTAssertEqual(firstState.stateHash, secondState.stateHash)
    XCTAssertTrue(firstState.isComplete)
  }

  func testINV4_DifferentSeedsDiverge() throws {
    let (first, _, _) = try TestSupport.playRandomMatch(seed: 1)
    let (second, _, _) = try TestSupport.playRandomMatch(seed: 2)
    XCTAssertNotEqual(first.stateHash, second.stateHash, "different seeds must produce different matches")
  }

  func testINV4_StateHashIsStableAcrossRuns() {
    let state = TestSupport.state(
      player0: [3, 5, -1, -1, -1, -2, -2],
      player1: [7, -1, -1, -1, -1, -1, -1]
    )
    let again = TestSupport.state(
      player0: [3, 5, -1, -1, -1, -2, -2],
      player1: [7, -1, -1, -1, -1, -1, -1]
    )
    XCTAssertEqual(state.stateHash, again.stateHash, "identical states hash identically")

    var shifted = state
    shifted.pieces[0].position = 4
    XCTAssertNotEqual(state.stateHash, shifted.stateHash, "a gameplay change must change the hash")
  }
}
