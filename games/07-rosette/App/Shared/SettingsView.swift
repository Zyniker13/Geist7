// MARK: - SettingsView

import RSPlatform
import SwiftUI

/// The Settings sheet (RS-P7.1): Game Center status, daily wins, iCloud
/// sync status, and the app version. No toggles yet — the online and
/// privacy choices for this build are "local substitutes", so there is
/// nothing to configure until the real services exist.
struct SettingsView: View {
    @EnvironmentObject private var gameCenter: GameCenterManager
    @EnvironmentObject private var cloud: CloudSyncManager

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.system(size: 32, design: .serif))
                .fontWeight(.bold)
                .foregroundColor(Color(red: 0.788, green: 0.631, blue: 0.231))

            gameCenterSection
            cloudSection
            Spacer()
            Text("Version \(appVersion)")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(30)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.098, green: 0.086, blue: 0.075))  // dark wood
    }

    private var gameCenterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Game Center")
                .font(.headline)
                .foregroundColor(.white)
            Text(gameCenterText)
                .font(.subheadline)
                .foregroundColor(.gray)
            Text("Daily wins: \(gameCenter.dailyWinCount)")
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .accessibilityIdentifier("Game Center Status")
    }

    private var gameCenterText: String {
        switch gameCenter.status {
        case .available: return "Signed in"
        case .unavailable: return "Not available (needs a signed-in Apple account)"
        case .unknown: return "Checking…"
        }
    }

    private var cloudSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("iCloud Sync")
                .font(.headline)
                .foregroundColor(.white)
            Text(cloudText)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .accessibilityIdentifier("iCloud Status")
    }

    private var cloudText: String {
        "Local save (this build stores your circuit on this device)"
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        return (info?["CFBundleShortVersionString"] as? String) ?? "1"
    }
}
