// MattangApp.swift — iOS/iPadOS entry point.
//
// Launch arguments are registered so snapshot/UI-test runs can drive
// deterministic self-play (-startMatch -seed N -autoPilot ...).

import SwiftUI

@main
struct MattangApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear { registerLaunchArguments() }
        }
    }
}

/// P0: argument registration hook; phase implementations read
/// LaunchArguments directly.
private func registerLaunchArguments() {
    _ = LaunchArguments.self
}
