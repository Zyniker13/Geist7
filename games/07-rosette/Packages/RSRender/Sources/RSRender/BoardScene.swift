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

    // MARK: - Layout constants

    private let boardPadding: CGFloat = 20
    private let squareSize: CGFloat = 50
    private let boardGap: CGFloat = 4

    // MARK: - Nodes

    private var boardBackground: SKShapeNode?
    private var squareNodes: [[SKShapeNode]] = []
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

    /// Layout the board to fit the scene.
    private func layoutBoard() {
        // Calculate board dimensions: 3 rows of 7 squares + 2 extra squares
        let boardWidth = CGFloat(7) * (squareSize + boardGap) - boardGap
        // extra bottom row
        let boardHeight = CGFloat(3) * (squareSize + boardGap) - boardGap + squareSize

        let scale = min(
            size.width / (boardWidth + boardPadding * 2),
            size.height / (boardHeight + boardPadding * 2))

        let scaledSquare = squareSize * scale
        let scaledGap = boardGap * scale

        // Clear existing nodes
        for child in self.children {
            child.removeFromParent()
        }
        squareNodes = []
        pieceNodes = [:]
        legalMoveHighlight = []

        // Create board background
        let bg = SKShapeNode(
            rectOf: CGSize(width: boardWidth, height: boardHeight),
            cornerRadius: 8 * scale)
        // papyrus #E2D3A6
        bg.fillColor = SKColor(red: 0.906, green: 0.827, blue: 0.651, alpha: 1.0)
        bg.position = CGPoint(x: 0, y: 0)
        bg.lineWidth = 3 * scale
        // tavern wood #5A3A22
        bg.strokeColor = SKColor(red: 0.353, green: 0.227, blue: 0.133, alpha: 1.0)
        self.addChild(bg)
        boardBackground = bg

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

                let colOffset = CGFloat(col) - CGFloat((rowInfo.count - 1) / 2) / 2.0
                let x = colOffset * (scaledSquare + scaledGap)
                let y = CGFloat(rowInfo.row - 1) * (scaledSquare + scaledGap)

                let square = SKShapeNode(
                    rectOf: CGSize(width: scaledSquare, height: scaledSquare),
                    cornerRadius: 4 * scale)

                // Determine square type
                let isRosette = [3, 7, 13].contains(squareIndex)
                let isSafeRosette = [7].contains(squareIndex)

                if isSafeRosette {
                    // lapis #26619C
                    square.fillColor = SKColor(red: 0.149, green: 0.380, blue: 0.612, alpha: 0.6)
                } else if isRosette {
                    // gold #C9A13B
                    square.fillColor = SKColor(red: 0.788, green: 0.631, blue: 0.231, alpha: 0.6)
                } else {
                    // shell #EFE7D3
                    square.fillColor = SKColor(red: 0.937, green: 0.906, blue: 0.827, alpha: 0.8)
                }

                square.strokeColor = SKColor(red: 0.353, green: 0.227, blue: 0.133, alpha: 1.0)
                square.lineWidth = 1.5 * scale
                square.position = CGPoint(x: x, y: y)
                square.name = "square_\(squareIndex)"
                self.addChild(square)
                rowNodes.append(square)
            }
            squareNodes.append(rowNodes)
        }

        // Add rosette symbols
        for squareIndex in [3, 7, 13] {
            if let sq = squareNode(for: squareIndex) {
                let symbol = SKLabelNode(text: "✦")
                symbol.fontColor = SKColor(red: 0.937, green: 0.906, blue: 0.827, alpha: 1.0)
                symbol.fontSize = scaledSquare * 0.4
                symbol.position = sq.position
                self.addChild(symbol)
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

        // Render dice value
        if let diceValue = state.diceValue {
            let label = SKLabelNode(text: "⚀ \(diceValue)")
            label.fontSize = 24
            label.position = CGPoint(x: 0, y: self.size.height / 2 - 40)
            label.fontColor = .white
            label.name = "diceDisplay"
            self.addChild(label)
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

        // Style piece
        let radius: CGFloat = 18
        let isPlayer0 = piece.owner == .player0
        targetNode.path = CGPath(
            ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2),
            transform: nil)
        targetNode.fillColor =
            isPlayer0
            // lapis
            ? SKColor(red: 0.149, green: 0.380, blue: 0.612, alpha: 1.0)
            // shell
            : SKColor(red: 0.937, green: 0.906, blue: 0.827, alpha: 1.0)
        // gold
        targetNode.strokeColor = SKColor(red: 0.788, green: 0.631, blue: 0.231, alpha: 1.0)
        targetNode.lineWidth = 2
        targetNode.name = "piece_\(piece.owner.rawValue)_\(piece.id)"

        if !playerNodes.values.contains(targetNode) {
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
                highlight.strokeColor = SKColor(red: 0.788, green: 0.631, blue: 0.231, alpha: 0.8)
                highlight.lineWidth = 2
                highlight.position = sq.position
                highlight.fillColor = .clear
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
                // red limestone
                highlight.strokeColor = SKColor(red: 0.639, green: 0.231, blue: 0.165, alpha: 0.8)
                highlight.lineWidth = 3
                highlight.position = sq.position
                highlight.fillColor = .clear
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
