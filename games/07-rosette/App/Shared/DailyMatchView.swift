// MARK: - DailyMatchView

import RSCore
import RSMeta
import RSPlatform
import SwiftUI

/// The daily match screen (RS-P7.1): today's date-seeded match — every
/// player on the same UTC day draws the same dice and faces the same
/// opponent. Winning reports the win to Game Center (when available).
struct DailyMatchView: View {
    @StateObject private var model = DailyMatchModel()
    @State private var showGame = false
    /// autoPilot auto-enters the match once per presentation; returning
    /// from the finished match re-fires onAppear and must not re-push it.
    @State private var autoEntered = false
    @EnvironmentObject private var gameCenter: GameCenterManager

    var body: some View {
        VStack(spacing: 24) {
            Text("Daily Match")
                .font(.system(size: 36, design: .serif))
                .fontWeight(.bold)
                .foregroundColor(Color(red: 0.788, green: 0.631, blue: 0.231))

            Text(model.dayText)
                .font(.headline)
                .foregroundColor(.gray)

            Text("Everyone plays the same dice today.")
                .font(.subheadline)
                .foregroundColor(.gray)

            // The daily opponent (strength cycles 2–4 with the day).
            VStack(spacing: 8) {
                Text("Today's Opponent")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(model.opponentText)
                    .font(.title3)
                    .foregroundColor(.white)
                Text("Stake: \(model.stake)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(20)
            .background(Color(red: 0.353, green: 0.227, blue: 0.133))  // tavern wood
            .cornerRadius(12)

            // Today's settled result, shown after the match completes
            // (persisted by DailyResultStore, so it survives relaunches).
            if let shown = model.lastResult {
                Text("Today's result: \(shown == .won ? "Won" : "Lost")")
                    .font(.headline)
                    .foregroundColor(shown == .won ? .green : .orange)
                    .accessibilityIdentifier("Daily Result")
            }

            Spacer()

            Button(action: { showGame = true }) {
                Text(model.playButtonText)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(red: 0.353, green: 0.227, blue: 0.133))
                    .cornerRadius(8)
            }
            .accessibilityIdentifier("Play Daily")
        }
        .padding(.horizontal, 40)
        .onAppear {
            model.refreshResult()
            // autoPilot smoke runs enter the match directly (no tap needed;
            // the same launch-arg already self-starts the match itself).
            if ProcessInfo.processInfo.arguments.contains("-autoPilot"), !autoEntered {
                autoEntered = true
                showGame = true
            }
        }
        .navigationDestination(isPresented: $showGame) {
            GameView(
                daily: model.daily,
                onMatchComplete: { outcome in
                    model.record(outcome: outcome, gameCenter: gameCenter)
                },
                onLeaveResults: { showGame = false }
            )
        }
    }
}

// MARK: - DailyMatchModel

/// The daily match's derived view state and result recording.
@MainActor
final class DailyMatchModel: ObservableObject {
    /// The UTC day this view was built for (fixed at presentation).
    let daily: DailyMatch

    /// Today's recorded result, for the result label and button state.
    @Published private(set) var lastResult: DailyResultStore.Result?

    private let store: DailyResultStore

    // Wall clock: "today's" daily match is a display concern, not match state.
    // swiftlint:disable:next banned_api
    init(daily: DailyMatch = DailyMatch.make(forDate: Date()), store: DailyResultStore = DailyResultStore()) {
        self.daily = daily
        self.store = store
        self.lastResult = store.result(for: daily.day)
    }

    /// Re-read the store (e.g. after returning from the match).
    func refreshResult() {
        lastResult = store.result(for: daily.day)
    }

    var dayText: String {
        let date = Date(timeIntervalSince1970: Double(daily.day) * 86_400)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return "UTC \(formatter.string(from: date))"
    }

    /// The daily opponent's description (strength cycles 2–4).
    var opponentText: String {
        let strength = 2 + (daily.day % 3)
        return "The Careful Merchant · Strength \(strength)"
    }

    var stake: Int { 2 }

    var playButtonText: String {
        switch store.result(for: daily.day) {
        case .won: return "Play Again (not for the leaderboard)"
        case .lost, .none: return "Play Today's Match"
        }
    }

    /// Record the outcome: a win is reported to Game Center once per day.
    func record(outcome: Outcome, gameCenter: GameCenterManager) {
        guard outcome.winner == .player0 else {
            store.record(day: daily.day, result: .lost)
            lastResult = .lost
            return
        }
        let firstWin = store.result(for: daily.day) != .won
        store.record(day: daily.day, result: .won)
        lastResult = .won
        if firstWin {
            Task { await gameCenter.reportDailyWin(day: daily.day) }
        }
    }
}
