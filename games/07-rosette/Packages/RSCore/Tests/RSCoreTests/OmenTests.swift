import XCTest
@testable import RSCore

/// R-12 (omens), R-23 (effects never change dice probabilities),
/// INV-7 (separate omen RNG stream).
final class OmenTests: XCTestCase {
  private let reroll = Omen(id: "reroll-1", effect: .reroll(count: 1), cost: 3, label: .invented)
  private let split = Omen(id: "split-1", effect: .split(count: 1), cost: 4, label: .invented)
  private let unsafeOmen = Omen(id: "unsafe-1", effect: .unsafeRosettes(count: 1), cost: 5, label: .invented)

  func testR12_PlayOmenBeforeRoll() throws {
    let start = TestSupport.state(
      player0: Array(repeating: -1, count: 7),
      player1: Array(repeating: -1, count: 7),
      omens0: [reroll]
    )
    let (played, events) = try TestSupport.apply(.playOmen(omenId: "reroll-1"), to: start)
    XCTAssertEqual(played.pendingOmen?.id, "reroll-1")
    XCTAssertEqual(played.omensPlayed[.player0], "reroll-1")
    XCTAssertTrue((played.omensHeld[.player0] ?? []).isEmpty, "the played omen leaves the hand")
    XCTAssertTrue(events.contains(Event.omenPlayed(omenId: "reroll-1", player: .player0)))
  }

  func testR12_OmensOnlyBeforeTheRoll() throws {
    let start = TestSupport.state(
      dice: TestSupport.loaded(1),
      player0: [2, -1, -1, -1, -1, -1, -1],
      player1: Array(repeating: -1, count: 7),
      omens0: [reroll]
    )
    let (rolled, _) = try TestSupport.apply(.roll, to: start)
    XCTAssertThrowsError(try TestSupport.apply(.playOmen(omenId: "reroll-1"), to: rolled)) { error in
      guard case RuleError.illegalAction = error else {
        return XCTFail("expected illegalAction, got \(error)")
      }
    }
  }

  func testR12_OneOmenPerMatch() throws {
    var state = TestSupport.state(
      dice: TestSupport.loaded(0),
      player0: Array(repeating: -1, count: 7),
      player1: Array(repeating: -1, count: 7),
      omens0: [reroll, split]
    )
    let (played, _) = try TestSupport.apply(.playOmen(omenId: "reroll-1"), to: state)
    state = played
    // Rolls of 0 pass; two turns later the same player may not play again.
    let (passed1, _) = try TestSupport.apply(.roll, to: state, diceSeed: 7)
    let (passed2, _) = try TestSupport.apply(.roll, to: passed1, diceSeed: 7)
    state = passed2
    XCTAssertThrowsError(try TestSupport.apply(.playOmen(omenId: "split-1"), to: state)) { error in
      guard case RuleError.illegalAction = error else {
        return XCTFail("expected illegalAction, got \(error)")
      }
    }
  }

  func testR12_OmenMustBeHeld() throws {
    let start = TestSupport.state(player0: Array(repeating: -1, count: 7), player1: Array(repeating: -1, count: 7))
    XCTAssertThrowsError(try TestSupport.apply(.playOmen(omenId: "reroll-1"), to: start))
  }

  // MARK: Reroll (R-23, INV-7)

  func testR12_INV7_RerollUsesSeparateStreamAndDiceStreamIsUnchanged() throws {
    // Mirror the two streams: dice draws d1, d2 from seed 5; the omen
    // stream's first draw o1 from seed 9.
    var diceProbe = SeededRNG(seed: 5)
    let firstDraw = DiceModel.tetra4.roll(rng: &diceProbe)
    let secondDraw = DiceModel.tetra4.roll(rng: &diceProbe)
    var omenProbe = SeededRNG(seed: 9)
    let omenDraw = DiceModel.tetra4.roll(rng: &omenProbe)

    var state = TestSupport.state(
      player0: [5, -1, -1, -1, -1, -1, -1],
      player1: Array(repeating: -1, count: 7),
      omens0: [reroll]
    )
    var rng = SeededRNG(seed: 5)
    var omenRng = SeededRNG(seed: 9)

    // Play the omen (no draws consumed), then roll.
    let played = try Reducer.apply(.playOmen(omenId: "reroll-1"), to: state, rng: &rng, omenRng: &omenRng)
    let rolled = try Reducer.apply(.roll, to: played.state, rng: &rng, omenRng: &omenRng)

    // The visible amount is the omen stream's draw; the omen is spent and
    // leaves the hand; both the original and the replacement were recorded.
    XCTAssertEqual(rolled.state.diceValue, omenDraw)
    if omenDraw != firstDraw {
      XCTAssertNotEqual(rolled.state.diceValue, firstDraw)
    }
    XCTAssertNil(rolled.state.pendingOmen)
    XCTAssertEqual(rolled.state.omensHeld[.player0]?.count, 0)
    XCTAssertEqual(rolled.events.filter { event in
      if case .diceRolled = event { return true } else { return false }
    }.count, 2)

    // INV-7: the reroll consumed no dice-stream draw. The next roll must be
    // the dice stream's SECOND draw (d2), not a third one.
    let passed = Reducer.endTurn(rolled.state)
    let nextRolled = try Reducer.apply(.roll, to: passed, rng: &rng, omenRng: &omenRng)
    if secondDraw == 0 {
      XCTAssertNil(nextRolled.state.diceValue, "a roll of 0 passes the turn")
    } else {
      XCTAssertEqual(nextRolled.state.diceValue, secondDraw)
    }
  }

  // MARK: Split (R-12)

  func testR12_SplitSplitsTheRollIntoTwoMoves() throws {
    var state = TestSupport.state(
      dice: TestSupport.loaded(4),
      player0: [3, 5, -1, -1, -1, -1, -1],
      player1: Array(repeating: -1, count: 7),
      omens0: [split]
    )
    (state, _) = try TestSupport.apply(.playOmen(omenId: "split-1"), to: state)
    let (rolled, _) = try TestSupport.apply(.roll, to: state, diceSeed: 3)
    XCTAssertTrue(rolled.splitActive)
    XCTAssertEqual(rolled.splitRemaining, 2)
    XCTAssertEqual(rolled.diceValue, 2, "the first half of 4 is 2")
    // Piece 1 (at 5) is the only one that can take the first half: piece 0
    // would land on 5, which piece 1 holds (R-4).
    XCTAssertEqual(rolled.movablePieceIds, Set([1]))

    let (firstMove, _) = try TestSupport.apply(.move(1), to: rolled, diceSeed: 3)
    XCTAssertEqual(firstMove.diceValue, 2, "the second half is still to move")
    XCTAssertFalse(firstMove.splitActive)
    XCTAssertTrue(firstMove.movablePieceIds.contains(0))

    let (secondMove, _) = try TestSupport.apply(.move(0), to: firstMove, diceSeed: 3)
    XCTAssertEqual(secondMove.pieces.first { $0.owner == .player0 && $0.id == 0 }?.position, 5)
    XCTAssertEqual(secondMove.pieces.first { $0.owner == .player0 && $0.id == 1 }?.position, 7)
    XCTAssertEqual(secondMove.plies, 2)
    // The split's first half landed on the central rosette (7), so the turn
    // does not pass: the player earns another roll (R-6 applies mid-split).
    XCTAssertEqual(secondMove.currentPlayer, .player0)
    XCTAssertFalse(secondMove.hasRolled)
  }

  func testR12_SplitFizzleToFullRollWhenOnlyEntriesExist() throws {
    var state = TestSupport.state(
      dice: TestSupport.loaded(2),
      player0: Array(repeating: -1, count: 7),
      player1: Array(repeating: -1, count: 7),
      omens0: [split]
    )
    (state, _) = try TestSupport.apply(.playOmen(omenId: "split-1"), to: state)
    let (rolled, _) = try TestSupport.apply(.roll, to: state, diceSeed: 3)
    // Only waiting pieces exist: entering spends the whole roll, so the
    // split (1+1) fizzles into a normal single move of the full roll.
    XCTAssertFalse(rolled.splitActive)
    XCTAssertNil(rolled.splitRemaining)
    XCTAssertEqual(rolled.diceValue, 2)
    XCTAssertFalse(rolled.movablePieceIds.isEmpty, "entries remain available for the full roll")
  }

  // MARK: Unsafe rosettes (R-12, R-23)

  func testR12_UnsafeRosettesAllowsCentralCapture() throws {
    var state = TestSupport.state(
      dice: TestSupport.loaded(2),
      player0: [5, -1, -1, -1, -1, -1, -1],
      player1: [7, -1, -1, -1, -1, -1, -1],
      omens0: [unsafeOmen]
    )
    (state, _) = try TestSupport.apply(.playOmen(omenId: "unsafe-1"), to: state)
    let (moved, events) = try TestSupport.rollAndMove(state, diceSeed: 3)
    XCTAssertEqual(moved.pieces.first { $0.owner == .player1 && $0.id == 0 }?.position, -1)
    XCTAssertTrue(events.contains(Event.pieceCaptured(piece: 0, by: .player0)))
  }
}
