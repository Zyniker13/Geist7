// MattangApp.swift — macOS entry point.
//
// Same shared screens as iOS (S0.4). Debug overlay toggles with ⌘⇧D.

import SwiftUI

@main
struct MattangApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear { registerLaunchArguments() }
                .frame(minWidth: 720, minHeight: 540)
        }
    }
}

/// P0: argument registration hook; phase implementations read
/// LaunchArguments directly.
private func registerLaunchArguments() {
    _ = LaunchArguments.self
}
