// RSRender — BoardScene accessibility tests (RS-P8.1).
//
// Covers the VoiceOver labels on pieces and dice, the owner shapes, and
// the Reduce Motion gate on the dice pop.

import RSCore
import SpriteKit
import XCTest
@testable import RSRender

/// SpriteKit's API surface is main-actor isolated in the 27 SDK, so the whole
/// suite runs on the main actor.
@MainActor
final class BoardSceneAccessibilityTests: XCTestCase {

    private func makeScene() -> BoardScene {
        let scene = BoardScene(size: CGSize(width: 1024, height: 1366))
        scene.theme = RegionTheme(region: RSRegion(contentID: "rosette.ankh"))
        return scene
    }

    private func freshState() -> MatchState {
        MatchState.newMatch(ruleset: .finkel, dice: .tetra4, stake: 2)
    }

    func test_pieceAccessibilityLabels() {
        let scene = makeScene()
        XCTAssertEqual(
            scene.pieceAccessibilityLabel(for: piece(id: 0, owner: .player0, position: 3)),
            "Your piece, square 3")
        XCTAssertEqual(
            scene.pieceAccessibilityLabel(for: piece(id: 1, owner: .player1, position: -1)),
            "Opponent's piece, waiting")
        XCTAssertEqual(
            scene.pieceAccessibilityLabel(for: piece(id: 2, owner: .player1, position: -2)),
            "Opponent's piece, borne off")
    }

    /// Piece's public API is `making(id:owner:)` (starts off-board); set the
    /// position after.
    private func piece(id: PieceID, owner: PlayerID, position: Int) -> Piece {
        var piece = Piece.making(id: id, owner: owner)
        piece.position = position
        return piece
    }

    func test_pieceNodesUseOwnerShapesAndLabels() {
        let scene = makeScene()
        var state = freshState()
        // pieces[0] is player 0's piece 0; pieces[1] is player 1's piece 0.
        state.pieces[0].position = 0
        state.pieces[1].position = 1
        scene.matchState = state

        let p0 = scene.childNode(withName: "piece_0_0") as? SKShapeNode
        let p1 = scene.childNode(withName: "piece_1_0") as? SKShapeNode
        XCTAssertNotNil(p0, "player 0's piece node should be on the board")
        XCTAssertNotNil(p1, "player 1's piece node should be on the board")

        // The shapes must differ (RS-P8.1): (12, 12) is inside a circle of
        // radius 18 (dist ≈ 17) but outside a diamond with vertices at
        // radius 18 (its edges sit at radius/√2 ≈ 12.7).
        let probe = CGPoint(x: 12, y: 12)
        XCTAssertTrue(p0?.path?.contains(probe) ?? false, "player 0's piece should be a circle")
        XCTAssertFalse(p1?.path?.contains(probe) ?? false, "player 1's piece should be a diamond")

        XCTAssertEqual(p0?.accessibilityLabel, "Your piece, square 0")
        XCTAssertEqual(p1?.accessibilityLabel, "Opponent's piece, square 1")
    }

    func test_diceNodeHasAccessibilityLabel() {
        let scene = makeScene()
        var state = freshState()
        state.diceValue = 5
        scene.matchState = state

        let dice = scene.childNode(withName: "diceDisplay")
        XCTAssertNotNil(dice, "the dice display should be rendered")
        XCTAssertEqual(dice?.accessibilityLabel, "Rolled 5")
    }

    func test_dicePopRunsWhenValueChanges() {
        let scene = makeScene()
        var state = freshState()
        state.diceValue = 5
        scene.matchState = state
        let first = scene.childNode(withName: "diceDisplay")
        XCTAssertNotNil(first?.action(forKey: "dicePop"), "first render of a new value should pop")

        // Re-render with the same value: no pop.
        scene.matchState = state
        let second = scene.childNode(withName: "diceDisplay")
        XCTAssertNil(second?.action(forKey: "dicePop"), "an unchanged value should not pop")
    }

    func test_dicePopSkippedUnderReduceMotion() {
        let scene = makeScene()
        scene.reduceMotionEnabled = true
        var state = freshState()
        state.diceValue = 5
        scene.matchState = state

        let dice = scene.childNode(withName: "diceDisplay")
        XCTAssertNil(dice?.action(forKey: "dicePop"), "Reduce Motion must suppress the dice pop")
    }
}
