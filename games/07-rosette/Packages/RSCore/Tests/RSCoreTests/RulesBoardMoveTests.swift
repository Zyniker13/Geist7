import XCTest
@testable import RSCore

/// R-1 (board and pieces) and R-2/R-3/R-4/R-18 (moves).
final class RulesBoardMoveTests: XCTestCase {
  // MARK: R-1

  func testR1_FinkelSetupHasSevenPiecesEachOffBoard() {
    let state = MatchState.finkelMatch(stake: 2, omens: [])
    XCTAssertEqual(state.pieces.count, 14)
    XCTAssertEqual(state.pieces.filter { $0.owner == .player0 }.count, 7)
    XCTAssertEqual(state.pieces.filter { $0.owner == .player1 }.count, 7)
    XCTAssertTrue(state.pieces.allSatisfy { $0.position == -1 })
  }

  func testR1_TrackLayoutFourPrivateEightSharedTwoPrivate() {
    let track = TestSupport.finkelRuleset.makeTrack()
    XCTAssertEqual(track.length, 14)
    XCTAssertEqual(Array(track.squares[0..<4].map { $0.owner }), Array(repeating: .startPrivate, count: 4))
    XCTAssertEqual(Array(track.squares[4..<12].map { $0.owner }), Array(repeating: .shared, count: 8))
    XCTAssertEqual(Array(track.squares[12..<14].map { $0.owner }), Array(repeating: .exitPrivate, count: 2))
  }

  func testR1_RosettesAtPathSteps4And8And14CentralSafe() {
    let track = TestSupport.finkelRuleset.makeTrack()
    // Path steps 4, 8 and 14 are 0-based indices 3, 7 and 13.
    XCTAssertEqual(track.rosetteIndices, [3, 7, 13])
    XCTAssertTrue(Rosette.isRosette(at: 3, track: track))
    XCTAssertTrue(Rosette.isRosette(at: 7, track: track))
    XCTAssertTrue(Rosette.isRosette(at: 13, track: track))
    // Only the shared central rosette (index 7) is safe (R-5).
    XCTAssertEqual(track.safeRosetteIndices, [7])
  }

  // MARK: R-2

  func testR2_Tetra4MatchesExcavatedDistribution() {
    let model = DiceModel.tetra4
    XCTAssertEqual(model.outcomes.map { $0.value }, [0, 1, 2, 3, 4])
    XCTAssertEqual(model.outcomes.map { $0.weight }, [1, 4, 6, 4, 1])
    XCTAssertEqual(model.denominator, 16)
    XCTAssertEqual(model.totalWeight, model.denominator)
  }

  // MARK: R-3

  func testR3_MoveExactlyN() throws {
    let start = TestSupport.state(
      dice: TestSupport.loaded(3),
      player0: [5, -1, -1, -1, -1, -1, -1],
      player1: Array(repeating: -1, count: 7)
    )
    let moved = try TestSupport.rollAndMove(start, diceSeed: 3).state
    let mover = moved.pieces.first { $0.owner == .player0 && $0.id == 0 }
    XCTAssertEqual(mover?.position, 8)
    XCTAssertEqual(moved.currentPlayer, .player1)
  }

  func testR3_RollOfZeroPassesTurn() throws {
    let start = TestSupport.state(
      dice: TestSupport.loaded(0),
      player0: Array(repeating: -1, count: 7),
      player1: Array(repeating: -1, count: 7)
    )
    let (rolled, events) = try TestSupport.apply(.roll, to: start)
    XCTAssertNil(rolled.diceValue)
    XCTAssertFalse(rolled.hasRolled)
    XCTAssertEqual(rolled.currentPlayer, .player1)
    XCTAssertTrue(events.contains(.turnPassed))
  }

  func testR3_NoLegalMovePassesTurn() throws {
    // The rearmost run 2-6 is packed with own pieces and the frontmost
    // piece's landing square is the central rosette (7) held by the
    // opponent — with a roll of 1 no piece can legally move (R-4, R-5).
    let start = TestSupport.state(
      dice: TestSupport.loaded(1),
      player0: [2, 3, 4, 5, 6, -2, -2],
      player1: [7, -1, -1, -1, -1, -1, -1]
    )
    let (rolled, events) = try TestSupport.apply(.roll, to: start)
    XCTAssertEqual(rolled.currentPlayer, .player1, "turn must pass when no legal move exists")
    XCTAssertFalse(rolled.hasRolled)
    XCTAssertTrue(events.contains(.turnPassed))
  }

  func testR3_MoveRequiresRoll() throws {
    let start = TestSupport.state(player0: [5, -1, -1, -1, -1, -1, -1], player1: Array(repeating: -1, count: 7))
    XCTAssertThrowsError(try TestSupport.apply(.move(0), to: start)) { error in
      guard case RuleError.noDiceRolled = error else {
        return XCTFail("expected noDiceRolled, got \(error)")
      }
    }
  }

  // MARK: R-4

  func testR4_CannotLandOnOwnPiece() throws {
    let start = TestSupport.state(
      dice: TestSupport.loaded(3),
      player0: [5, 8, -1, -1, -1, -1, -1],
      player1: Array(repeating: -1, count: 7)
    )
    let (rolled, _) = try TestSupport.apply(.roll, to: start)
    let moves = MoveGen.legalMoves(
      for: rolled.currentPlayer,
      amount: 3,
      pieces: rolled.pieces,
      track: rolled.track,
      rules: rolled.ruleset
    )
    XCTAssertFalse(moves.contains { $0.piece == 0 && $0.destination == 8 })
    XCTAssertTrue(moves.contains { $0.piece == 1 && $0.destination == 11 })
  }

  // MARK: R-18

  func testR18_SingleLegalMoveIsDetectable() {
    let start = TestSupport.state(
      player0: [6, 7, -2, -2, -2, -2, -2],
      player1: Array(repeating: -1, count: 7)
    )
    // Roll of 1: piece 0 at 6 is blocked by piece 1 at 7; piece 1 at 7 can go
    // to 8 — exactly one legal move (R-18 Assist triggers on this).
    let moves = MoveGen.legalMoves(for: .player0, amount: 1, pieces: start.pieces, track: start.track, rules: start.ruleset)
    XCTAssertEqual(moves, [Move(piece: 1, destination: 8)])
  }
}
