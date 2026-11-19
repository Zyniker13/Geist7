// MARK: - GameCenterManager

import RSPlatform
import SwiftUI

/// App-facing Game Center wrapper (RS-P7.1). Best-effort: Game Center is
/// never required to play. When no Apple account is signed in (or Game
/// Center is unavailable, as in the local build), submissions fail
/// silently and the status is surfaced in Settings.
///
/// The local substitute (`_CONVENTIONS.md` §8.2): this build has no App
/// Store Connect registration, so the real `GameKitGameCenter` cannot
/// reach live leaderboards. The service still authenticates and reports
/// through the same `GameCenterLike` surface the shipping app uses; wiring
/// the real account and leaderboard kinds is a maintainer issue.
@MainActor
final class GameCenterManager: ObservableObject {
    /// Game Center availability, shown in Settings.
    enum Status: Equatable {
        case unknown
        case unavailable
        case available
    }

    static let shared = GameCenterManager()

    @Published private(set) var status: Status = .unknown

    private let service: GameCenterService
    private let defaults: UserDefaults

    /// The local record of daily wins (the leaderboard mirror count; the
    /// authoritative count lives on the device until a real Game Center app
    /// exists — see the maintainer issue).
    private static let dailyWinsKey = "rosette.daily-wins.v1"
    /// The UTC day the last daily win was reported for (one report per day).
    private static let dailyReportedKey = "rosette.daily-reported.v1"

    init(gc: any GameCenterLike = GameKitGameCenter(), defaults: UserDefaults = .standard) {
        self.service = GameCenterService(gc)
        self.defaults = defaults
    }

    /// Authenticate at app start. Never throws to the caller: a failure
    /// just means Game Center features are unavailable.
    func authenticate() async {
        do {
            try await service.authenticate()
            status = service.isAuthenticated ? .available : .unavailable
        } catch {
            status = .unavailable
        }
    }

    /// Report a daily win for `day`. Idempotent per day: the win is
    /// submitted to the `daily-wins` leaderboard once (the cumulative local
    /// count is bumped with it).
    func reportDailyWin(day: Int) async {
        let reported = defaults.integer(forKey: Self.dailyReportedKey)
        guard reported != day else { return }  // already reported today
        let count = defaults.integer(forKey: Self.dailyWinsKey) + 1
        do {
            try await service.submit(score: count, to: .dailyWins)
            defaults.set(day, forKey: Self.dailyReportedKey)
            defaults.set(count, forKey: Self.dailyWinsKey)
        } catch {
            // Best-effort: the local count still records the win.
            defaults.set(count, forKey: Self.dailyWinsKey)
        }
    }

    /// The player's recorded daily-win count (Settings display).
    var dailyWinCount: Int {
        defaults.integer(forKey: Self.dailyWinsKey)
    }

    /// Submit the circuit purse to the `circuit-purse` leaderboard
    /// (RS-P7.1). The purse is in-game gold only (no real money).
    func reportCircuitPurse(_ purse: Int) async {
        guard status == .available else { return }
        try? await service.submitCircuitPurse(purse)
    }
}
