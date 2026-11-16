import XCTest

@testable import RSCore

/// S1.4: the ten committed golden replays must reproduce exactly — the
/// recorded actions replay through the reducer to the recorded final hash,
/// and re-deriving the match from the seed reproduces the recorded actions.
final class GoldenReplayTests: XCTestCase {
    private struct GoldenReplay: Codable {
        var seed: UInt64
        var finalStateHash: UInt64
        var winner: String
        var gammon: Bool
        var plies: Int
        var actions: [Action]
    }

    private func fixtureURL(_ name: String) throws -> URL {
        let candidates = [
            Bundle.module.url(
                forResource: name, withExtension: "json", subdirectory: "Fixtures/Replays"),
            Bundle.module.url(forResource: "Replays/\(name)", withExtension: "json"),
        ]
        guard let url = candidates.compactMap({ $0 }).first else {
            throw RuleError.illegalAction("missing golden replay fixture \(name)")
        }
        return url
    }

    func testS4_TenGoldenReplaysReplayExactly() throws {
        for index in 1...10 {
            let name = String(format: "replay-%02d", index)
            let data = try Data(contentsOf: try fixtureURL(name))
            let fixture = try JSONDecoder().decode(GoldenReplay.self, from: data)

            // (a) Replay the recorded actions through the reducer with fresh
            // streams seeded exactly as the sim tool seeds them.
            var state = MatchState.finkelMatch(stake: 2, omens: [])
            var rng = SeededRNG(seed: fixture.seed)
            var omenRng = SeededRNG(seed: RandomMatch.omenSeed(for: fixture.seed))
            for action in fixture.actions {
                let result = try Reducer.apply(action, to: state, rng: &rng, omenRng: &omenRng)
                state = result.state
            }
            XCTAssertEqual(state.stateHash, fixture.finalStateHash, "\(name): final hash mismatch")
            XCTAssertEqual(state.plies, fixture.plies, "\(name): ply count mismatch")
            XCTAssertTrue(state.isComplete, "\(name): replay must complete the match")
            let winner = state.outcome?.winner == .player0 ? "player0" : "player1"
            XCTAssertEqual(winner, fixture.winner, "\(name): winner mismatch")
            XCTAssertEqual(
                state.outcome?.gammon ?? false, fixture.gammon, "\(name): gammon mismatch")

            // (b) Re-derive the match from the seed: the random driver must choose
            // exactly the recorded actions (INV-4 end to end).
            let record = try RandomMatch.play(seed: fixture.seed)
            XCTAssertEqual(record.actions, fixture.actions, "\(name): re-derived actions mismatch")
            XCTAssertEqual(
                record.finalState.stateHash, fixture.finalStateHash,
                "\(name): re-derived hash mismatch")
        }
    }
}
