// DryGardenApp.swift — iOS/iPadOS entry point.
//
// Launch arguments are registered so snapshot/UI-test runs can drive
// deterministic scenarios (-debugOverlay -seed N ...).

import SwiftUI

@main
struct DryGardenApp: App {
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
