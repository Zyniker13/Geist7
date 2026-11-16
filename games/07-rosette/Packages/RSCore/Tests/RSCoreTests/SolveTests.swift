import XCTest

@testable import RSCore

/// Tests for the RS-P1.4 value-iteration solver, its position ranking, and
/// the solved-value table codec.
///
/// Structural ground truth: RoyalUr's published solved tables (MIT, see
/// docs/THIRD_PARTY.md) store light-to-move states, and their entry counts
/// equal this package's full (board, rolling-player) tuple space minus the
/// tuples where the second player has already borne off every piece —
/// verified exactly for both published tables (12,990 and 137,892,016).
/// A sampled cross-check against the published two-piece table is committed
/// as a fixture and asserted in testTable_MatchesRoyalUrPublishedSample.
final class SolveTests: XCTestCase {

    // MARK: - Enumeration structure

    /// The two-piece tuple space counts every valid (board, rolling player)
    /// configuration: 13,112 tuples, of which 122 have player 1 already
    /// finished — matching the 12,990 entries of the published table.
    func testRanking_TwoPieceTupleCount() {
        XCTAssertEqual(UrRanking(pieces: 2).totalPositions, 13_112)
    }

    /// The seven-piece tuple space has 137,913,936 configurations, of which
    /// 21,920 (the finished-player-1 distributions the published table
    /// omits) leave exactly RoyalUr's 137,892,016 entries.
    func testRanking_SevenPieceTupleCount() {
        XCTAssertEqual(UrRanking(pieces: 7).totalPositions, 137_913_936)
        XCTAssertEqual(137_913_936 - 21_920, 137_892_016)
    }

    /// Layer sizes must sum to the total and every layer must be non-empty
    /// (each borne-off total 0…2P is reachable).
    func testRanking_LayerSizesSumToTotal() {
        for pieces in [1, 2, 3, 7] {
            let ranking = UrRanking(pieces: pieces)
            let counts = (0..<ranking.layerCount).map { layer in
                ranking.layerStart[layer + 1] - ranking.layerStart[layer]
            }
            XCTAssertEqual(counts.reduce(0, +), ranking.totalPositions)
            XCTAssertFalse(counts.contains(0), "piece count \(pieces) has an empty layer")
        }
    }

    /// Brute-force bijectivity on the two-piece game: every valid position
    /// maps to a unique dense index, and the index count equals the table
    /// size — so the mapping is a bijection onto [0, totalPositions).
    func testRanking_IndexIsBijectiveOnTwoPieceGame() {
        let ranking = UrRanking(pieces: 2)
        var seen = Set<Int>()
        seen.reserveCapacity(ranking.totalPositions)
        for shared in 0..<6561 {
            let packed = UrPosition.base3ToPacked[shared]
            let n0 = ranking.sharedCount0(shared)
            let n1 = ranking.sharedCount1(shared)
            for priv0 in 0..<64 where n0 + priv0.nonzeroBitCount <= 2 {
                for priv1 in 0..<64 where n1 + priv1.nonzeroBitCount <= 2 {
                    let on0 = n0 + priv0.nonzeroBitCount
                    let on1 = n1 + priv1.nonzeroBitCount
                    for hand0 in 0...2 {
                        let off0 = 2 - hand0 - on0
                        guard off0 >= 0 else { continue }
                        for hand1 in 0...2 {
                            let off1 = 2 - hand1 - on1
                            guard off1 >= 0 else { continue }
                            let position = UrPosition(
                                shared: packed, private0: UInt32(priv0),
                                private1: UInt32(priv1), hand0: hand0, hand1: hand1
                            )
                            let index = ranking.index(of: position)
                            XCTAssertLessThan(index, ranking.totalPositions)
                            XCTAssertFalse(seen.contains(index), "duplicate index \(index)")
                            seen.insert(index)
                        }
                    }
                }
            }
        }
        XCTAssertEqual(seen.count, 13_112)
    }

    /// The initial position (every piece waiting to enter) has dense index 0.
    func testRanking_InitialPositionHasIndexZero() {
        for pieces in [1, 2, 7] {
            let ranking = UrRanking(pieces: pieces)
            let initial = UrPosition(
                shared: 0, private0: 0, private1: 0, hand0: pieces, hand1: pieces
            )
            XCTAssertEqual(ranking.index(of: initial), 0)
            XCTAssertEqual(ranking.layer(of: initial), 0)
        }
    }

    /// Colour swap is an involution.
    func testRanking_MirrorIsAnInvolution() {
        let ranking = UrRanking(pieces: 2)
        for shared in stride(from: 0, to: 6561, by: 97) {
            for priv in stride(from: 0, to: 64, by: 7) {
                let position = UrPosition(
                    shared: UrPosition.base3ToPacked[shared], private0: UInt32(priv),
                    private1: UInt32((priv * 13) % 64), hand0: 1, hand1: 2
                )
                XCTAssertEqual(ranking.mirrored(ranking.mirrored(position)), position)
            }
        }
    }

    // MARK: - Solver correctness on small games

    /// One-piece race with both pieces on the final step: only a roll of 1
    /// wins (4/16), every other roll passes (12/16), and the pass hands the
    /// mirrored situation to the opponent, so V = 4/16 + (12/16)(1 − V),
    /// giving V = 4/7.
    func testSolver_AnalyticValueOnTheFinalStep() throws {
        let solver = UrSolver(pieces: 1)
        let (values, _) = solver.solve()
        let ranking = solver.ranking
        // Private bitmap bit 5 = step 13 (the private exit square).
        let position = UrPosition(
            shared: 0, private0: 1 << 5, private1: 1 << 5, hand0: 0, hand1: 0
        )
        XCTAssertEqual(
            values[ranking.index(of: position)], 4.0 / 7.0, accuracy: 1e-8)
    }

    /// Every non-decided position is a fixed point of the Bellman operator
    /// evaluated on the solved values, with values in [0, 1]. Decided
    /// positions (a side with nothing in hand and nothing on board) carry
    /// forced boundary values — the game is over — and are counted, not
    /// probed; no non-decided state's Bellman ever reads them, because the
    /// rolling player's turn never increases the opponent's borne-off count.
    func testFixedPoints(solver: UrSolver, values: [Double]) {
        let ranking = solver.ranking
        let pieces = solver.pieces
        XCTAssertFalse(values.contains { $0 < 0 || $0 > 1 })
        var checked = 0
        var decided = 0
        for s in 0..<UrRanking.sharedPatterns {
            let n0 = ranking.sharedCount0(s)
            let n1 = ranking.sharedCount1(s)
            let packed = UrPosition.base3ToPacked[s]
            for priv0 in 0..<64 {
                let on0 = n0 + priv0.nonzeroBitCount
                guard on0 <= pieces else { continue }
                for priv1 in 0..<64 {
                    let on1 = n1 + priv1.nonzeroBitCount
                    guard on1 <= pieces else { continue }
                    // Walk every layer that holds this (shared, priv0, priv1) shape.
                    for layer in 0..<ranking.layerCount {
                        guard let layerBounds = ranking.handPairBounds(on0, on1, layer)
                        else { continue }
                        let k = 2 * pieces - on0 - on1 - layer
                        for hand0 in layerBounds.low...layerBounds.high {
                            let position = UrPosition(
                                shared: packed, private0: UInt32(priv0), private1: UInt32(priv1),
                                hand0: hand0, hand1: k - hand0
                            )
                            if position.hand0 + on0 == 0 || position.hand1 + on1 == 0 {
                                decided += 1
                                continue
                            }
                            let index = ranking.index(of: position)
                            XCTAssertEqual(
                                values[index], solver.bellman(position: position, values: values),
                                accuracy: 1e-9,
                                "tuple shared=\(s) priv0=\(priv0) priv1=\(priv1) h0=\(hand0) h1=\(k - hand0)"
                                    + " is not a fixed point")
                            checked += 1
                        }
                    }
                }
            }
        }
        XCTAssertEqual(checked + decided, ranking.totalPositions)
    }

    /// The one-piece solve is an exact fixed point on all 248 tuples with a
    /// real first-player advantage.
    func testSolver_OnePieceGameIsAnExactFixedPoint() throws {
        let solver = UrSolver(pieces: 1)
        let (values, report) = solver.solve()
        XCTAssertGreaterThan(report.initialWinProbability, 0.5)
        testFixedPoints(solver: solver, values: values)
    }

    /// The two-piece solve is bit-for-bit identical to the committed solved
    /// table (determinism across runs and machines), an exact Bellman fixed
    /// point on every tuple, and keeps a real first-player advantage.
    func testSolver_TwoPieceSolveIsExactAndDeterministic() throws {
        let committed = try committedTable()
        let solver = UrSolver(pieces: 2)
        let (values, report) = solver.solve()
        let ranking = solver.ranking

        XCTAssertEqual(report.totalPositions, 13_112)
        let quantized = values.map { UInt16(max(0, min(65535, ($0 * 65535.0).rounded()))) }
        XCTAssertEqual(quantized, committed.values, "fresh solve differs from the committed table")

        let initial = UrPosition(shared: 0, private0: 0, private1: 0, hand0: 2, hand1: 2)
        XCTAssertEqual(
            values[ranking.index(of: initial)], report.initialWinProbability, accuracy: 0)
        XCTAssertGreaterThan(report.initialWinProbability, 0.5)
        testFixedPoints(solver: solver, values: values)
    }

    /// The committed two-piece table's initial win probability is the
    /// published first-player advantage (51.8578%, RoyalUr.net solved data).
    func testSolver_TwoPieceInitialMatchesPublishedAdvantage() throws {
        let committed = try committedTable()
        let ranking = UrRanking(pieces: 2)
        let initial = UrPosition(shared: 0, private0: 0, private1: 0, hand0: 2, hand1: 2)
        // The committed table stores quantised values; one quantisation step
        // is 1/65535 ≈ 1.53e-5, so compare to the published advantage within
        // a step.
        XCTAssertEqual(
            committed.winProbability(at: initial), 0.5185729074950166, accuracy: 8.0e-6)
        XCTAssertEqual(ranking.index(of: initial), 0)
    }

    // MARK: - Table codec

    /// Serialization round-trips through deserialize with identical values.
    func testTable_RoundTripsThroughSerialization() throws {
        let table = try committedTable()
        let restored = try UrTable.deserialize(table.serialized())
        XCTAssertEqual(restored.pieces, 2)
        XCTAssertEqual(restored.totalPositions, table.totalPositions)
        XCTAssertEqual(restored.values, table.values)
        XCTAssertEqual(restored.layerStart, table.layerStart)
        let initial = UrPosition(shared: 0, private0: 0, private1: 0, hand0: 2, hand1: 2)
        XCTAssertEqual(
            restored.winProbability(at: initial), table.winProbability(at: initial),
            accuracy: 0)
    }

    /// Delta + varint compression round-trips exactly, and never exceeds the
    /// raw encoding by more than the header (the codec falls back to raw
    /// when deltas would expand).
    func testTable_CompressionRoundTrips() throws {
        let table = try committedTable()
        let ranking = UrRanking(pieces: 2)
        let compressed = UrTableCodec.compress(table.values, layerStart: ranking.layerStart)
        let restored = try UrTableCodec.decompress(compressed, pieces: 2)
        XCTAssertEqual(restored, table.values)
        // Header: two UInt32 counts plus (layers + 1) UInt64 offsets, plus the
        // one-byte mode tag.
        let headerBytes = 8 + (ranking.layerCount + 1) * 8 + 1
        XCTAssertLessThanOrEqual(
            compressed.count, table.values.count * 2 + headerBytes)
    }

    /// Smooth value sequences (small deltas) take the delta-varint mode and
    /// compress well below the raw size.
    func testTable_CompressionUsesDeltaWhenSmaller() throws {
        let ranking = UrRanking(pieces: 1)
        var values = [UInt16]()
        for index in 0..<ranking.totalPositions {
            // A slow ramp: deltas stay tiny, so varint coding wins.
            values.append(UInt16((index * 7) % 64))
        }
        let compressed = UrTableCodec.compress(values, layerStart: ranking.layerStart)
        let restored = try UrTableCodec.decompress(compressed, pieces: 1)
        XCTAssertEqual(restored, values)
        XCTAssertLessThan(compressed.count, values.count * 2)
    }

    /// Corrupting any payload byte is caught by the checksum.
    func testTable_ChecksumCatchesCorruption() throws {
        let table = try committedTable()
        var data = table.serialized()
        XCTAssertGreaterThan(data.count, 32)
        data[20] ^= 0xFF
        XCTAssertThrowsError(try UrTable.deserialize(data)) { error in
            XCTAssertEqual(
                "\(error)", UrTable.UrTableError.checksumMismatch.description)
        }
    }

    /// Non-table data is rejected by the magic-number check.
    func testTable_RejectsBadMagic() {
        XCTAssertThrowsError(
            try UrTable.deserialize(
                Data([0, 1, 2, 3, 4, 5, 6, 7] + [UInt8](repeating: 0, count: 24)))
        ) { error in
            XCTAssertEqual("\(error)", UrTable.UrTableError.badMagic.description)
        }
    }

    // MARK: - Published-table evidence

    /// Every sampled entry of RoyalUr's published two-piece solved table
    /// must agree with the committed solve to within their storage
    /// quantisation (one step of 1/65535; the full-file cross-check measured
    /// a worst case of 7.66e-6).
    func testTable_MatchesRoyalUrPublishedSample() throws {
        struct Sample: Decodable {
            var pieces: Int
            var upstreamEntries: Int
            var entries: [Entry]
            struct Entry: Decodable {
                var k: UInt32
                var v: UInt16
            }
        }
        let url = try fixtureURL("rgu2p-sample", extension: "json")
        let sample = try JSONDecoder().decode(Sample.self, from: Data(contentsOf: url))
        XCTAssertEqual(sample.pieces, 2)
        XCTAssertEqual(sample.upstreamEntries, 12_990)

        let table = try committedTable()
        let compression = UrRguCrossCheck.warCompressionInverse(pieces: 2)
        var worst = 0.0
        for entry in sample.entries {
            let position = try UrRguCrossCheck.position(
                key: entry.k, compression: compression, pieces: 2)
            let theirs = Double(entry.v) / 65535.0
            let mine = table.winProbability(at: position)
            worst = max(worst, abs(mine - theirs))
        }
        XCTAssertLessThanOrEqual(worst, 8.0e-6, "worst published-table deviation")
    }

    // MARK: - Helpers

    private func fixtureURL(_ name: String, extension ext: String) throws -> URL {
        let candidates = [
            Bundle.module.url(
                forResource: name, withExtension: ext, subdirectory: "Fixtures/Tables"),
            Bundle.module.url(forResource: "Tables/\(name)", withExtension: ext),
            Bundle.module.url(forResource: name, withExtension: ext),
        ]
        guard let url = candidates.compactMap({ $0 }).first else {
            throw RuleError.illegalAction("missing fixture \(name).\(ext)")
        }
        return url
    }

    private func committedTable() throws -> UrTable {
        let url = try fixtureURL("ur2p-solved", extension: "rstable")
        return try UrTable.deserialize(Data(contentsOf: url))
    }
}
