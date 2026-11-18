// RSMeta — player statistics (RS-P5.1).
//
// `MatchResult` is the per-match record from the local player's
// perspective; `PlayerStats` aggregates them. Both are plain Codable
// value types so the meta layer persists with no runtime services.

import Foundation
import RSCore

/// The outcome of one match from the perspective of the local player.
public struct MatchResult: Codable, Sendable, Equatable {
    public let won: Bool
    public let gammon: Bool
    public let cubeValue: Int
    public let stake: Int
    public let plies: Int
    public let rosettesLanded: Int
    public let piecesCaptured: Int
    public let piecesCapturedByOpponent: Int
    public let piecesBorneOff: Int
    public let omensPlayed: [String]
    public let doublesOffered: Int
    public let isDaily: Bool
    public let dailyDay: Int?

    public init(
        won: Bool,
        gammon: Bool,
        cubeValue: Int,
        stake: Int,
        plies: Int,
        rosettesLanded: Int,
        piecesCaptured: Int,
        piecesCapturedByOpponent: Int,
        piecesBorneOff: Int,
        omensPlayed: [String],
        doublesOffered: Int,
        isDaily: Bool = false,
        dailyDay: Int? = nil
    ) {
        self.won = won
        self.gammon = gammon
        self.cubeValue = cubeValue
        self.stake = stake
        self.plies = plies
        self.rosettesLanded = rosettesLanded
        self.piecesCaptured = piecesCaptured
        self.piecesCapturedByOpponent = piecesCapturedByOpponent
        self.piecesBorneOff = piecesBorneOff
        self.omensPlayed = omensPlayed
        self.doublesOffered = doublesOffered
        self.isDaily = isDaily
        self.dailyDay = dailyDay
    }

    /// Derive a result from a finished bot match, from `perspective`'s
    /// seat.
    public static func from(record: BotMatch.Record, perspective: PlayerID) -> MatchResult {
        let outcome = record.finalState.outcome
        var rosettes = 0
        var captured = 0
        var capturedByOpp = 0
        var borneOff = 0
        var doubles = 0
        var omens: [String] = []
        for event in record.events {
            switch event {
            case .rosetteLanded(let player):
                if player == perspective { rosettes += 1 }
            case .pieceCaptured(_, let by):
                if by == perspective { captured += 1 } else { capturedByOpp += 1 }
            case .pieceBorneOff(_, let player):
                if player == perspective { borneOff += 1 }
            case .doubleOffered(let by):
                if by == perspective { doubles += 1 }
            case .omenPlayed(let id, _):
                omens.append(id)
            default:
                break
            }
        }
        return MatchResult(
            won: outcome?.winner == perspective,
            gammon: outcome?.gammon == true,
            cubeValue: outcome?.cubeValue ?? 1,
            stake: outcome?.initialStake ?? 0,
            plies: outcome?.plies ?? record.actions.count,
            rosettesLanded: rosettes,
            piecesCaptured: captured,
            piecesCapturedByOpponent: capturedByOpp,
            piecesBorneOff: borneOff,
            omensPlayed: omens,
            doublesOffered: doubles
        )
    }
}

/// Aggregate, persistent statistics for the local player.
public struct PlayerStats: Codable, Sendable, Equatable {
    public private(set) var matches: Int = 0
    public private(set) var wins: Int = 0
    public private(set) var losses: Int = 0
    public private(set) var gammonsWon: Int = 0
    public private(set) var gammonsLost: Int = 0
    public private(set) var rosettesLanded: Int = 0
    public private(set) var piecesCaptured: Int = 0
    public private(set) var omensPlayed: Int = 0
    public private(set) var omenKinds: Set<String> = []
    public private(set) var doublesOffered: Int = 0
    public private(set) var highCubeWins: Int = 0
    public private(set) var netStake: Int = 0
    public private(set) var winStreak: Int = 0
    public private(set) var bestWinStreak: Int = 0
    public private(set) var dailyMatches: Int = 0
    public private(set) var dailyDays: Set<Int> = []
    public private(set) var dailyStreak: Int = 0
    public private(set) var bestDailyStreak: Int = 0
    public private(set) var circuitCompletions: Int = 0
    public private(set) var bestCircuitPurse: Int = 0

    public init() {}

    /// Fold one finished match into the totals. `omenKind` maps an omen id
    /// to its kind (from the content tables); the default treats the id as
    /// its own kind.
    public mutating func record(_ result: MatchResult, omenKind: (String) -> String? = { $0 }) {
        matches += 1
        let base = result.stake * result.cubeValue
        let amount = result.gammon ? base * 2 : base
        if result.won {
            wins += 1
            winStreak += 1
            bestWinStreak = max(bestWinStreak, winStreak)
            if result.gammon { gammonsWon += 1 }
            if result.cubeValue >= 8 { highCubeWins += 1 }
            netStake += amount
        } else {
            losses += 1
            winStreak = 0
            if result.gammon { gammonsLost += 1 }
            netStake -= amount
        }
        rosettesLanded += result.rosettesLanded
        piecesCaptured += result.piecesCaptured
        omensPlayed += result.omensPlayed.count
        for id in result.omensPlayed {
            if let kind = omenKind(id) { omenKinds.insert(kind) }
        }
        doublesOffered += result.doublesOffered
        if result.isDaily, let day = result.dailyDay {
            dailyMatches += 1
            if !dailyDays.contains(day) {
                dailyDays.insert(day)
                dailyStreak = dailyDays.contains(day - 1) ? dailyStreak + 1 : 1
                bestDailyStreak = max(bestDailyStreak, dailyStreak)
            }
        }
    }

    /// Record a completed tavern circuit (RS-P5.1 leaderboard feed).
    public mutating func recordCircuitCompletion(purse: Int) {
        circuitCompletions += 1
        bestCircuitPurse = max(bestCircuitPurse, purse)
    }
}
