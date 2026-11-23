// AxisTests.swift — mirror-axis enumeration (R-17, DG-P0.3, G0 fixture).

import XCTest

@testable import DGCore

final class AxisTests: XCTestCase {
    // MARK: Reflection formula verification

    /// Every family's reflection is an exact involution: reflecting
    /// twice returns the original cell (verified exhaustively on a
    /// bounded region for all six families and many offsets).
    func testReflectionsAreInvolutions() {
        for family in 0...5 {
            for offset in -20...20 {
                let axis = Axis(family: family, offset: offset)
                for q in -12...12 {
                    for r in -12...12 {
                        let cell = Hex(q, r)
                        let image = axis.reflect(cell)
                        XCTAssertEqual(
                            axis.reflect(image), cell,
                            "family \(family) offset \(offset) not involutive at \(cell)")
                        // The image is always a lattice point (integer
                        // coordinates by construction).
                        _ = image.q
                        _ = image.r
                    }
                }
            }
        }
    }

    /// Family 1 (vertical) reflects east↔west: the point-mirror case a
    /// hand check can pin.
    func testVerticalFamilyKnownAnswers() {
        // Axis through (q + r = 7): (q, r) -> (7 − q − r, r)
        let axis = Axis(family: 1, offset: 7)
        XCTAssertEqual(axis.reflect(Hex(0, 0)), Hex(7, 0))
        XCTAssertEqual(axis.reflect(Hex(7, 0)), Hex(0, 0))
        XCTAssertEqual(axis.reflect(Hex(3, 1)), Hex(3, 1), "cells on the axis are fixed")
    }

    /// Family 0 (horizontal mirror across the r = k row): the reflection
    /// keeps the axial skew, so a north cell maps to a south cell with
    /// q shifted east by the row change (verified as an involution in
    /// testReflectionsAreInvolutions and against the design probe).
    func testHorizontalFamilyKnownAnswers() {
        let axis = Axis(family: 0, offset: 5)
        // (0,0): q+r−k = −5, 2k−r = 10 → (−5, 10).
        XCTAssertEqual(axis.reflect(Hex(0, 0)), Hex(-5, 10))
        // (10,10): 10+10−5 = 15, 10 → (15, 10)? No: 2k−r = 0 → (15, 0).
        XCTAssertEqual(axis.reflect(Hex(10, 10)), Hex(15, 0))
        // (9,4): 9+4−5 = 8, 10−4 = 6 → (8, 6).
        XCTAssertEqual(axis.reflect(Hex(9, 4)), Hex(8, 6))
        // Involutive: reflecting the image returns the original.
        XCTAssertEqual(axis.reflect(axis.reflect(Hex(0, 0))), Hex(0, 0))
    }

    // MARK: Enumeration properties

    /// The axis set does not depend on the order cells are listed in
    /// (INV-6's order-independence, applied to the axis sweep).
    func testEnumerationIsOrderIndependent() {
        var rng = SeededRNG(seed: 77)
        var cells: [Hex] = []
        for _ in 0..<40 {
            cells.append(Hex(rng.nextInt(below: 17) - 8, rng.nextInt(below: 17) - 8))
        }
        let set = Set(cells)
        let a = AxisEnumeration.axesInPlay(cells: cells).map { Axis(family: $0.family, offset: $0.offset) }
        let shuffled = Array(set).shuffled()
        let b = AxisEnumeration.axesInPlay(cells: shuffled).map { Axis(family: $0.family, offset: $0.offset) }
        XCTAssertEqual(a, b)
    }

    /// A rectangle of cells is symmetric about its own centre axes:
    /// families 0 and 1 must both appear (each with exactly one offset
    /// for the rectangle's bounding box).
    func testRectangleHasHorizontalAndVerticalAxes() {
        var cells: [Hex] = []
        for r in -3...3 {
            for q in -4...4 {
                cells.append(Hex(q, r))
            }
        }
        let axes = AxisEnumeration.axesInPlay(cells: cells).map { ($0.family, $0.offset) }
        let horizontal = axes.filter { $0.0 == 0 }
        let vertical = axes.filter { $0.0 == 1 }
        XCTAssertFalse(horizontal.isEmpty, "rectangle must have a horizontal axis")
        XCTAssertFalse(vertical.isEmpty, "rectangle must have a vertical axis")
        XCTAssertTrue(horizontal.contains { $0.1 == 0 }, "horizontal axis through centre")
        XCTAssertTrue(vertical.contains { $0.1 == 0 }, "vertical axis through centre")
    }

    /// A blob with no mirror symmetry at all yields no in-play axes at
    /// the 100% threshold. An earlier version of this test used EQUAL
    /// arms (5 east + 5 south) — but an equal-arm L IS symmetric across
    /// the q = r main diagonal (family 2, offset 0 swaps the arms), so
    /// the premise was wrong, not the enumerator. Arms of different
    /// lengths have no exact axis.
    func testAsymmetricBlobHasNoPerfectAxes() {
        // An L-shaped corner with unequal arms: 6 east, 4 south.
        var cells: [Hex] = []
        for q in 0...5 { cells.append(Hex(q, 0)) }
        for r in 1...4 { cells.append(Hex(0, r)) }
        let axes = AxisEnumeration.axesInPlay(cells: cells, threshold: 1.0)
        XCTAssertTrue(axes.isEmpty, "unequal-arm L should have no exact axis, got \(axes)")

        // Positive control: the equal-arm L has exactly the diagonal.
        var equal: [Hex] = []
        for q in 0...5 { equal.append(Hex(q, 0)) }
        for r in 1...5 { equal.append(Hex(0, r)) }
        let equalAxes = AxisEnumeration.axesInPlay(cells: equal, threshold: 1.0)
        XCTAssertTrue(
            equalAxes.contains { $0.family == 2 && $0.offset == 0 && $0.mapped == 11 },
            "equal-arm L is symmetric across q = r, got \(equalAxes)")
    }

    /// Reported mapped counts never exceed the cell count, and every
    /// reported axis meets the threshold exactly.
    func testMappedCountsRespectThreshold() {
        var cells: [Hex] = []
        for r in 0...6 {
            for q in 0...(6 - r) {
                cells.append(Hex(q, r))
            }
        }
        let axes = AxisEnumeration.axesInPlay(cells: cells, threshold: 0.5)
        for axis in axes {
            XCTAssertLessThanOrEqual(axis.mapped, cells.count)
            XCTAssertGreaterThanOrEqual(
                Double(axis.mapped), Double(cells.count) * 0.5 - 0.001)
        }
    }
}
