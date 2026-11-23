// Replay.swift — deterministic replay support and stable state hashing.
//
// _CONVENTIONS S0.6: every game records a Replay (seed, ordered events,
// final state hash) and a golden-replay test harness verifies it.
// INV-4 (Dry Garden roadmap): replay determinism — the same seed and
// action list must rebuild the identical state.
//
// Swift's `Hasher` is seeded per process, so `Hashable` hashes are NOT
// stable across runs or devices. State hashes that appear in replays,
// debug overlays, and golden tests use FNV-1a 64 over a canonical
// sorted-keys JSON encoding instead, which is stable everywhere.

import Foundation

/// FNV-1a 64-bit (Fowler, Noll, Vo). Used only for replay verification,
/// never for security.
public enum FNV1a64: Sendable {
    public static let offsetBasis: UInt64 = 0xCBF2_9CE4_8422_2325
    public static let prime: UInt64 = 0x0000_0100_0000_01B3

    public static func hash(_ data: [UInt8]) -> UInt64 {
        var h = offsetBasis
        for b in data {
            h ^= UInt64(b)
            h = h &* prime
        }
        return h
    }

    public static func hash(_ string: String) -> UInt64 {
        hash(Array(string.utf8))
    }
}

/// Stable hash for any Encodable value: canonical JSON with sorted keys,
/// then FNV-1a 64. The same value hashes identically on every device and
/// in every process.
public enum StateHashing: Sendable {
    public static func stableHash<T: Encodable>(_ value: T) throws -> UInt64 {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        return FNV1a64.hash([UInt8](data))
    }
}

/// A single recorded ply in a replay.
public struct ReplayEvent: Codable, Sendable, Equatable {
    public let ply: Int
    public let action: String
    public let params: [String: String]

    public init(ply: Int, action: String, params: [String: String] = [:]) {
        self.ply = ply
        self.action = action
        self.params = params
    }
}

/// A complete replay: the seed that generated the match, the ordered
/// event list, and the stable hash of the final state for verification.
public struct Replay: Codable, Sendable, Equatable {
    public let seed: UInt64
    public let version: Int
    public let events: [ReplayEvent]
    public let finalHash: UInt64

    public init(seed: UInt64, version: Int = 1, events: [ReplayEvent], finalHash: UInt64) {
        self.seed = seed
        self.version = version
        self.events = events
        self.finalHash = finalHash
    }

    public func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> Replay {
        try JSONDecoder().decode(Replay.self, from: data)
    }

    public func save(to url: URL) throws {
        try encode().write(to: url)
    }

    public static func load(from url: URL) throws -> Replay {
        try decode(Data(contentsOf: url))
    }
}
