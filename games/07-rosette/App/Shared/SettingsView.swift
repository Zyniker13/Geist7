// MARK: - SettingsView

import RSPlatform
import SwiftUI

/// The Settings sheet (RS-P7.1): the accessibility toggles (RS-P8.4),
/// Game Center status, daily wins, iCloud sync status, and the app
/// version. The online and privacy choices for this build remain local
/// substitutes — nothing to configure until the real services exist.
struct SettingsView: View {
    @EnvironmentObject private var gameCenter: GameCenterManager
    @EnvironmentObject private var cloud: CloudSyncManager

    /// RS-P8.4: the title scales with Dynamic Type instead of a fixed
    /// point size.
    @ScaledMetric(relativeTo: .title) private var titleSize: CGFloat = 32

    /// RS-P8.4: the left-handed layout toggle, shared with the game view.
    @AppStorage(GameViewLayout.leftHandedKey) private var leftHanded = false

    /// RS-P8.4: the haptic-feedback toggle (captures, match end).
    @AppStorage(HapticPreferences.enabledKey) private var hapticsEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.system(size: titleSize, design: .serif))
                .fontWeight(.bold)
                .foregroundColor(Color(red: 0.788, green: 0.631, blue: 0.231))

            accessibilitySection
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

    private var accessibilitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Accessibility")
                .font(.headline)
                .foregroundColor(.white)
            Toggle("Left-Handed Layout", isOn: $leftHanded)
                .font(.subheadline)
                .foregroundColor(.white)
            Toggle("Haptic Feedback", isOn: $hapticsEnabled)
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .accessibilityIdentifier("Accessibility Settings")
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
