// RSMeta — daily match (RS-P5.1).
//
// The daily match is seeded from the UTC date, so every player on the same
// UTC day derives the identical dice sequence and faces the same opponent.
// The seed is a deterministic finalizer over the UTC day number
// (ADR-0012); no wall-clock call happens here — the caller passes the
// date, which keeps the package testable and keeps the system clock out
// of the codebase.

import Foundation
import RSCore

/// A fully determined daily match: the UTC day, its seed, and the fixed
/// dice sequence every player that day plays with.
public struct DailyMatch: Sendable, Equatable {
    /// UTC days since 1970-01-01 for the match's date.
    public let day: Int
    /// Deterministic match seed derived from the day (ADR-0012).
    public let seed: UInt64
    /// The fixed dice stream: the k-th roll of the match is the k-th value.
    public let diceSequence: [Int]

    public init(day: Int, seed: UInt64, diceSequence: [Int]) {
        self.day = day
        self.seed = seed
        self.diceSequence = diceSequence
    }

    /// UTC days since 1970-01-01 for `date` (truncated; positive for all
    /// dates since the epoch).
    public static func utcDay(for date: Date) -> Int {
        Int(date.timeIntervalSince1970 / 86_400)
    }

    /// Deterministic seed for a UTC day: a SplitMix64-style finalizer over
    /// the day offset by the golden-ratio constant, so nearby days give
    /// uncorrelated seeds.
    public static func seed(forDay day: Int) -> UInt64 {
        var z = UInt64(bitPattern: Int64(day)) &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Derive the daily match for `date`. Two derivations for the same UTC
    /// day are always identical; different days give different seeds.
    public static func make(forDate date: Date, sequenceLength: Int = 5000) -> DailyMatch {
        let day = utcDay(for: date)
        let seed = seed(forDay: day)
        var rng = SeededRNG(seed: seed)
        var sequence = [Int]()
        sequence.reserveCapacity(sequenceLength)
        for _ in 0..<sequenceLength {
            sequence.append(DiceModel.tetra4.roll(rng: &rng))
        }
        return DailyMatch(day: day, seed: seed, diceSequence: sequence)
    }

    /// The daily opponent: a careful heuristic bot whose strength cycles
    /// 2...4 with the day, so the daily match stays fresh across a week.
    public static func opponent(forDay day: Int) -> RosetteBot {
        RosetteBot(personality: .careful, strength: 2 + (day % 3))
    }

    /// Play the daily match: `player` (seat 0) against the daily opponent
    /// (seat 1), with the fixed dice sequence. The same date always yields
    /// the same match for the same player.
    public static func play(
        forDate date: Date,
        player: some MatchBot,
        stake: Int = 2
    ) throws -> BotMatch.Record {
        let daily = make(forDate: date)
        return try BotMatch.play(
            seed: daily.seed,
            ruleset: .finkel,
            dice: .tetra4,
            stake: stake,
            bot0: player,
            bot1: opponent(forDay: daily.day),
            diceSequence: daily.diceSequence
        )
    }
}
