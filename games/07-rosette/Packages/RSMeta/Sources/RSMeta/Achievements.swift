// RSMeta — achievements (RS-P5.1).
//
// Twenty achievements, evaluated purely from `PlayerStats` and the
// just-finished `MatchResult`. Unlock state is a Codable value type; the
// UTC day of unlock is recorded for the trophy shelf.

import Foundation

/// One achievement in the catalog.
public struct Achievement: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let icon: String

    public init(id: String, name: String, description: String, icon: String) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
    }
}

/// The fixed catalog of twenty achievements.
public enum AchievementCatalog {
    public static let all: [Achievement] = [
        Achievement(
            id: "first-match",
            name: "First Move",
            description: "Play your first match.",
            icon: "figure.play"
        ),
        Achievement(
            id: "first-win",
            name: "First Blood",
            description: "Win your first match.",
            icon: "trophy"
        ),
        Achievement(
            id: "rosette-first",
            name: "Rosette Runner",
            description: "Land a piece on a rosette.",
            icon: "circle.hexagongrid"
        ),
        Achievement(
            id: "rosette-streak",
            name: "Triple Rosette",
            description: "Land three pieces on rosettes in one match.",
            icon: "circle.hexagongrid.fill"
        ),
        Achievement(
            id: "double-down",
            name: "Double or Nothing",
            description: "Win a match with the cube at 4 or more.",
            icon: "die.face.five"
        ),
        Achievement(
            id: "cube-master",
            name: "Cube Master",
            description: "Win five matches with the cube at 8 or more.",
            icon: "die.face.six"
        ),
        Achievement(
            id: "omen-first",
            name: "Fate's Favor",
            description: "Play your first omen.",
            icon: "moon.stars"
        ),
        Achievement(
            id: "omen-collector",
            name: "Omen Collector",
            description: "Play all three kinds of omen.",
            icon: "moon.stars.circle"
        ),
        Achievement(
            id: "omen-master",
            name: "Master of Omens",
            description: "Play twenty-five omens.",
            icon: "moon.stars.fill"
        ),
        Achievement(
            id: "daily-first",
            name: "Rise and Roll",
            description: "Complete a daily match.",
            icon: "sun"
        ),
        Achievement(
            id: "daily-streak-3",
            name: "Three Days",
            description: "Complete daily matches on three days in a row.",
            icon: "sun.max"
        ),
        Achievement(
            id: "daily-streak-7",
            name: "Week of Wagers",
            description: "Complete daily matches on seven days in a row.",
            icon: "calendar"
        ),
        Achievement(
            id: "circuit-first",
            name: "Circuit Breaker",
            description: "Complete the tavern circuit.",
            icon: "map"
        ),
        Achievement(
            id: "circuit-rich",
            name: "Fat Purse",
            description: "Finish the circuit with a purse of 100 or more.",
            icon: "bag"
        ),
        Achievement(
            id: "bear-off",
            name: "Home Stretch",
            description: "Bear off all your pieces in a match.",
            icon: "flag.checkered"
        ),
        Achievement(
            id: "gammon",
            name: "Clean Sweep",
            description: "Win a gammon.",
            icon: "bolt"
        ),
        Achievement(
            id: "comeback",
            name: "The Comeback",
            description: "Win a match after the opponent captured three of your pieces.",
            icon: "arrow.uturn.backward"
        ),
        Achievement(
            id: "streak-3",
            name: "On a Roll",
            description: "Win three matches in a row.",
            icon: "flame"
        ),
        Achievement(
            id: "streak-5",
            name: "Unstoppable",
            description: "Win five matches in a row.",
            icon: "flame.fill"
        ),
        Achievement(
            id: "veteran",
            name: "Tavern Veteran",
            description: "Play fifty matches.",
            icon: "hourglass"
        ),
    ]

    /// The catalog has exactly twenty achievements (RS-P5.1).
    public static var count: Int { all.count }
}

/// Persistent unlock state for the catalog.
public struct AchievementState: Codable, Sendable, Equatable {
    public private(set) var unlocked: Set<String> = []
    /// Achievement id to UTC day of unlock.
    public private(set) var unlockedDays: [String: Int] = [:]

    public init() {}

    /// Evaluate the catalog against `stats` (which must already include
    /// `result`, if any) and the just-finished `result`; return the ids
    /// that unlocked on this call.
    public mutating func evaluate(
        stats: PlayerStats,
        result: MatchResult?,
        day: Int? = nil
    ) -> [String] {
        var newly: [String] = []
        for achievement in AchievementCatalog.all {
            guard !unlocked.contains(achievement.id) else { continue }
            guard condition(achievement.id, stats: stats, result: result) else { continue }
            unlocked.insert(achievement.id)
            if let day { unlockedDays[achievement.id] = day }
            newly.append(achievement.id)
        }
        return newly
    }

    public func isUnlocked(_ id: String) -> Bool {
        unlocked.contains(id)
    }

    private func condition(_ id: String, stats: PlayerStats, result: MatchResult?) -> Bool {
        switch id {
        case "first-match":
            return stats.matches >= 1
        case "first-win":
            return stats.wins >= 1
        case "rosette-first":
            return stats.rosettesLanded >= 1
        case "rosette-streak":
            return (result?.rosettesLanded ?? 0) >= 3
        case "double-down":
            return (result?.won ?? false) && (result?.cubeValue ?? 0) >= 4
        case "cube-master":
            return stats.highCubeWins >= 5
        case "omen-first":
            return stats.omensPlayed >= 1
        case "omen-collector":
            return stats.omenKinds.count >= 3
        case "omen-master":
            return stats.omensPlayed >= 25
        case "daily-first":
            return stats.dailyMatches >= 1
        case "daily-streak-3":
            return stats.bestDailyStreak >= 3
        case "daily-streak-7":
            return stats.bestDailyStreak >= 7
        case "circuit-first":
            return stats.circuitCompletions >= 1
        case "circuit-rich":
            return stats.bestCircuitPurse >= 100
        case "bear-off":
            return (result?.piecesBorneOff ?? 0) >= 14
        case "gammon":
            return (result?.won ?? false) && (result?.gammon ?? false)
        case "comeback":
            return (result?.won ?? false) && (result?.piecesCapturedByOpponent ?? 0) >= 3
        case "streak-3":
            return stats.bestWinStreak >= 3
        case "streak-5":
            return stats.bestWinStreak >= 5
        case "veteran":
            return stats.matches >= 50
        default:
            return false
        }
    }
}
