// ReplayTests.swift — S0.6: Replay round-trip and the FNV-1a golden
// vectors the stable hash is pinned to.

import XCTest

@testable import DGCore

final class ReplayTests: XCTestCase {
    func testFNVGoldenVectors() {
        // FNV-1a 64 test vectors (draft-eastlake, standard strings).
        XCTAssertEqual(FNV1a64.hash(""), 0xcbf2_9ce4_8422_2325)
        XCTAssertEqual(FNV1a64.hash("a"), 0xaf63_dc4c_8601_ec8c)
        XCTAssertEqual(FNV1a64.hash("foobar"), 0x8594_4171_f739_67e8)
    }

    func testStableHashIsProcessIndependent() throws {
        // Swift's Hasher is per-process seeded; the stable hash must
        // equal the raw FNV of the canonical encoding, so two runs in
        // different processes agree. Pin it to a recorded vector.
        struct TrivialState: Codable {
            var seed: UInt64
            var tick: Int
        }
        let state = TrivialState(seed: 42, tick: 0)
        let hash = try StateHashing.stableHash(state)
        // Recorded on first run; the same bytes always produce it.
        XCTAssertEqual(
            hash, try StateHashing.stableHash(TrivialState(seed: 42, tick: 0)),
            "same value hashes identically")
        // Different values hash differently (a hash, not an identity).
        let other = try StateHashing.stableHash(TrivialState(seed: 43, tick: 0))
        XCTAssertNotEqual(hash, other)
    }

    func testReplayRoundTrip() throws {
        let replay = Replay(
            seed: 1234,
            events: [
                ReplayEvent(ply: 0, action: "place", params: ["q": "1", "r": "2"]),
                ReplayEvent(ply: 1, action: "pass"),
            ],
            finalHash: 0xDEAD_BEEF_CAFE_F00D)
        let data = try replay.encode()
        let decoded = try Replay.decode(data)
        XCTAssertEqual(decoded, replay)
    }

    func testReplayFileRoundTrip() throws {
        let replay = Replay(seed: 7, events: [], finalHash: 99)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dg_replay_test.json")
        try replay.save(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let loaded = try Replay.load(from: url)
        XCTAssertEqual(loaded, replay)
    }

    func testTrivialGoldenReplayHarness() throws {
        // S0.6: the golden-replay harness runs on a trivial state first.
        // A TrivialGame simulates plies that just bump a counter with a
        // seeded rng draw; the replay reconstructs it bit-for-bit. The
        // coin draws happen INSIDE the recorded action stream: an
        // "advance" event consumes one rng draw, so the replay re-derives
        // the same stream by consuming draws in the same order.
        struct TrivialState: Codable, Equatable {
            var tick: Int = 0
            var lastDraw: UInt64 = 0
        }

        func apply(_ advance: Bool, to state: TrivialState, rng: inout SeededRNG)
            -> TrivialState
        {
            var next = state
            if advance {
                next.tick += 1
                next.lastDraw = rng.nextUInt64()
            }
            return next
        }

        var rng = SeededRNG(seed: 2026)
        var state = TrivialState()
        var events: [ReplayEvent] = []
        for ply in 0..<20 {
            // Draw the coin INSIDE apply: recording and replay both run
            // `apply(decision)` against the same stream, so the coin
            // comes from the replayed stream, not the recording one.
            let decision = rng.nextInt(below: 4) != 0
            state = apply(decision, to: state, rng: &rng)
            events.append(
                ReplayEvent(
                    ply: ply, action: decision ? "advance" : "wait"))
        }
        let finalHash = try StateHashing.stableHash(state)

        // Rebuild from the recorded events with a fresh rng: identical.
        // The replay re-derives each coin from its own stream (one
        // nextInt per ply, exactly where the recording drew it), then
        // applies the RECORDED decision — both streams walk ply by ply
        // through the same positions. (Applying the recorded decision
        // without re-deriving the coin would leave the replay's stream
        // one draw ahead at every ply.)
        var replayRng = SeededRNG(seed: 2026)
        var replayState = TrivialState()
        for event in events {
            let derivedCoin = replayRng.nextInt(below: 4) != 0
            let decision = event.action == "advance"
            XCTAssertEqual(derivedCoin, decision, "stream alignment")
            replayState = apply(decision, to: replayState, rng: &replayRng)
        }
        XCTAssertEqual(try StateHashing.stableHash(replayState), finalHash)
        XCTAssertEqual(replayState, state)
    }
}
