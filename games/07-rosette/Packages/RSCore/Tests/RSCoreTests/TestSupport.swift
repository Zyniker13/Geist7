import XCTest
@testable import RSCore

/// Shared helpers for the rule-tagged test suites.
enum TestSupport {
  /// A dice model that always rolls `value` (deterministic scenarios).
  static func loaded(_ value: Int) -> DiceModel {
    DiceModel(
      id: "loaded-\(value)",
      label: "Test dice always \(value)",
      outcomes: [DiceOutcome(value: value, weight: 1)],
      denominator: 1,
      note: "Test-only loaded dice."
    )
  }

  /// The Finkel ruleset (same construction as `MatchState.finkelMatch`).
  static var finkelRuleset: RuleSet {
    .finkel
  }

  /// Build a state with pieces placed at explicit positions.
  /// Positions: -1 = waiting to enter, -2 = borne off, 0..<trackLength = on board.
  static func state(
    ruleset: RuleSet = TestSupport.finkelRuleset,
    dice: DiceModel = .tetra4,
    player0: [Int],
    player1: [Int],
    currentPlayer: PlayerID = .player0,
    stake: Int = 2,
    omens0: [Omen] = [],
    omens1: [Omen] = [],
    cube: DoublingCube = .centered,
    cubeDead: Bool = false
  ) -> MatchState {
    var pieces: [Piece] = []
    for (id, position) in player0.enumerated() {
      pieces.append(Piece(id: id, owner: .player0, position: position))
    }
    for (id, position) in player1.enumerated() {
      pieces.append(Piece(id: id, owner: .player1, position: position))
    }
    return MatchState(
      ruleset: ruleset,
      track: ruleset.makeTrack(),
      dice: dice,
      pieces: pieces,
      currentPlayer: currentPlayer,
      diceValue: nil,
      movablePieceIds: [],
      extraRoll: false,
      stake: Stake(value: stake),
      cube: cube,
      cubeDead: cubeDead,
      doubleOffered: false,
      hasDoubledThisTurn: false,
      omensHeld: [.player0: omens0, .player1: omens1],
      omensPlayed: [:],
      pendingOmen: nil,
      splitRemaining: nil,
      splitActive: false,
      hasRolled: false,
      borneOff: [
        .player0: player0.filter { $0 == -2 }.count,
        .player1: player1.filter { $0 == -2 }.count
      ],
      plies: 0,
      isComplete: false,
      outcome: nil
    )
  }

  /// Apply one action with fresh seeded streams.
  static func apply(
    _ action: Action,
    to state: MatchState,
    diceSeed: UInt64 = 101,
    omenSeed: UInt64 = 202
  ) throws -> (MatchState, [Event]) {
    var rng = SeededRNG(seed: diceSeed)
    var omenRng = SeededRNG(seed: omenSeed)
    let result = try Reducer.apply(action, to: state, rng: &rng, omenRng: &omenRng)
    return (result.state, result.events)
  }

  /// Roll, then move the piece chosen by a deterministic pick from legal moves.
  /// Returns the state and all events from both actions.
  static func rollAndMove(
    _ state: MatchState,
    diceSeed: UInt64,
    pickIndex: Int = 0
  ) throws -> (state: MatchState, events: [Event]) {
    let (rolled, rollEvents) = try TestSupport.apply(.roll, to: state, diceSeed: diceSeed)
    guard let amount = rolled.diceValue else { return (rolled, rollEvents) }
    let moves = MoveGen.legalMoves(
      for: rolled.currentPlayer,
      amount: amount,
      pieces: rolled.pieces,
      track: rolled.track,
      rules: rolled.ruleset,
      unsafeRosettesActive: rolled.pendingOmen?.effect.kind == .unsafeRosettes
    )
    guard !moves.isEmpty else { return (rolled, rollEvents) }
    let chosen = moves[min(pickIndex, moves.count - 1)]
    let (moved, moveEvents) = try TestSupport.apply(.move(chosen.piece), to: rolled, diceSeed: diceSeed)
    return (moved, rollEvents + moveEvents)
  }

  /// Play one full match with random legal moves; always accepts a double.
  /// Returns the final state plus the full action and event records (INV-4).
  static func playRandomMatch(
    seed: UInt64,
    ruleset: RuleSet = .finkel,
    dice: DiceModel = .tetra4,
    maxActions: Int = 100_000
  ) throws -> (MatchState, [Action], [Event]) {
    let record = try RandomMatch.play(
      seed: seed,
      ruleset: ruleset,
      dice: dice,
      stake: 2,
      maxActions: maxActions
    )
    return (record.finalState, record.actions, record.events)
  }
}
