// MARK: - GameView

import RSCore
import RSRender
import SpriteKit
import SwiftUI

/// Main game screen: SpriteKit board + SwiftUI HUD overlay.
struct GameView: View {
    @StateObject private var viewModel: GameViewModel
    @State private var selectedPiece: PieceID?
    @State private var showResults = false
    @State private var showPauseMenu = false

    let onMatchComplete: (Outcome) -> Void

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
                seed: LaunchArguments.seed ?? seed
            ))
        self.onMatchComplete = onMatchComplete
    }

    /// Resume a saved match (S2.4).
    init(
        snapshot: SavedMatch,
        onMatchComplete: @escaping (Outcome) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: GameViewModel(snapshot: snapshot))
        self.onMatchComplete = onMatchComplete
    }

    var body: some View {
        ZStack {
            // SpriteKit board
            BoardView(viewModel: viewModel)
                .ignoresSafeArea()

            // HUD overlay
            VStack(spacing: 0) {
                // Top bar: player info and dice
                topBar

                Spacer()

                // Bottom bar: action buttons
                bottomBar
            }
            .padding()
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
        .onReceive(viewModel.$matchState) { state in
            // Fire match completion when the state becomes complete.
            if state.isComplete, let outcome = viewModel.outcome {
                onMatchComplete(outcome)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Player 0 info
            playerInfo(player: .player0, isCurrent: viewModel.matchState.currentPlayer == .player0)

            Spacer()

            // Center column: dice value and doubling cube (R-10).
            VStack(spacing: 2) {
                if let diceValue = viewModel.matchState.diceValue {
                    Text("Roll \(diceValue)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                } else {
                    Text("Roll to start")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Text("Cube ×\(viewModel.matchState.cube.value)")
                    .font(.caption)
                    .foregroundColor(viewModel.matchState.cube.value > 1 ? .yellow : .gray)
            }

            Spacer()

            // Player 1 info
            playerInfo(player: .player1, isCurrent: viewModel.matchState.currentPlayer == .player1)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
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
            // Odds panel + activity line
            Text(viewModel.oddsText)
                .font(.caption)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)

            if !viewModel.lastEventText.isEmpty {
                Text(viewModel.lastEventText)
                    .font(.caption2)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
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

                    Button(action: { viewModel.restart() }) {
                        Text("Play Again")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(8)
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
