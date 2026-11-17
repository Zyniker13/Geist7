import XCTest

@testable import RSCore

/// The content dice models (R-17): weights sum to the denominator, the
/// roll distribution matches the weights, and every ruleset's dice id
/// resolves. INV-2's full χ² battery covers tetra4 in DiceTests; these
/// tests pin the three variant models the content tables reference.
final class DiceModelTests: XCTestCase {

    static let variantModels: [DiceModel] = [.astragal4, .stick4, .beans5]

    func testR17_WeightsSumToDenominator() {
        for model in DiceModelTests.variantModels + [.tetra4] {
            XCTAssertEqual(
                model.totalWeight, model.denominator,
                "\(model.id): weights must sum to the denominator")
        }
    }

    func testR17_AllModelsResolveByID() {
        for id in ["tetra4", "astragal4", "stick4", "beans5"] {
            XCTAssertNotNil(DiceModel.model(forID: id), "content dice id \(id) must resolve")
        }
        XCTAssertNil(DiceModel.model(forID: "nonexistent"))
    }

    func testR17_RollDistributionMatchesWeights() {
        // 100k rolls per model; each outcome's frequency must sit within 1%
        // of its weight's share (loose bound: this is a sanity check; the
        // full χ² battery is INV-2's DiceTests for tetra4).
        for model in DiceModelTests.variantModels {
            var counts: [Int: Int] = [:]
            var rng = SeededRNG(seed: 20_260_117)
            let rolls = 100_000
            for _ in 0..<rolls {
                counts[model.roll(rng: &rng), default: 0] += 1
            }
            for outcome in model.outcomes {
                let expected = Double(outcome.weight) / Double(model.denominator)
                let observed = Double(counts[outcome.value] ?? 0) / Double(rolls)
                XCTAssertEqual(
                    observed, expected, accuracy: 0.01,
                    "\(model.id) value \(outcome.value): observed \(observed), expected \(expected)"
                )
            }
            // No outcome outside the table may ever appear.
            let legalValues = Set(model.outcomes.map(\.value))
            for (value, _) in counts {
                XCTAssertTrue(
                    legalValues.contains(value), "\(model.id) rolled illegal value \(value)")
            }
        }
    }

    func testAstragal4_MatchesTheRoadmapsPlaceholderOdds() {
        // Appendix A.3/A.9: the astragal placeholder is 10/40/40/10 over
        // values 1–4, flagged Reconstructed pending HIST review.
        XCTAssertEqual(DiceModel.astragal4.outcomes.map(\.value), [1, 2, 3, 4])
        XCTAssertEqual(DiceModel.astragal4.outcomes.map(\.weight), [10, 40, 40, 10])
        XCTAssertEqual(DiceModel.astragal4.denominator, 100)
    }

    func testBeans5_GivesBinomialCounts() {
        XCTAssertEqual(DiceModel.beans5.outcomes.map(\.value), [0, 1, 2, 3, 4, 5])
        XCTAssertEqual(DiceModel.beans5.outcomes.map(\.weight), [1, 5, 10, 10, 5, 1])
        XCTAssertEqual(DiceModel.beans5.denominator, 32)
    }
}
