// GoldenReplayTests.swift — S1.4: the ten committed golden replays.
// Each fixture records a seed, the full chart parameters, the complete
// action list, and the final state hash. The test rebuilds the chart
// from the fixture (no code dependency), replays the actions through
// the reducer, and demands the same action echo, event hash, result,
// and final hash.

import XCTest

@testable import MTCore

final class GoldenReplayTests: XCTestCase {
    private func loadGoldens() throws -> [(name: String, golden: GoldenSupport.Golden)] {
        let urls = try XCTUnwrap(
            Bundle.module.urls(
                forResourcesWithExtension: "json", subdirectory: "Fixtures/golden"),
            "golden fixtures missing from the test bundle")
        return
            try urls
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { url in
                let data = try Data(contentsOf: url)
                return (
                    url.lastPathComponent,
                    try JSONDecoder().decode(GoldenSupport.Golden.self, from: data)
                )
            }
    }

    func test_S14_tenGoldenReplaysCommitted() throws {
        let goldens = try loadGoldens()
        XCTAssertEqual(goldens.count, 10, "S1.4 requires ten committed golden replays")
        // Every fixture is well-formed: a validating chart, a nonzero
        // action list, consistent hashes.
        for (name, golden) in goldens {
            XCTAssertEqual(
                GoldenSupport.chart(from: golden.chart).validate(), [],
                "\(name): chart must validate")
            XCTAssertFalse(golden.actions.isEmpty, "\(name): empty replay")
            XCTAssertFalse(golden.finalHash.isEmpty, "\(name): missing final hash")
            XCTAssertEqual(golden.actions.count, golden.plies, "\(name): ply count")
        }
    }

    func test_S14_goldenReplaysReproduceExactly() throws {
        for (name, golden) in try loadGoldens() {
            let chart = GoldenSupport.chart(from: golden.chart)
            var state = Reducer.initial(chart: chart)
            for (ply, string) in golden.actions.enumerated() {
                guard let action = GoldenSupport.decode(string) else {
                    XCTFail("\(name): unparseable action at ply \(ply): \(string)")
                    return
                }
                do {
                    let (next, _) = try Reducer.apply(action, to: state)
                    state = next
                } catch let error as ReducerError {
                    XCTFail("\(name): replay ply \(ply) illegal: \(error.reason)")
                    return
                }
            }
            XCTAssertEqual(
                String(format: "%016llx", try StateHashing.stableHash(state)),
                golden.finalHash, "\(name): final hash")
            XCTAssertEqual(
                String(
                    format: "%016llx",
                    FNV1a64.hash(golden.actions.joined(separator: "|"))),
                golden.eventsHash, "\(name): events hash")
            XCTAssertEqual(golden.actions.count, golden.plies, "\(name): plies")
            XCTAssertEqual(
                GoldenSupport.resultDescription(state.status), golden.result,
                "\(name): result")
        }
    }
}
