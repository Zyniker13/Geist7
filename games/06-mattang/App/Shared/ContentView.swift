import SwiftUI

/// P0 placeholder root view. Phase implementations replace the body
/// with the real menu flow; the launch surface stays identical.
struct ContentView: View {
    @State private var debugVisible = LaunchArguments.current.debugOverlay

    var body: some View {
        VStack(spacing: 16) {
            Text("Mattang")
                .font(.largeTitle.weight(.bold))
            Text("Swell-reading abstract strategy")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("P0 scaffold")
                .font(.caption2.monospaced())
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
            content.background { ThreeFingerDoubleTap(onTap: onToggle) }
        #else
            content
                .background {
                    DebugShortcut(onToggle: onToggle)
                }
        #endif
    }
}

#Preview {
    ContentView()
}
