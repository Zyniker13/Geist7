import XCTest

@testable import RSCore
@testable import RSRender

final class RSRenderTests: XCTestCase {
    func testPlaceholder() {
        XCTAssertTrue(true)
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
}
