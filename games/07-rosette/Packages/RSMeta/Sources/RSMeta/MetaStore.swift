// RSMeta — persistence (RS-P5.1).
//
// JSON files in a caller-chosen directory (tests use a temp dir; the app
// uses Application Support). Missing or corrupt files fall back to
// defaults so a fresh install always boots.

import Foundation

/// JSON persistence for the meta layer: stats, achievements,
/// leaderboards.
public struct MetaStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// The default on-device location: Application Support/Geist7/Rosette.
    public static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Geist7/Rosette", isDirectory: true)
    }

    // MARK: Stats

    public func loadStats() -> PlayerStats {
        load(PlayerStats.self, "stats.json") ?? PlayerStats()
    }

    public func saveStats(_ stats: PlayerStats) throws {
        try save(stats, "stats.json")
    }

    // MARK: Achievements

    public func loadAchievements() -> AchievementState {
        load(AchievementState.self, "achievements.json") ?? AchievementState()
    }

    public func saveAchievements(_ state: AchievementState) throws {
        try save(state, "achievements.json")
    }

    // MARK: Leaderboards

    public func loadLeaderboard(_ kind: LeaderboardKind) -> LocalLeaderboard {
        load(LocalLeaderboard.self, "leaderboard-\(kind.rawValue).json") ?? LocalLeaderboard()
    }

    public func saveLeaderboard(_ board: LocalLeaderboard, _ kind: LeaderboardKind) throws {
        try save(board, "leaderboard-\(kind.rawValue).json")
    }

    // MARK: Helpers

    private func load<T: Decodable>(_ type: T.Type, _ name: String) -> T? {
        let url = directory.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T, _ name: String) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(value)
        try data.write(to: directory.appendingPathComponent(name), options: .atomic)
    }
}
