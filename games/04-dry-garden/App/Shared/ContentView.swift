import SwiftUI

/// Root view: the placeholder P0 launch surface. The rules engine and
/// match flow arrive in P1/P2; the menu carries the title, subtitle,
/// and debug overlay so CI's smoke tests and screenshots have a stable
/// target from day one (S0.4).
struct ContentView: View {
    @State private var debugVisible = LaunchArguments.current.debugOverlay

    var body: some View {
        VStack(spacing: 16) {
            Text("Dry Garden")
                .font(.largeTitle.weight(.bold))
            Text("Set stones, rake gravel, own the courtyard")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Play") {}
                .buttonStyle(.borderedProminent)
                .disabled(true)
            Text("Rules engine arrives in P1")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topLeading) {
            if debugVisible {
                DebugOverlay(
                    seed: LaunchArguments.current.seed ?? 0,
                    tick: 0
                )
                .padding(8)
            }
        }
        .modifier(DebugToggleModifier { debugVisible.toggle() })
    }
}

/// Platform toggle wiring (S0.7): three-finger double tap on iOS,
/// ⌘⇧D on Mac.
struct DebugToggleModifier: ViewModifier {
    var onToggle: () -> Void

    func body(content: Content) -> some View {
        #if os(iOS)
            content
                .background { ThreeFingerDoubleTap(onTap: onToggle) }
                .overlay { DebugShortcut(onToggle: onToggle) }
        #else
            content.overlay { DebugShortcut(onToggle: onToggle) }
        #endif
    }
}
