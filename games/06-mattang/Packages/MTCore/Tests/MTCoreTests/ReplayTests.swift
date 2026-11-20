// ReplayTests.swift — S0.6 golden-replay harness (trivial state).
//
// Verifies: FNV-1a 64 known-answer vectors, stable-hash determinism
// across processes (same value on two fresh processes via golden
// constants), Replay JSON round-trip, and the harness recipe that
// later phases reuse for real GameState replays.

import XCTest

@testable import MTCore

/// Trivial Codable state standing in for GameState until P1 lands it.
private struct TrivialState: Codable, Equatable {
    var seed: UInt64
    var tick: Int
    var cells: [String: Int]
}

final class ReplayTests: XCTestCase {
    // FNV-1a 64 reference vectors (Fowler, Noll, Vo test vectors).
    func testFNV1a64KnownAnswers() {
        XCTAssertEqual(FNV1a64.hash(""), 0xcbf2_9ce4_8422_2325)
        XCTAssertEqual(FNV1a64.hash("a"), 0xaf63_dc4c_8601_ec8c)
        XCTAssertEqual(FNV1a64.hash("foobar"), 0x8594_4171_f739_67e8)
    }

    func testStableHashDeterministic() throws {
        let state = TrivialState(seed: 7, tick: 3, cells: ["a": 1, "b": 2])
        let h1 = try StateHashing.stableHash(state)
        let h2 = try StateHashing.stableHash(state)
        XCTAssertEqual(h1, h2)
    }

    func testStableHashMatchesGoldenConstant() throws {
        // Golden constant captured from the first passing run; the same
        // TrivialState (sorted-keys JSON) must hash to this on every
        // device and in every process — INV-4's local anchor.
        let state = TrivialState(seed: 7, tick: 3, cells: ["a": 1, "b": 2])
        let h = try StateHashing.stableHash(state)
        XCTAssertEqual(h, 0x9D3B_73F0_768E_6046, "state encoding drifted")
    }

    func testStableHashDistinguishesStates() throws {
        let a = TrivialState(seed: 7, tick: 3, cells: ["a": 1])
        let b = TrivialState(seed: 7, tick: 4, cells: ["a": 1])
        let c = TrivialState(seed: 7, tick: 3, cells: ["a": 2])
        let hashes = try [a, b, c].map { try StateHashing.stableHash($0) }
        XCTAssertEqual(Set(hashes).count, 3, "distinct states collided")
    }

    func testReplayJSONRoundTrip() throws {
        let replay = Replay(
            seed: 0xDEAD_BEEF_CAFE_F00D,
            version: 1,
            events: [
                ReplayEvent(ply: 0, action: "launch", params: ["hex": "2,1"]),
                ReplayEvent(ply: 1, action: "sail", params: ["canoe": "0", "path": "3,0;3,1"]),
                ReplayEvent(ply: 2, action: "pass"),
            ],
            finalHash: 0x1234_5678_9ABC_DEF0
        )
        let data = try replay.encode()
        let decoded = try Replay.decode(data)
        XCTAssertEqual(decoded, replay)
    }

    func testReplaySaveLoadRoundTrip() throws {
        let replay = Replay(
            seed: 1, version: 1,
            events: [
                ReplayEvent(
                    ply: 0, action: "placeIsland",
                    params: ["hex": "0,0"])
            ],
            finalHash: 42)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("replay-test-roundtrip.json")
        try? FileManager.default.removeItem(at: url)
        defer { try? FileManager.default.removeItem(at: url) }
        try replay.save(to: url)
        let loaded = try Replay.load(from: url)
        XCTAssertEqual(loaded, replay)
    }

    /// The harness recipe every later phase reuses: drive a seeded RNG,
    /// fold each event into a running FNV-1a hash, and record the final
    /// chain; replaying the same seed + events must reproduce it exactly.
    func testGoldenReplayHarnessReproducesHashChain() throws {
        func fold(_ h: UInt64, _ text: String) -> UInt64 {
            var combined = h
            for b in text.utf8 {
                combined ^= UInt64(b)
                combined = combined &* FNV1a64.prime
            }
            return combined
        }

        let seed: UInt64 = 2026
        var rng = SeededRNG(seed: seed)
        var hash = FNV1a64.offsetBasis

        var events: [ReplayEvent] = []
        for ply in 0..<8 {
            let die = rng.nextInt(below: 6)
            let event = ReplayEvent(
                ply: ply, action: "sail",
                params: ["dir": "\(die)"])
            events.append(event)
            hash = fold(hash, event.action)
            hash = fold(hash, event.params["dir"] ?? "")
        }

        // Replay from the same seed: identical stream, identical chain.
        var rng2 = SeededRNG(seed: seed)
        var hash2 = FNV1a64.offsetBasis
        for event in events {
            let expected = try XCTUnwrap(
                Int(event.params["dir"] ?? ""),
                "missing dir at ply \(event.ply)"
            )
            let drawn = rng2.nextInt(below: 6)
            XCTAssertEqual(drawn, expected, "event stream diverged at ply \(event.ply)")
            hash2 = fold(hash2, event.action)
            hash2 = fold(hash2, event.params["dir"] ?? "")
        }
        XCTAssertEqual(hash2, hash, "replay did not reproduce the hash chain")

        let replay = Replay(seed: seed, events: events, finalHash: hash)
        let roundTripped = try Replay.decode(try replay.encode())
        XCTAssertEqual(roundTripped.finalHash, hash)
    }
}
