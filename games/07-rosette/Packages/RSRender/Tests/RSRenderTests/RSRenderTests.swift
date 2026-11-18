import SpriteKit
import XCTest

@testable import RSCore
@testable import RSRender

final class RSRenderTests: XCTestCase {
    func testPlaceholder() {
        XCTAssertTrue(true)
    }

    // MARK: - RS-P6.1 art themes

    /// The Ur palette is pinned to RESEARCH.md §1: lapis lazuli, shell,
    /// red limestone, bitumen, and gold. Drift breaks the attested look.
    func testUrPaletteMatchesResearch() {
        let theme = RegionTheme(region: .sumer)
        XCTAssertEqual(
            SKColor.hex(theme.lapis), 0x26428B, "lapis lazuli")
        XCTAssertEqual(
            SKColor.hex(theme.squareShell), 0xEFE6D2, "shell")
        XCTAssertEqual(
            SKColor.hex(theme.accent), 0xA0422D, "red limestone")
        XCTAssertEqual(
            SKColor.hex(theme.bedding), 0x2B2620, "bitumen")
        XCTAssertEqual(
            SKColor.hex(theme.gold), 0xC9A44C, "gold")
        XCTAssertEqual(theme.motif, .diamondChips, "Ur's border motif")
    }

    /// The three regions must be visually distinct: no two themes share
    /// the same frame/shell/motif identity.
    func testRegionThemesAreDistinct() {
        let themes = [
            RegionTheme(region: .sumer),
            RegionTheme(region: .egypt),
            RegionTheme(region: .mexica),
        ]
        let ids = Set(
            themes.map { theme in
                let frame = SKColor.hex(theme.frame)
                let shell = SKColor.hex(theme.squareShell)
                return "\(frame)/\(shell)/\(theme.motif)"
            }
        )
        XCTAssertEqual(ids.count, 3, "regions must not share a visual identity")
    }

    /// Regression: the tavern backdrop (RS-P6.1) must exist and sit
    /// behind the board art, which sits behind the squares.
    func testSceneLayeringBackdropBelowBoardBelowSquares() {
        let scene = BoardScene(size: CGSize(width: 1024, height: 1366))
        // Setting matchState renders with the default theme; setting the
        // theme re-renders (both paths go through the same private layout).
        scene.matchState = .finkelMatch(stake: 1, omens: [])
        scene.theme = RegionTheme(region: .egypt)

        let backdrops = scene.children.filter { $0.name == "tavernBackdrop" }
        XCTAssertEqual(backdrops.count, 1, "exactly one tavern backdrop")
        XCTAssertEqual(backdrops[0].zPosition, -20, accuracy: 0.001)

        let backgrounds = scene.children.filter { $0.name == "boardBackground" }
        XCTAssertEqual(backgrounds.count, 1, "exactly one board background")
        XCTAssertEqual(backgrounds[0].zPosition, -10, accuracy: 0.001)

        let squares = scene.children.filter { $0.name?.hasPrefix("square_") == true }
        XCTAssertEqual(squares.count, 14)
        for square in squares {
            XCTAssertGreaterThanOrEqual(
                square.zPosition, 0, "squares render above the art layers")
        }
    }

    /// Regression: the board rows were once offset by integer division
    /// (`(count-1) / 2` as an Int, then halved), which shifted every row
    /// two columns right — tiles ran off the scene at every size. All
    /// square nodes must lie inside the scene bounds after a render.
    func testBoardLayoutFitsTheSceneAtSeveralSizes() {
        let sizes: [CGSize] = [
            CGSize(width: 1024, height: 1366),  // the nominal scene size
            CGSize(width: 834, height: 1194),  // iPad Pro 11-inch points
            CGSize(width: 1032, height: 1376),  // iPad Pro 13-inch points
            CGSize(width: 375, height: 667),  // small phone
        ]
        for size in sizes {
            let scene = BoardScene(size: size)
            scene.matchState = .finkelMatch(stake: 1, omens: [])
            var checked = 0
            for row in scene.layoutSquares {
                for square in row {
                    let half = square.frame.width / 2
                    XCTAssertLessThanOrEqual(
                        square.frame.maxX, size.width / 2,
                        "square \(square.name ?? "?") exceeds the right edge at \(size)")
                    XCTAssertGreaterThanOrEqual(
                        square.frame.minX, -size.width / 2,
                        "square \(square.name ?? "?") exceeds the left edge at \(size)")
                    XCTAssertLessThanOrEqual(
                        square.frame.maxY, size.height / 2,
                        "square \(square.name ?? "?") exceeds the top edge at \(size)")
                    XCTAssertGreaterThanOrEqual(
                        square.frame.minY, -size.height / 2,
                        "square \(square.name ?? "?") exceeds the bottom edge at \(size)")
                    // Every row of squares must be centred: the row's mean
                    // column offset is zero.
                    checked += 1
                    _ = half
                }
            }
            XCTAssertEqual(checked, 14, "all 14 track squares must be laid out at \(size)")
            for (rowIndex, row) in scene.layoutSquares.enumerated() where row.count > 1 {
                let meanX = row.map { $0.position.x }.reduce(0, +) / CGFloat(row.count)
                XCTAssertEqual(
                    meanX, 0, accuracy: 1,
                    "row \(rowIndex) is not centred at \(size) (mean x \(meanX))")
            }
        }
    }

    /// Regression (P6 snapshot review): piece nodes must actually be in
    /// the scene graph. The pre-fix code guarded `addChild` with a check
    /// that was always true, so every piece stayed parentless and invisible
    /// on the board.
    func testPieceNodesAreInSceneGraph() {
        let scene = BoardScene(size: CGSize(width: 1024, height: 1366))
        var state = MatchState.finkelMatch(stake: 1, omens: [])
        scene.matchState = state

        // Put a piece on board square 3 and one borne off.
        state.pieces[0].position = 3
        state.pieces[1].position = -2
        scene.matchState = state

        let pieceNodes = scene.children.filter {
            $0.name?.hasPrefix("piece_") == true
        }
        XCTAssertEqual(
            pieceNodes.count, 13,
            "all non-borne-off pieces are in the scene graph")
        for node in pieceNodes {
            XCTAssertTrue(
                node.parent === scene, "piece \(node.name ?? "?") has a parent")
        }
        // The borne-off piece must not sit on a square.
        let names = Set(scene.children.compactMap { $0.name })
        XCTAssertFalse(names.contains("piece_player0_1"))
    }

    /// Regression (P6 snapshot review): SwiftUI presents the scene while
    /// the SKView's bounds are still zero, and `.resizeFill` zeroes the
    /// scene size. A render pass at a degenerate size must not wipe the
    /// existing geometry, and the scene must re-layout when it gains a
    /// real size.
    func testDegenerateSizeLayoutDoesNotWipeGeometry() {
        let scene = BoardScene(size: CGSize(width: 1024, height: 1366))
        scene.matchState = .finkelMatch(stake: 1, omens: [])
        let squaresBefore = scene.children.filter {
            $0.name?.hasPrefix("square_") == true
        }
        XCTAssertEqual(squaresBefore.count, 14)
        let widthBefore = squaresBefore.map { $0.frame.width }.max() ?? 0
        XCTAssertGreaterThan(widthBefore, 10, "initial layout has real squares")

        // The degenerate pass (zero-size scene): geometry must survive.
        scene.size = .zero
        scene.refreshLayout()
        let squaresAfter = scene.children.filter {
            $0.name?.hasPrefix("square_") == true
        }
        XCTAssertEqual(
            squaresAfter.count, 14, "a zero-size render must not wipe the layout")
        XCTAssertEqual(
            squaresAfter.map { $0.frame.width }.max() ?? 0, widthBefore,
            accuracy: 0.5, "squares keep their laid-out geometry")

        // Gaining a real size re-lays-out to fit the new size.
        scene.size = CGSize(width: 375, height: 667)
        scene.refreshLayout()
        let laid = scene.layoutSquares.flatMap { $0 }
        XCTAssertEqual(laid.count, 14, "all squares re-laid out at the new size")
        for square in laid {
            XCTAssertLessThanOrEqual(
                square.frame.maxX, 375 / 2 + 1,
                "square \(square.name ?? "?") exceeds the right edge")
        }
    }
}
