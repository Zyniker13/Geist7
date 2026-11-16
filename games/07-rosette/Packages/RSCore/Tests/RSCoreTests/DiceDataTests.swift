import XCTest
@testable import RSCore

/// R-17 (dice models from data), INV-2 (chi-square over 10^6 rolls),
/// INV-6 (probability table equals the model), R-16/INV-8 (tablet ruleset).
final class DiceDataTests: XCTestCase {
  // MARK: R-17

  func testR17_DiceModelDecodesFromDataTable() throws {
    // A data table of (outcome, weight) pairs, as `dice.json` will carry.
    let json = """
    {
      "id": "astragal2",
      "label": "Two astragals (test table)",
      "outcomes": [
        {"value": 2, "weight": 16},
        {"value": 4, "weight": 24},
        {"value": 5, "weight": 24},
        {"value": 7, "weight": 16},
        {"value": 8, "weight": 12},
        {"value": 10, "weight": 8}
      ],
      "denominator": 100,
      "note": "Reconstructed face-to-value mapping (placeholder)."
    }
    """
    let data = Data(json.utf8)
    let model = try JSONDecoder().decode(DiceModel.self, from: data)
    XCTAssertEqual(model.id, "astragal2")
    XCTAssertEqual(model.totalWeight, model.denominator)
    // Roll determinism against the decoded model.
    var rng = SeededRNG(seed: 77)
    let value = model.roll(rng: &rng)
    XCTAssertTrue(model.outcomes.contains { $0.value == value })
  }

  func testR17_WeightsSumToDenominator() {
    XCTAssertEqual(DiceModel.tetra4.totalWeight, DiceModel.tetra4.denominator)
    for outcome in DiceModel.tetra4.outcomes {
      XCTAssertGreaterThan(outcome.weight, 0)
    }
  }

  // MARK: INV-2

  func testINV2_ChiSquareOverMillionRollsMatchesTetra4() {
    var rng = SeededRNG(seed: 20_260_116)
    let total = 1_000_000
    var counts = [Int](repeating: 0, count: 5)
    for _ in 0..<total {
      let value = DiceModel.tetra4.roll(rng: &rng)
      counts[value] += 1
    }
    let expected: [Double] = [62_500, 250_000, 375_000, 250_000, 62_500]
    var chiSquare = 0.0
    for (index, expect) in expected.enumerated() {
      let observed = Double(counts[index])
      chiSquare += (observed - expect) * (observed - expect) / expect
    }
    // 4 degrees of freedom: p > 0.01 iff chi-square < 13.277.
    XCTAssertLessThan(chiSquare, 13.277, "chi-square \(chiSquare) rejects the R-2 distribution")
  }

  // MARK: INV-6

  func testINV6_ProbabilityTableEqualsTheModel() {
    let model = DiceModel.tetra4
    for outcome in model.outcomes {
      let probability = Double(outcome.weight) / Double(model.denominator)
      XCTAssertTrue(probability > 0 && probability <= 1)
    }
    let total = Double(model.outcomes.reduce(0) { $0 + $1.weight }) / Double(model.denominator)
    XCTAssertEqual(total, 1.0, accuracy: 1e-12)
  }

  // MARK: R-16 / INV-8 (tablet ruleset, astragal dice from data)

  func testR16_TabletRulesetPlaysWithFivePiecesAndAstragalDice() throws {
    // Single astragal face-to-value mapping: a reconstructed placeholder
    // table (weights out of 10); P8 finalises the numbers with sourcing.
    let singleAstragal: [DiceOutcome] = [
      DiceOutcome(value: 1, weight: 4),
      DiceOutcome(value: 3, weight: 2),
      DiceOutcome(value: 4, weight: 2),
      DiceOutcome(value: 6, weight: 2)
    ]
    // Convolve four astragals into a data-driven model.
    var table: [Int: Int] = [0: 1]
    for _ in 0..<4 {
      var next: [Int: Int] = [:]
      for (base, baseWeight) in table {
        for outcome in singleAstragal {
          next[base + outcome.value, default: 0] += baseWeight * outcome.weight
        }
      }
      table = next
    }
    let outcomes = table.keys.sorted().map { DiceOutcome(value: $0, weight: table[$0]!) }
    let astragal4 = DiceModel(
      id: "astragal4",
      label: "Four astragals (tablet)",
      outcomes: outcomes,
      denominator: outcomes.reduce(0) { $0 + $1.weight },
      note: "Convolved from the placeholder single-astragal table."
    )
    XCTAssertEqual(astragal4.totalWeight, astragal4.denominator, "R-17: weights sum to the denominator")
    XCTAssertEqual(astragal4.outcomes.first?.value, 4, "four astragals show at least four tips")

    let tabletRuleset = RuleSet(
      id: "tablet",
      label: "Tablet ruleset",
      trackLength: 14,
      pieces: 5,
      rosettes: [3, 7, 13],
      safeRosettes: [7],
      diceModel: "astragal4",
      exactBearOff: true,
      extraRollOnRosette: true,
      captureRule: .standard,
      moveGenerator: "ur",
      source: "R-16 (route and safety as Finkel/RoyalUr)",
      historyLabel: .attested
    )

    // INV-8: play matches with the 5-piece tablet ruleset and check
    // conservation (analogous to INV-1) after every action.
    for seed: UInt64 in [1, 2, 3] {
      var state = TestSupport.state(
        ruleset: tabletRuleset,
        dice: astragal4,
        player0: Array(repeating: -1, count: 5),
        player1: Array(repeating: -1, count: 5)
      )
      var rng = SeededRNG(seed: seed)
      var omenRng = SeededRNG(seed: seed &+ 7)
      var guardCounter = 0
      while !state.isComplete && guardCounter < 20_000 {
        guardCounter += 1
        XCTAssertTrue(state.pieceConservationValid, "INV-8 broken at ply \(state.plies), seed \(seed)")
        let action: Action
        if state.doubleOffered {
          action = .acceptDouble
        } else if !state.hasRolled {
          action = .roll
        } else {
          let moves = MoveGen.legalMoves(
            for: state.currentPlayer,
            amount: state.diceValue ?? 0,
            pieces: state.pieces,
            track: state.track,
            rules: state.ruleset
          )
          guard !moves.isEmpty else { break }
          action = .move(moves[Int(rng.next(UInt64(moves.count)))].piece)
        }
        let result = try Reducer.apply(action, to: state, rng: &rng, omenRng: &omenRng)
        state = result.state
      }
      XCTAssertTrue(state.isComplete || guardCounter >= 20_000, "match should end or hit the guard")
      XCTAssertTrue(state.pieceConservationValid, "INV-8 broken at the end of seed \(seed)")
      XCTAssertEqual(state.pieces.count, 10, "tablet ruleset: 5 pieces per player")
    }
  }
}
