// MARK: - MainView

import RSContent
import RSCore
import SwiftUI

/// Main menu screen: start a new game, load a save, or read the rules.
struct MainView: View {
    /// RS-P8.1: the title scales with Dynamic Type instead of a fixed
    /// point size.
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 48

    @State private var showGame = false
    @State private var showResume = false
    @State private var showNewGame = false
    @State private var showCircuit = false
    @State private var showTutorial = false
    @State private var showHistory = false
    @State private var showDaily = false
    @State private var showSettings = false
    @State private var newGameStake: Int = 1
    @State private var newGameUseAI = true
    @State private var newGameOmen: String = "none"
    @State private var lastOutcome: Outcome?
    @State private var resumeSnapshot: SavedMatch?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Title
                Text("Rosette")
                    .font(.system(size: titleSize, design: .serif))
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.788, green: 0.631, blue: 0.231))  // gold
                    .padding(.top, 60)

                Text("A Near Eastern race game — the rules are a modern reconstruction")
                    .font(.caption)
                    .foregroundColor(.gray)

                Spacer()

                RosetteMedallion()

                Spacer()

                // Menu buttons
                VStack(spacing: 16) {
                    if resumeSnapshot != nil {
                        Button(action: {
                            BoardDebug.mark("resume tapped")
                            showResume = true
                        }) {
                            menuButton("Resume Match")
                        }
                    }

                    Button(action: { showCircuit = true }) {
                        menuButton("Tavern Circuit")
                    }

                    Button(action: { showDaily = true }) {
                        menuButton("Daily Match")
                    }

                    Button(action: { showNewGame = true }) {
                        menuButton("Single Match")
                    }

                    Button(action: { showTutorial = true }) {
                        menuButton("How to Play")
                    }

                    Button(action: { showHistory = true }) {
                        menuButton("Rules & History")
                    }

                    Button(action: { showSettings = true }) {
                        menuButton("Settings")
                    }
                }
                .padding(.horizontal, 40)

                Spacer()

                // Version
                Text("v0.0.1")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.bottom, 20)
            }
            .navigationTitle("Rosette")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationDestination(isPresented: $showGame) {
                GameView(
                    stake: newGameStake,
                    omen: newGameOmen == "none" ? nil : newGameOmen,
                    useAI: newGameUseAI,
                    seed: 42,
                    onMatchComplete: { outcome in
                        lastOutcome = outcome
                    }
                )
            }
            .navigationDestination(isPresented: $showCircuit) {
                CircuitView()
            }
            .navigationDestination(isPresented: $showDaily) {
                DailyMatchView()
            }
            .navigationDestination(isPresented: $showTutorial) {
                TutorialView()
            }
            .navigationDestination(isPresented: $showHistory) {
                HistoryView()
            }
            .navigationDestination(isPresented: $showResume) {
                if let snapshot = resumeSnapshot {
                    GameView(
                        snapshot: snapshot,
                        onMatchComplete: { outcome in
                            lastOutcome = outcome
                        }
                    )
                }
            }
            .onAppear {
                BoardDebug.mark("menu onAppear")
                resumeSnapshot = SaveManager.resumeCandidate()
                if LaunchArguments.startMatch {
                    showGame = true
                }
                if LaunchArguments.autoResume, resumeSnapshot != nil {
                    BoardDebug.mark("resume tapped (auto)")
                    showResume = true
                }
                if LaunchArguments.daily {
                    showDaily = true
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showNewGame) {
                NewGameView(
                    stake: $newGameStake,
                    useAI: $newGameUseAI,
                    omen: $newGameOmen,
                    onConfirm: {
                        showNewGame = false
                        showGame = true
                    })
            }
        }
    }

    private func menuButton(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(red: 0.353, green: 0.227, blue: 0.133))  // tavern wood
            .cornerRadius(8)
    }
}

// MARK: - NewGameView

/// Sheet for configuring a new game.
struct NewGameView: View {
    @Binding var stake: Int
    @Binding var useAI: Bool
    @Binding var omen: String
    var onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    /// Content omens for the picker (R-12's closed set, from omens.json).
    @State private var omenDefs: [OmenDef] = []

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Game Settings")) {
                    Picker("Stake", selection: $stake) {
                        Text("1").tag(1)
                        Text("2").tag(2)
                        Text("4").tag(4)
                    }

                    // RS-P3.3: pass-and-play is the two-player hot-seat mode.
                    Picker("Players", selection: $useAI) {
                        Text("Solo vs AI").tag(true)
                        Text("Pass & Play").tag(false)
                    }

                    Picker("Omen (one per match)", selection: $omen) {
                        Text("None").tag("none")
                        ForEach(omenDefs, id: \.id) { def in
                            Text("\(def.name) · \(def.label.displayName)").tag(def.id)
                        }
                    }
                }

                Section(header: Text("Board")) {
                    Text("Finkel rules: 7 pieces, 14-square path, rosettes at 4, 8 and 14.")
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("New Game")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        onConfirm()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if omenDefs.isEmpty {
                omenDefs = (try? ContentLoader().loadOmens()) ?? []
            }
        }
    }
}
