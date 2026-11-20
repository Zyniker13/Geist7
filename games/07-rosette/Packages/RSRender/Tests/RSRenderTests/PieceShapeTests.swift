// RSRender — PieceShape tests (RS-P8.1: color-blind accessibility).

import CoreGraphics
import RSCore
import XCTest
@testable import RSRender

final class PieceShapeTests: XCTestCase {

    func test_shapesDistinguishOwners() {
        // Player 0 = circle, player 1 = diamond: the shape carries the
        // ownership information that color alone would carry.
        XCTAssertEqual(PieceShape.forOwner(.player0), .circle)
        XCTAssertEqual(PieceShape.forOwner(.player1), .diamond)
    }

    func test_pathsAreGeometricallyDistinct() {
        let circle = PieceShape.circle.cgPath(radius: 10)
        let diamond = PieceShape.diamond.cgPath(radius: 10)
        // (7, 7) is inside the circle (49 + 49 < 100) but outside the
        // diamond (|7| + |7| > 10), so the two shapes are not merely
        // different colors of the same silhouette.
        let probe = CGPoint(x: 7, y: 7)
        XCTAssertTrue(circle.contains(probe))
        XCTAssertFalse(diamond.contains(probe))
    }

    func test_pathsAreCenteredAndBounded() {
        for shape in [PieceShape.circle, PieceShape.diamond] {
            let box = shape.cgPath(radius: 10).boundingBoxOfPath
            XCTAssertEqual(box.midX, 0, accuracy: 0.01)
            XCTAssertEqual(box.midY, 0, accuracy: 0.01)
            XCTAssertEqual(box.width, 20, accuracy: 0.01)
            XCTAssertEqual(box.height, 20, accuracy: 0.01)
        }
    }
}
