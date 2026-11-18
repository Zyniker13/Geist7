// RSMeta — local leaderboards (RS-P5.1).
//
// Leaderboards are local and offline: a fixed-size list of named scores
// per kind, persisted by `MetaStore`. Ties break by the earlier day, so
// the first player to reach a score keeps the higher rank.

import Foundation

/// The kinds of leaderboard the meta layer keeps.
public enum LeaderboardKind: String, Codable, Sendable, CaseIterable {
    case dailyWins = "daily-wins"
    case circuitPurse = "circuit-purse"
}

/// One named score on a leaderboard.
public struct LeaderboardEntry: Codable, Sendable, Equatable {
    public let name: String
    public let score: Int
    /// UTC day the score was set (tie-break: earlier day ranks higher).
    public let day: Int
    public let kind: LeaderboardKind

    public init(name: String, score: Int, day: Int, kind: LeaderboardKind) {
        self.name = name
        self.score = score
        self.day = day
        self.kind = kind
    }
}

/// A fixed-size local leaderboard for one kind of score.
public struct LocalLeaderboard: Codable, Sendable, Equatable {
    public static let limit = 10

    public private(set) var entries: [LeaderboardEntry] = []

    public init(entries: [LeaderboardEntry] = []) {
        self.entries = entries
    }

    /// Add a score, keeping at most `limit` entries per kind.
    public mutating func submit(name: String, score: Int, kind: LeaderboardKind, day: Int) {
        entries.append(LeaderboardEntry(name: name, score: score, day: day, kind: kind))
        var kept: [LeaderboardEntry] = []
        for k in LeaderboardKind.allCases {
            kept.append(contentsOf: top(k))
        }
        entries = kept
    }

    /// The current top list for `kind`: best score first, ties to the
    /// earlier day.
    public func top(_ kind: LeaderboardKind) -> [LeaderboardEntry] {
        entries
            .filter { $0.kind == kind }
            .sorted { a, b in
                if a.score != b.score { return a.score > b.score }
                return a.day < b.day
            }
            .prefix(Self.limit)
            .map { $0 }
    }
}
