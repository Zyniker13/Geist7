import SwiftUI

@main
struct RosetteApp: App {
    // Game Center is best-effort (RS-P7.1): authenticate once at launch;
    // the status shows in Settings and reporting fails silently when
    // unavailable.
    @StateObject private var gameCenter = GameCenterManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameCenter)
                .environmentObject(CloudSyncManager.shared)
                .task {
                    await gameCenter.authenticate()
                }
        }
    }
}
