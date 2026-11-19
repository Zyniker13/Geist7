// MARK: - GameView

import RSAI
import RSCore
import RSMeta
import RSAudio
import RSPlatform
import RSRender
import SpriteKit
import SwiftUI

/// Main game screen: SpriteKit board + SwiftUI HUD overlay.
struct GameView: View {
    @StateObject private var viewModel: GameViewModel
    @State private var selectedPiece: PieceID?
    @State private var showResults = false
    @State private var showPauseMenu = false
    /// The audio layer (RS-P6.2): deterministic procedural music + SFX.
    @State private var audio = AudioController()

    let onMatchComplete: (Outcome) -> Void
    /// Whether the results overlay offers "Play Again" (hidden in circuit
    /// matches, where the circuit session drives the next match).
    private let showPlayAgain: Bool
    /// Dismisses the results overlay when the flow that pushed this match
    /// owns the navigation (daily); nil keeps only the menu controls.
    private let onLeaveResults: (() -> Void)?

    init(
        stake: Int = 1,
        omen: String? = nil,
        useAI: Bool = false,
        seed: UInt64 = 42,
        onMatchComplete: @escaping (Outcome) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: GameViewModel(
                stakeValue: stake,
                omenId: omen,
                useAI: useAI,
                seed: LaunchArguments.seed ?? seed,
                // §7: Finkel opponents play via the solved table; the plain
                // heuristic can cycle on mutual capture-avoidance (seed-42
                // regression). The quick match is always Finkel, so it gets
                // OptimalBot (RS-P7 open item).
                opponentBot: useAI ? OptimalBot() : nil
            ))
        self.onMatchComplete = onMatchComplete
        self.onLeaveResults = nil
        self.showPlayAgain = true
    }

    /// Start a match under a specific content ruleset (circuit path).
    init(
        ruleset: RuleSet,
        dice: DiceModel,
        fortunes: [FortuneSquare] = [],
        omens1: [Omen] = [],
        stake: Int,
        region: String = "sumer",
        useAI: Bool = true,
        seed: UInt64 = 42,
        showPlayAgain: Bool = true,
        onMatchComplete: @escaping (Outcome) -> Void
    ) {
        let vm = GameViewModel(
            ruleset: ruleset,
            dice: dice,
            fortunes: fortunes,
            omens1: omens1,
            stakeValue: stake,
            useAI: useAI,
            seed: LaunchArguments.seed ?? seed,
            autoSave: false,
            region: region,
            // §7: Finkel taverns play via the solved table (OptimalBot);
            // variant taverns use the expectiminimax bot (VariantBot). The
            // plain heuristic can cycle on mutual capture-avoidance
            // (seed-42 regression), so no tavern fields it.
            opponentBot: useAI
                ? (ruleset == RuleSet.finkel ? OptimalBot() : VariantBot()) as any MatchBot
                : nil
        )
        vm.onMatchComplete = onMatchComplete
        _viewModel = StateObject(wrappedValue: vm)
        self.onMatchComplete = onMatchComplete
        self.onLeaveResults = nil
        self.showPlayAgain = showPlayAgain
    }

    /// Resume a saved match (S2.4).
    init(
        snapshot: SavedMatch,
        onMatchComplete: @escaping (Outcome) -> Void
    ) {
        let vm = GameViewModel(snapshot: snapshot)
        vm.onMatchComplete = onMatchComplete
        _viewModel = StateObject(wrappedValue: vm)
        self.onMatchComplete = onMatchComplete
        self.onLeaveResults = nil
        self.showPlayAgain = true
    }

    /// Play today's daily match (RS-P7.1): the date-seeded dice sequence
    /// (everyone that UTC day draws the same dice) against the daily
    /// opponent bot, at the daily stake. A daily is one sitting: no
    /// autosave, and "Play Again" returns to the menu rather than
    /// restarting the same match.
    init(
        daily: DailyMatch,
        onMatchComplete: @escaping (Outcome) -> Void,
        onLeaveResults: @escaping () -> Void
    ) {
        let vm = GameViewModel(
            ruleset: .finkel,
            dice: .tetra4,
            stakeValue: 2,
            useAI: true,
            seed: daily.seed,
            autoSave: false,
            opponentBot: DailyMatch.opponent(forDay: daily.day),
            diceSource: DiceSource(values: daily.diceSequence)
        )
        vm.onMatchComplete = onMatchComplete
        _viewModel = StateObject(wrappedValue: vm)
        self.onMatchComplete = onMatchComplete
        self.onLeaveResults = onLeaveResults
        self.showPlayAgain = false
    }

    var body: some View {
        ZStack {
            // SpriteKit board
            BoardView(viewModel: viewModel)
                .ignoresSafeArea()

            // Scrim behind the HUD bars: keeps player info legible over
            // light tavern walls (e.g. Egypt's sand tone).
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [.black.opacity(0.55), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 140)
                Spacer()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 150)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // HUD overlay
            VStack(spacing: 0) {
                // Top bar: player info and dice
                topBar

                Spacer()

                // Bottom bar: action buttons
                bottomBar
            }
            .padding(.horizontal)
            .padding(.bottom)
            .safeAreaPadding(.top)
        }
        .overlay(alignment: .center) {
            if viewModel.isPaused {
                pauseOverlay
            }
        }
        .overlay(alignment: .center) {
            if viewModel.isComplete {
                resultsOverlay
            }
        }
        .onAppear {
            audio.startMusic()
            viewModel.kickAutoPilotIfNeeded()
        }
        .onDisappear {
            audio.stopMusic()
        }
        .onReceive(viewModel.$lastEvents) { events in
            audio.handle(events: events)
        }
        #if os(macOS)
        // Mac keyboard 1-7 picks a piece (RS-P7.2b).
        .macKeyboard { viewModel.handleNumberKey($0) }
        #endif
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Player 0 info
            playerInfo(player: .player0, isCurrent: viewModel.matchState.currentPlayer == .player0)

            Spacer()

            // Center column: dice value, doubling cube (R-10), and the
            // ruleset's name with its history label (R-15, HIST3.1).
            VStack(spacing: 2) {
                if let diceValue = viewModel.matchState.diceValue {
                    Text("Roll \(diceValue)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                } else if viewModel.matchState.plies == 0 {
                    Text("Roll to start")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    Text("Roll dice")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Text("Cube ×\(viewModel.matchState.cube.value)")
                    .font(.caption)
                    .foregroundColor(viewModel.matchState.cube.value > 1 ? .yellow : .gray)
                Text(
                    "\(viewModel.matchState.ruleset.label) · \(viewModel.matchState.ruleset.historyLabel.displayName)"
                )
                .font(.caption2)
                .foregroundColor(.gray)
            }

            Spacer()

            // Player 1 info
            playerInfo(player: .player1, isCurrent: viewModel.matchState.currentPlayer == .player1)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        // RS-P8.1: one VoiceOver element announces turn, score, and dice.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(topBarAccessibilityLabel)
    }

    /// The combined top-bar announcement (RS-P8.1).
    private var topBarAccessibilityLabel: String {
        let state = viewModel.matchState
        let turn = state.currentPlayer == .player0 ? "Your turn" : "Opponent's turn"
        let dice = state.diceValue.map { "Dice \($0)" } ?? "Dice not rolled"
        let yours = state.borneOff[.player0] ?? 0
        let theirs = state.borneOff[.player1] ?? 0
        return "\(turn). \(dice). Cube times \(state.cube.value). "
            + "You have borne off \(yours) of 7, opponent \(theirs) of 7."
    }

    private func playerInfo(player: PlayerID, isCurrent: Bool) -> some View {
        VStack(alignment: player == .player0 ? .leading : .trailing) {
            Text(player == .player0 ? "You" : "Opponent")
                .font(.caption)
                .foregroundColor(isCurrent ? .yellow : .gray)
            let borneOff = viewModel.matchState.borneOff[player] ?? 0
            Text("Borne off: \(borneOff)/7")
                .font(.caption2)
                .foregroundColor(.white)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            // Odds panel + activity line (RS-P8.1: accessibility labels)
            Text(viewModel.oddsText)
                .font(.caption)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Win rate: \(viewModel.oddsText)")

            if !viewModel.lastEventText.isEmpty {
                Text(viewModel.lastEventText)
                    .font(.caption2)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(viewModel.lastEventText)
            }

            if let errorText = viewModel.errorText {
                Text(errorText)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
            }

            // Action buttons
            HStack(spacing: 16) {
                if !viewModel.matchState.hasRolled {
                    Button(action: { viewModel.rollDice() }) {
                        Text("Roll Dice")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .disabled(viewModel.isPaused || viewModel.isComplete)
                }

                // Offer a double (R-10): before rolling, once per turn.
                if !viewModel.matchState.isComplete,
                    !viewModel.matchState.hasRolled,
                    !viewModel.matchState.doubleOffered,
                    !viewModel.matchState.hasDoubledThisTurn,
                    !viewModel.matchState.cubeDead,
                    viewModel.matchState.currentPlayer == .player0
                {
                    Button(action: { viewModel.offerDouble() }) {
                        Text("Double")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.purple)
                            .cornerRadius(8)
                    }
                    .disabled(viewModel.isPaused)
                }

                // A pending double is answered by the opponent of the offerer
                // (the offerer keeps the turn), so player 0 answers while the
                // current player is player 1.
                if viewModel.matchState.doubleOffered
                    && viewModel.matchState.currentPlayer == .player1
                {
                    Button(action: { viewModel.acceptDouble() }) {
                        Text("Accept Double")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.orange)
                            .cornerRadius(8)
                    }
                    .disabled(viewModel.isPaused)

                    Button(action: { viewModel.declineDouble() }) {
                        Text("Decline")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                    .disabled(viewModel.isPaused)
                }

                if !viewModel.matchState.isComplete {
                    Button(action: { viewModel.togglePause() }) {
                        Image(systemName: viewModel.isPaused ? "play.circle" : "pause.circle")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }

                Button(action: { showPauseMenu = true }) {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
    }

    // MARK: - Overlays

    private var pauseOverlay: some View {
        Color.black.opacity(0.8)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 20) {
                    Text("Paused")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Button(action: { viewModel.togglePause() }) {
                        Text("Resume")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(Color.green)
                            .cornerRadius(8)
                    }

                    Button(action: { showPauseMenu = true }) {
                        Text("Menu")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(Color.gray)
                            .cornerRadius(8)
                    }
                }
            }
    }

    private var resultsOverlay: some View {
        Color.black.opacity(0.85)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 20) {
                    // Player 0 is "You": victory when player 0 won.
                    let playerWon = viewModel.outcome?.winner == .player0
                    Text(playerWon ? "Victory!" : "Defeat")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(playerWon ? .green : .red)

                    if let outcome = viewModel.outcome {
                        let score = outcome.score(for: .player0)
                        Text(
                            "Winner: \(outcome.winner == .player0 ? "You" : "Opponent")"
                                + (outcome.gammon ? " (gammon)" : "")
                        )
                        .font(.body)
                        .foregroundColor(.white)

                        Text(
                            "Score: \(score >= 0 ? "+" : "")\(score)  ·  Cube ×\(outcome.cubeValue)  ·  Plies: \(outcome.plies)"
                        )
                        .font(.caption)
                        .foregroundColor(.gray)
                    }

                    if showPlayAgain {
                        Button(action: { viewModel.restart() }) {
                            Text("Play Again")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 16)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }

                    if let onLeaveResults {
                        Button(action: onLeaveResults) {
                            Text("Done")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 16)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .accessibilityIdentifier("Results Done")
                    }

                    Button(action: { showPauseMenu = true }) {
                        Text("Main Menu")
                            .font(.body)
                            .foregroundColor(.gray)
                    }
                }
            }
    }
}

// MARK: - BoardView (SpriteKit wrapper)

/// Shared scene construction/update used by the platform wrappers below.
@MainActor
enum BoardSceneHost {
    /// Build the scene and wire the tap handler.
    static func makeScene(viewModel: GameViewModel) -> BoardScene {
        // The scene lays out to its own size; .resizeFill stretches it to the
        // hosting view, so a nominal iPad-portrait size is enough here.
        let scene = BoardScene(size: CGSize(width: 1024, height: 1366))
        scene.scaleMode = .resizeFill
        scene.reduceMotionEnabled = MotionPolicy.systemReduceMotion
        scene.theme = RegionTheme(region: RSRegion(contentID: viewModel.regionID))
        scene.matchState = viewModel.matchState
        scene.onSquareTap = { squareIndex in
            // Find one of the current player's movable pieces on this square.
            // Piece ids repeat per owner, so filter by owner first.
            if let piece = viewModel.matchState.pieces.first(where: {
                $0.owner == viewModel.matchState.currentPlayer
                    && $0.position == squareIndex
                    && viewModel.matchState.movablePieceIds.contains($0.id)
            }) {
                viewModel.movePiece(piece.id)
            }
        }
        return scene
    }

    /// Push the current state and highlights into the scene.
    static func update(scene: BoardScene?, viewModel: GameViewModel) {
        guard let scene else { return }
        scene.matchState = viewModel.matchState
        if viewModel.matchState.hasRolled && !viewModel.legalMoves.isEmpty {
            scene.highlightLegalMoves(for: viewModel.legalMoves)
        } else {
            scene.clearHighlights()
        }
    }

    /// Configure the hosting SKView (fps overlay only in UI-test/debug runs).
    static func configure(_ skView: SKView) {
        skView.allowsTransparency = true
        let showDebug = ProcessInfo.processInfo.arguments.contains("-showFPS")
        skView.showsFPS = showDebug
        skView.showsNodeCount = showDebug
    }

    final class Coordinator {
        var scene: BoardScene?
    }
}

#if os(iOS)
    struct BoardView: UIViewRepresentable {
        @ObservedObject var viewModel: GameViewModel

        func makeUIView(context: Context) -> SKView {
            let skView = SKView()
            BoardSceneHost.configure(skView)
            let scene = BoardSceneHost.makeScene(viewModel: viewModel)
            skView.presentScene(scene)
            context.coordinator.scene = scene
            return skView
        }

        func updateUIView(_ skView: SKView, context: Context) {
            BoardSceneHost.update(scene: context.coordinator.scene, viewModel: viewModel)
        }

        func makeCoordinator() -> BoardSceneHost.Coordinator {
            BoardSceneHost.Coordinator()
        }
    }
#else
    struct BoardView: NSViewRepresentable {
        @ObservedObject var viewModel: GameViewModel

        func makeNSView(context: Context) -> SKView {
            let skView = SKView()
            BoardSceneHost.configure(skView)
            let scene = BoardSceneHost.makeScene(viewModel: viewModel)
            skView.presentScene(scene)
            context.coordinator.scene = scene
            return skView
        }

        func updateNSView(_ skView: SKView, context: Context) {
            BoardSceneHost.update(scene: context.coordinator.scene, viewModel: viewModel)
        }

        func makeCoordinator() -> BoardSceneHost.Coordinator {
            BoardSceneHost.Coordinator()
        }
    }
#endif
