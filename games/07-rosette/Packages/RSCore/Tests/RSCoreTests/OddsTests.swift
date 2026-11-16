import XCTest

@testable import RSCore

/// Odds panel tests (RS-P2.1 / G2): the exact capture chance must agree with
/// an independent direct-rules computation across 200 sampled states, and
/// known-answer cases must hold.
final class OddsTests: XCTestCase {

    // MARK: - Independent reference computation

    /// Direct-rules capture chance: enumerates outcomes × candidate
    /// destinations and applies `Capture.check` directly, never touching the
    /// reducer. Structurally independent of `OddsCalculator`'s reducer-probe
    /// path, so agreement between the two is a real cross-check.
    func directCaptureChance(_ state: MatchState) -> Double {
        guard !state.isComplete, !state.hasRolled, !state.doubleOffered else { return 0 }

        let unsafeActive = state.pendingOmen?.effect.kind == .unsafeRosettes
        var favorable = 0

        for outcome in state.dice.outcomes where outcome.value > 0 {
            var captures = false
            for piece in state.pieces
            where piece.owner == state.currentPlayer && piece.position != -2 {
                let destination: Int
                if piece.position == -1 {
                    // R-3: entry lands on square (roll − 1).
                    let entry = outcome.value - 1
                    guard entry >= 0, entry < state.track.length else { continue }
                    destination = entry
                } else {
                    let raw = piece.position + outcome.value
                    // Reaching past the end bears off (exact or inexact);
                    // bearing off never captures.
                    guard raw < state.track.length else { continue }
                    destination = raw
                }

                // R-4: blocked by an own piece on the destination.
                if state.pieces.contains(where: {
                    $0.owner == state.currentPlayer && $0.position == destination
                }) {
                    continue
                }

                guard
                    let target = state.pieces.first(where: {
                        $0.owner != state.currentPlayer && $0.position == destination
                    })
                else { continue }

                let capture = Capture.check(
                    landingOn: destination,
                    targetPiece: target,
                    track: state.track,
                    rules: state.ruleset,
                    unsafeRosettesActive: unsafeActive
                )
                if case .captured = capture {
                    captures = true
                    break
                }
            }
            if captures {
                favorable += outcome.weight
            }
        }

        return Double(favorable) / Double(state.dice.denominator)
    }

    // MARK: - Known answers

    func testFreshMatchHasZeroCaptureChance() {
        let state = MatchState.finkelMatch(stake: 2, omens: [])
        XCTAssertEqual(OddsCalculator.nextRollCaptureChance(for: state), 0)
        XCTAssertEqual(
            OddsCalculator.panelText(for: state),
            "Chance to capture next roll: 0%"
        )
    }

    func testCertainCaptureWithLoadedDice() {
        // Player 0 piece on square 5, player 1 piece on square 6, roll 1:
        // the landing is a capture every time the piece moves.
        let state = TestSupport.state(
            dice: TestSupport.loaded(1),
            player0: [5, -1, -1, -1, -1, -1, -1],
            player1: [6, -1, -1, -1, -1, -1, -1]
        )
        XCTAssertEqual(OddsCalculator.nextRollCaptureChance(for: state), 1.0)
        XCTAssertEqual(
            OddsCalculator.panelText(for: state),
            "Chance to capture next roll: 100%"
        )
    }

    func testQuarterChanceMatchesRoadmapExample() {
        // The same placement under the astragal distribution: only a roll of
        // 1 captures (weight 4 of 16), so the panel reads 25% — the exact
        // example wording in the roadmap.
        let state = TestSupport.state(
            dice: .tetra4,
            player0: [5, -1, -1, -1, -1, -1, -1],
            player1: [6, -1, -1, -1, -1, -1, -1]
        )
        XCTAssertEqual(OddsCalculator.nextRollCaptureChance(for: state), 0.25)
        XCTAssertEqual(
            OddsCalculator.panelText(for: state),
            "Chance to capture next roll: 25%"
        )
    }

    func testSafeRosetteBlocksCapture() {
        // Opponent waiting on a safe rosette: landing there is .safeRosette,
        // so even a certain landing never captures.
        let base = TestSupport.state(
            player0: [0, -1, -1, -1, -1, -1, -1],
            player1: [0, -1, -1, -1, -1, -1, -1]
        )
        guard let safe = base.track.safeRosetteIndices.first(where: { $0 > 1 }) else {
            return XCTFail("Finkel track has no safe rosette beyond square 1")
        }
        let state = TestSupport.state(
            dice: TestSupport.loaded(1),
            player0: [safe - 1, -1, -1, -1, -1, -1, -1],
            player1: [safe, -1, -1, -1, -1, -1, -1]
        )
        XCTAssertEqual(OddsCalculator.nextRollCaptureChance(for: state), 0)
    }

    func testPendingDoubleShowsZero() throws {
        var state = TestSupport.state(
            player0: [5, -1, -1, -1, -1, -1, -1],
            player1: [6, -1, -1, -1, -1, -1, -1]
        )
        let (offered, _) = try TestSupport.apply(.offerDouble, to: state)
        state = offered
        XCTAssertEqual(OddsCalculator.nextRollCaptureChance(for: state), 0)
    }

    // MARK: - 200 sampled states: exact agreement (G2 check)

    func testOddsMatchExactComputationAcross200SampledStates() throws {
        // One turn-boundary state per seed, mid-match, from seeded random
        // playouts — the moments the odds panel is shown.
        var sampled = 0
        for seed: UInt64 in 1...400 where sampled < 200 {
            var state = MatchState.finkelMatch(stake: 2, omens: [])
            // Step the match a seed-dependent number of plies to spread the
            // samples across the game.
            let steps = 1 + Int(seed % 12)
            for step in 0..<steps {
                let diceSeed = seed &* 31 &+ UInt64(step)
                let (next, _) = try TestSupport.rollAndMove(state, diceSeed: diceSeed)
                state = next
                if state.isComplete { break }
            }
            guard !state.isComplete, !state.hasRolled, !state.doubleOffered else {
                continue
            }

            let probed = OddsCalculator.nextRollCaptureChance(for: state)
            let direct = directCaptureChance(state)
            XCTAssertEqual(
                probed, direct, accuracy: 1e-12,
                "Odds mismatch at seed \(seed): probe \(probed) vs direct \(direct)"
            )
            XCTAssertTrue(probed >= 0 && probed <= 1)

            // The panel line must be the exact value, rounded to a percent.
            let expectedPercent = Int((probed * 100).rounded())
            XCTAssertEqual(
                OddsCalculator.panelText(for: state),
                "Chance to capture next roll: \(expectedPercent)%"
            )
            sampled += 1
        }
        XCTAssertEqual(sampled, 200, "expected 200 sampled states")
    }
}
