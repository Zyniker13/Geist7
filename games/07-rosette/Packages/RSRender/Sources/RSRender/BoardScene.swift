// RSRender — SpriteKit board scene and game nodes for Rosette

import RSCore
import SpriteKit

#if os(macOS)
    import AppKit
#endif

// MARK: - BoardScene

/// SpriteKit scene that renders a Rosette board state.
public final class BoardScene: SKScene {

    /// The current match state (read-only for rendering).
    public var matchState: MatchState? {
        didSet { render() }
    }

    /// The region art theme (RS-P6.1). Defaults to Ur; the app sets it from
    /// the circuit region before the first render.
    public var theme: RegionTheme = RegionTheme(region: .sumer) {
        didSet {
            if theme != oldValue, matchState != nil {
                render()
            }
        }
    }

    // MARK: - Layout constants

    private let boardPadding: CGFloat = 20
    private let squareSize: CGFloat = 50
    private let boardGap: CGFloat = 4

    // MARK: - Nodes

    private var boardBackground: SKNode?
    private var squareNodes: [[SKShapeNode]] = []

    /// Test-visible access to the laid-out square nodes (RSRenderTests read
    /// them to pin the board layout).
    var layoutSquares: [[SKShapeNode]] { squareNodes }
    private var pieceNodes: [PieceID: [PlayerID: SKShapeNode]] = [:]
    private var diceNode: SKLabelNode?
    private var rosetteHighlight: SKShapeNode?
    private var legalMoveHighlight: [SKShapeNode] = []
    private var _onSquareTap: ((Int) -> Void)?

    /// Handle tap/click on a square to trigger a move.
    public var onSquareTap: ((Int) -> Void)? {
        get { _onSquareTap }
        set { _onSquareTap = newValue }
    }

    /// When true, the dice pop animation is skipped (RS-P8.1 Reduce
    /// Motion). The app sets this from the system setting; the default is
    /// off so headless tests are deterministic.
    public var reduceMotionEnabled = false

    /// Called once, on the first frame cycle after the scene is presented
    /// (P8 performance instrumentation; nil in production).
    public var onFirstFrame: (() -> Void)?
    private var firstFrameMarked = false

    override public func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        if !firstFrameMarked {
            firstFrameMarked = true
            onFirstFrame?()
        }
    }

    /// The dice value shown on the last render, so the pop animation only
    /// runs when the value actually changes.
    private var lastDiceValue: Int?

    // MARK: - Drawing

    override public init(size: CGSize) {
        super.init(size: size)
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        // bitumen #1E1A17
        self.backgroundColor = SKColor(red: 0.118, green: 0.102, blue: 0.090, alpha: 1.0)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// SpriteKit calls this whenever the hosting view resizes (SwiftUI's
    /// `.resizeFill` re-sizes the scene after presentation; at first
    /// presentation the SKView's bounds may still be zero). Re-render so
    /// the board always fits the real size.
    override public func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        if matchState != nil {
            render()
        }
    }

    /// Re-render the board from the current match state (also called when
    /// the hosting view resizes). Exposed for tests.
    public func refreshLayout() {
        render()
    }

    /// Layout the board to fit the scene.
    private func layoutBoard() {
        let debugStart = ProcessInfo.processInfo.arguments.contains("-boardDebug")
            ? CFAbsoluteTimeGetCurrent() : 0
        defer {
            if debugStart > 0 {
                print(
                    "[boardDebug] layoutBoard took "
                        + String(format: "%.1f", (CFAbsoluteTimeGetCurrent() - debugStart) * 1000)
                        + " ms (size \(size))")
            }
        }
        // A degenerate size (the hosting SKView has no bounds yet, or the
        // scene was presented before layout) must not wipe the existing
        // geometry: skip until the size is real.
        guard size.width > 1, size.height > 1 else { return }

        // Calculate board dimensions: 3 rows of 7 squares + 2 extra squares
        let boardWidth = CGFloat(7) * (squareSize + boardGap) - boardGap
        // extra bottom row
        let boardHeight = CGFloat(3) * (squareSize + boardGap) - boardGap + squareSize

        let scale = min(
            size.width / (boardWidth + boardPadding * 2),
            size.height / (boardHeight + boardPadding * 2))

        let scaledSquare = squareSize * scale
        let scaledGap = boardGap * scale
        // Optical balance: the HUD bars cover the screen top and bottom, so
        // nudge the board up a touch of the square size to re-center it
        // between them.
        let boardY = scaledSquare * 0.22

        // Clear existing nodes
        for child in self.children {
            child.removeFromParent()
        }
        squareNodes = []
        pieceNodes = [:]
        legalMoveHighlight = []

        // Create squares
        let trackLength = 14  // Finkel rules
        let rows: [(row: Int, startCol: Int, count: Int)] = [
            (row: 0, startCol: 0, count: 7),  // top row: squares 0-6
            (row: 1, startCol: 0, count: 7),  // middle row: squares 7-13
            (row: 2, startCol: 0, count: 1),  // bottom row: exit square
        ]

        var rowIdx = 0
        for rowInfo in rows {
            var rowNodes: [SKShapeNode] = []
            for col in 0..<rowInfo.count {
                let squareIndex = rowIdx
                rowIdx += 1
                if squareIndex >= trackLength { break }

                // Center the row: offsets run −(count−1)/2 … +(count−1)/2.
                // (Float division — the integer-division version shifted
                // every row 2 columns right, off the board.)
                let colOffset = CGFloat(col) - CGFloat(rowInfo.count - 1) / 2.0
                let x = colOffset * (scaledSquare + scaledGap)
                let y =
                    CGFloat(rowInfo.row - 1) * (scaledSquare + scaledGap)
                    + boardY

                let square = SKShapeNode(
                    rectOf: CGSize(width: scaledSquare, height: scaledSquare),
                    cornerRadius: 4 * scale)

                // Determine square type (RS-P6.1: theme colors).
                let isRosette = [3, 7, 13].contains(squareIndex)
                let isSafeRosette = [7].contains(squareIndex)

                if isSafeRosette {
                    square.fillColor = theme.lapis.withAlpha(0.6)
                } else if isRosette {
                    square.fillColor = theme.lapis.withAlpha(0.45)
                } else {
                    square.fillColor = theme.squareShell.withAlpha(0.85)
                }

                square.strokeColor = theme.frame.withAlpha(0.9)
                square.lineWidth = 1.5 * scale
                square.position = CGPoint(x: x, y: y)
                square.name = "square_\(squareIndex)"
                square.zPosition = 0
                self.addChild(square)
                rowNodes.append(square)
            }
            squareNodes.append(rowNodes)
        }

        // Tavern backdrop behind everything (RS-P6.1): wall, beams, shelf,
        // lantern glow. Sized to the scene (features live in the visible
        // margins around the board). zPosition -20, below the board
        // background (-10).
        let backdrop = BoardArt.tavernBackdrop(theme: theme, size: size)
        backdrop.zPosition = -20
        self.addChild(backdrop)

        // Themed board background (RS-P6.1): worn-wood frame, bitumen
        // bedding, motif border. Added after the squares but placed behind
        // them with zPosition -10.
        let boardRect = CGRect(
            x: -boardWidth / 2 - 10, y: -boardHeight / 2 - 10 + boardY,
            width: boardWidth + 20, height: boardHeight + 20)
        let bg = BoardArt.boardBackground(theme: theme, boardRect: boardRect)
        bg.zPosition = -10
        self.addChild(bg)
        boardBackground = bg

        // Rosette flowers on top of the rosette squares (zPosition 1,
        // below the pieces).
        for squareIndex in [3, 7, 13] {
            if let sq = squareNode(for: squareIndex) {
                let flower = BoardArt.rosetteFlower(
                    theme: theme,
                    radius: scaledSquare * 0.30)
                flower.position = sq.position
                flower.zPosition = 1
                flower.name = "rosetteFlower_\(squareIndex)"
                self.addChild(flower)
            }
        }

        if ProcessInfo.processInfo.arguments.contains("-boardDebug") {
            print(
                "[boardDebug] sceneSize=\(size) scale=\(scale) "
                    + "scaledSquare=\(scaledSquare) children=\(children.count)")
            for child in children {
                let frame = child.calculateAccumulatedFrame()
                print(
                    "[boardDebug] child \(child.name ?? "<unnamed>") "
                        + "type=\(type(of: child)) pos=\(child.position) "
                        + "frame=\(frame)")
            }
        }
    }

    /// Get the SKShapeNode for a given square index.
    private func squareNode(for index: Int) -> SKShapeNode? {
        var count = 0
        for row in squareNodes {
            for sq in row {
                if count == index { return sq }
                count += 1
                if count >= 14 { break }
            }
            if count >= 14 { break }
        }
        return nil
    }

    /// Render the current match state.
    private func render() {
        guard let state = matchState else { return }

        layoutBoard()

        // Render pieces
        for piece in state.pieces {
            if piece.isBorneOff { continue }
            addPieceNode(piece: piece, state: state)
        }

        // Render dice value (RS-P8.1: accessibility label + pop animation
        // skipped under Reduce Motion).
        if let diceValue = state.diceValue {
            let label = SKLabelNode(text: "⚀ \(diceValue)")
            label.fontSize = 24
            label.position = CGPoint(x: 0, y: self.size.height / 2 - 40)
            label.fontColor = theme.gold
            label.zPosition = 4
            label.name = "diceDisplay"
            label.isAccessibilityElement = true
            label.accessibilityLabel = "Rolled \(diceValue)"
            self.addChild(label)
            diceNode = label
            if lastDiceValue != diceValue, !reduceMotionEnabled {
                // Keyed so tests can probe it with action(forKey:).
                label.run(
                    .sequence([
                        .scale(to: 1.15, duration: 0.08),
                        .scale(to: 1.0, duration: 0.08),
                    ]),
                    withKey: "dicePop")
            }
            lastDiceValue = diceValue
        } else {
            diceNode = nil
            lastDiceValue = nil
        }

        // Highlight rosettes
        highlightRosettes()
    }

    /// Add or update a piece node for a piece.
    private func addPieceNode(piece: Piece, state: MatchState) {
        let key = piece.id
        if pieceNodes[key] == nil {
            pieceNodes[key] = [.player0: SKShapeNode(), .player1: SKShapeNode()]
        }

        // The node was just created (or existed) for this piece, and every
        // piece has a node per player, so both lookups are safe.
        guard let playerNodes = pieceNodes[key], let targetNode = playerNodes[piece.owner] else {
            return
        }

        // Position piece
        if piece.position == -1 {
            // Off board - place to the side
            let side = piece.owner == .player0 ? -1 : 1
            targetNode.position = CGPoint(
                x: self.size.width / 2 + CGFloat(side) * 80,
                y: -self.size.height / 4)
        } else if piece.position == -2 {
            // Borne off - place at the top
            let side = piece.owner == .player0 ? -1 : 1
            targetNode.position = CGPoint(
                x: self.size.width / 2 + CGFloat(side) * 60,
                y: self.size.height / 2 - 20)
        } else {
            // On board
            if let sq = squareNode(for: piece.position) {
                targetNode.position = sq.position
            }
        }

        // Style piece (RS-P6.1: theme colors; RS-P8.1: shape distinguishes
        // the players for color-blind players).
        let radius: CGFloat = 18
        let isPlayer0 = piece.owner == .player0
        targetNode.path = PieceShape.forOwner(piece.owner).cgPath(radius: radius)
        targetNode.fillColor = isPlayer0 ? theme.lapis : theme.squareShell
        targetNode.strokeColor = theme.gold
        targetNode.lineWidth = 2
        targetNode.zPosition = 2
        targetNode.name = "piece_\(piece.owner.rawValue)_\(piece.id)"
        targetNode.isAccessibilityElement = true
        targetNode.accessibilityLabel = pieceAccessibilityLabel(for: piece)

        // Re-parent on every render: layoutBoard() clears the scene graph,
        // so a cached piece node must be re-added even if it already has a
        // dictionary entry (it must never sit outside the scene graph).
        if targetNode.parent !== self {
            targetNode.removeFromParent()
            self.addChild(targetNode)
        }
    }

    /// Highlight rosette squares.
    private func highlightRosettes() {
        // Remove existing highlights
        rosetteHighlight?.removeFromParent()
        rosetteHighlight = nil

        for index in [3, 7, 13] {
            if let sq = squareNode(for: index) {
                let highlight = SKShapeNode(circleOfRadius: sq.frame.width / 2 + 4)
                highlight.strokeColor = theme.gold.withAlpha(0.8)
                highlight.lineWidth = 2
                highlight.position = sq.position
                highlight.fillColor = .clear
                highlight.zPosition = 3
                highlight.name = "rosetteHighlight"
                self.addChild(highlight)
                if rosetteHighlight == nil { rosetteHighlight = highlight }
            }
        }
    }

    /// Highlight legal moves for the current player.
    public func highlightLegalMoves(for moves: [Move]) {
        // Remove old highlights
        for node in legalMoveHighlight {
            node.removeFromParent()
        }
        legalMoveHighlight = []

        for move in moves {
            if move.destination >= 0, let sq = squareNode(for: move.destination) {
                let highlight = SKShapeNode(
                    rectOf: CGSize(width: sq.frame.width - 4, height: sq.frame.height - 4),
                    cornerRadius: 4)
                highlight.strokeColor = theme.accent.withAlpha(0.8)
                highlight.lineWidth = 3
                highlight.position = sq.position
                highlight.fillColor = .clear
                highlight.zPosition = 3
                highlight.name = "legalMoveHighlight"
                self.addChild(highlight)
                legalMoveHighlight.append(highlight)
            }
        }
    }

    /// Clear all highlights.
    public func clearHighlights() {
        for node in legalMoveHighlight {
            node.removeFromParent()
        }
        legalMoveHighlight = []
    }

    // MARK: - Accessibility (RS-P8.1)

    /// The VoiceOver label for a piece: owner, and where it sits.
    public func pieceAccessibilityLabel(for piece: Piece) -> String {
        let owner = piece.owner == .player0 ? "Your piece" : "Opponent's piece"
        if piece.isBorneOff {
            return "\(owner), borne off"
        }
        if piece.position < 0 {
            return "\(owner), waiting"
        }
        return "\(owner), square \(piece.position)"
    }

    // MARK: - Input Handling (touch on iOS, mouse on macOS)

    /// Dispatch a location in scene coordinates to the square-tap handler.
    private func dispatchTap(at location: CGPoint) {
        for child in children {
            if child.name?.hasPrefix("square_") == true,
                child.contains(location)
            {
                if let squareIndexStr = child.name?.dropFirst(7),
                    let squareIndex = Int(squareIndexStr)
                {
                    _onSquareTap?(squareIndex)
                    return
                }
            }
        }
    }

    #if os(iOS)
        /// Handle touch on a square to trigger a move.
        override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = touches.first else { return }
            dispatchTap(at: touch.location(in: self))
        }
    #else
        /// Mouse equivalent (S2.1): a click selects a square.
        override public func mouseDown(with event: NSEvent) {
            dispatchTap(at: event.location(in: self))
        }
    #endif
}
