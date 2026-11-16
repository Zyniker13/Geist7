// MARK: - MainView

import RSCore
import SwiftUI

/// Main menu screen: start a new game, load a save, or read the rules.
struct MainView: View {
    @State private var showGame = false
    @State private var showResume = false
    @State private var showNewGame = false
    @State private var newGameStake: Int = 1
    @State private var newGameUseAI = false
    @State private var newGameOmen: String = "none"
    @State private var lastOutcome: Outcome?
    @State private var resumeSnapshot: SavedMatch?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Title
                Text("Rosette")
                    .font(.system(size: 48, design: .serif))
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.788, green: 0.631, blue: 0.231))  // gold
                    .padding(.top, 60)

                Text("Ancient Egyptian Board Game")
                    .font(.caption)
                    .foregroundColor(.gray)

                Spacer()

                // Menu buttons
                VStack(spacing: 16) {
                    if resumeSnapshot != nil {
                        Button(action: { showResume = true }) {
                            menuButton("Resume Match")
                        }
                    }

                    Button(action: { showNewGame = true }) {
                        menuButton("New Game")
                    }

                    Button(action: { showGame = true }) {
                        menuButton("Quick Match (vs AI)")
                    }

                    Button(action: {}) {
                        menuButton("Rules")
                    }
                    .disabled(true)  // Placeholder for P3

                    Button(action: {}) {
                        menuButton("Settings")
                    }
                    .disabled(true)  // Placeholder for P3
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
                resumeSnapshot = SaveManager.resumeCandidate()
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

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Game Settings")) {
                    Picker("Stake", selection: $stake) {
                        Text("1").tag(1)
                        Text("2").tag(2)
                        Text("4").tag(4)
                    }

                    Toggle("Play vs AI", isOn: $useAI)

                    Picker("Omen (one per match)", selection: $omen) {
                        Text("None").tag("none")
                        Text("Re-roll").tag("reroll")
                        Text("Unsafe Rosettes").tag("unsafeRosettes")
                        Text("Split Roll").tag("split")
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
    }
}
