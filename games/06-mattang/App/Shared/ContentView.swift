import SwiftUI

/// Root view: the menu and the match (MT-P2.2). The P0 launch surface
/// (title, subtitle, debug overlay) is preserved; `-startMatch`
/// enters the match directly for tests and snapshots.
struct ContentView: View {
    @State private var debugVisible = LaunchArguments.current.debugOverlay
    @State private var matchModel: MatchModel?
    @State private var showAbout = false
    /// MT-P3.2: the tutorial opens from the menu, or directly under
    /// `-scenario tutorial` for the scripted UI test.
    @State private var showTutorial = LaunchArguments.current.scenario == "tutorial"

    var body: some View {
        if let model = matchModel {
            MatchView(model: model, onExit: exitMatch)
        } else if showTutorial {
            TutorialView(lessons: TutorialContent.loadLessons())
        } else {
            menu
        }
    }

    private var menu: some View {
        VStack(spacing: 16) {
            Text("Mattang")
                .font(.largeTitle.weight(.bold))
            Text("Swell-reading abstract strategy")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Play") { startMatch() }
                .buttonStyle(.borderedProminent)
            Button("Learn: the tutorial") { showTutorial = true }
                .buttonStyle(.bordered)
            Button("About the Tradition") { showAbout = true }
                .buttonStyle(.bordered)
        }
        .sheet(isPresented: $showAbout) {
            AboutView { showAbout = false }
        }
        .sheet(isPresented: $showTutorial) {
            TutorialView(lessons: TutorialContent.loadLessons())
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
        .onAppear {
            if LaunchArguments.current.startMatch, matchModel == nil {
                startMatch()
            }
        }
    }

    private func startMatch() {
        matchModel = MatchModel.forCurrentLaunch()
    }

    private func exitMatch() {
        matchModel = nil
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
