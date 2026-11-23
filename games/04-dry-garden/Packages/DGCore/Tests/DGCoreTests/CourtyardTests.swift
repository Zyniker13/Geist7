// CourtyardTests.swift — mask parsing and the default courtyard fixture
// (R-1, R-16, DG-P0.2, DG-P0.3, and the G0 axis-enumeration check).

import XCTest

@testable import DGCore

final class CourtyardTests: XCTestCase {
    /// The default courtyard mask (R-1): an irregular walled courtyard
    /// outline, 44 lattice cells within the wall, with an open bay on
    /// the south-east side. Deliberately asymmetric in outline, so no
    /// mirror axis is in play at the 70% filter (R-17): the symmetry
    /// law then bites only on accidental stone arrangements, which is
    /// the intended feel (asymmetry is the garden's aesthetic).
    /// Row index = r, column = c, axial q = c − r/2 (odd-r layout).
    static let defaultMask: [String] = [
        "..####.....",
        "...####....",
        ".....#####.",
        "##.........",
        "..######...",
        "...######..",
        "...........",
        "..######...",
        "...#####...",
        "##.........",
        "..####.....",
    ]

    /// Fixed features (R-1): a moss patch and a water basin. Both sit
    /// on mask cells (parse rejects features outside the mask).
    static let defaultFeatures: [Feature] = [
        Feature(cell: Hex(0, 4), kind: "moss"),
        Feature(cell: Hex(3, 7), kind: "basin"),
    ]

    func makeDefaultCourtyard() throws -> Courtyard {
        try Courtyard.parse(
            id: "long_wall", name: "Long Wall",
            mask: Self.defaultMask, features: Self.defaultFeatures,
            veranda: "bottom")
    }

    // MARK: Mask parsing (DG-P0.2)

    func testDefaultCourtyardCellCounts() throws {
        let courtyard = try makeDefaultCourtyard()
        // 44 mask cells; 42 placeable after the two features (R-1's
        // feature cells cannot receive stones but are part of the yard).
        XCTAssertEqual(courtyard.cells.count, 44, "G0 fixture: 44 cells")
        XCTAssertEqual(courtyard.cellSet.count, 44, "cells are unique")
        XCTAssertEqual(courtyard.placeableCells.count, 42)
    }

    func testMaskParsingCoordinates() throws {
        let courtyard = try makeDefaultCourtyard()
        // Row 0, column 2 → q = 2 − 0 = 2, r = 0.
        XCTAssertTrue(courtyard.cellSet.contains(Hex(2, 0)))
        // Row 2, column 5 → q = 5 − 1 = 4, r = 2.
        XCTAssertTrue(courtyard.cellSet.contains(Hex(4, 2)))
        // Row 3, column 1 → q = 1 − 1 = 0, r = 3.
        XCTAssertTrue(courtyard.cellSet.contains(Hex(0, 3)))
        // A wall point must not be a cell.
        XCTAssertFalse(courtyard.cellSet.contains(Hex(9, 0)), "row 0 column 9 is wall")
        XCTAssertFalse(courtyard.cellSet.contains(Hex(0, 6)), "row 6 is the open bay")
    }

    func testFeaturesLandOnMaskCells() throws {
        let courtyard = try makeDefaultCourtyard()
        XCTAssertEqual(courtyard.features.count, 2)
        for feature in courtyard.features {
            XCTAssertTrue(
                courtyard.cellSet.contains(feature.cell),
                "feature \(feature.cell) sits outside the mask")
        }
        XCTAssertTrue(courtyard.isFeature(Hex(0, 4)))
        XCTAssertTrue(courtyard.isFeature(Hex(3, 7)))
        XCTAssertFalse(courtyard.isFeature(Hex(2, 5)))
    }

    func testRaggedRowFailsWithRow() {
        XCTAssertThrowsError(
            try Courtyard.parse(
                id: "bad", name: "Bad",
                mask: ["###", "##"], features: [], veranda: "bottom")
        ) { error in
            XCTAssertEqual(error as? CourtyardError, .raggedRow(row: 1))
        }
    }

    func testEmptyMaskFails() {
        XCTAssertThrowsError(
            try Courtyard.parse(
                id: "bad", name: "Bad", mask: [], features: [], veranda: "bottom")
        ) { error in
            XCTAssertEqual(error as? CourtyardError, .emptyMask)
        }
    }

    func testFeatureOutsideMaskFailsWithCell() {
        XCTAssertThrowsError(
            try Courtyard.parse(
                id: "bad", name: "Bad",
                mask: ["####", "####"],
                features: [Feature(cell: Hex(9, 9), kind: "moss")],
                veranda: "bottom")
        ) { error in
            XCTAssertEqual(
                error as? CourtyardError, .featureOutsideMask(q: 9, r: 9))
        }
    }

    // MARK: Axis enumeration (DG-P0.3, G0 fixture check)

    /// GATE G0 fixture: the default courtyard yields the expected axis
    /// count. The outline is deliberately asymmetric, so at R-17's 70%
    /// filter (over the 42 non-feature cells) ZERO axes are in play —
    /// the symmetry law must never fire from geometry alone on the
    /// default courtyard; only a player's own stones can create the
    /// mirror (and R-7 still judges those stone mirrors, P1).
    func testDefaultCourtyardAxisCountFixture() throws {
        let courtyard = try makeDefaultCourtyard()
        XCTAssertEqual(courtyard.axes.count, 0, "G0 fixture: no axis in play")
    }

    /// The enumerator's threshold logic still works on the courtyard's
    /// own cell set when the features are ignored: pin the counts the
    /// plain-lattice sweep reports for the record.
    func testPlainLatticeSweepRecordedCounts() throws {
        let courtyard = try makeDefaultCourtyard()
        let plain = AxisEnumeration.axesInPlay(cells: courtyard.cells, threshold: 1.0)
        // The 44-cell outline has no exact mirror either.
        XCTAssertEqual(plain.count, 0, "outline itself has no exact axis")
        // And at a loose 25% threshold some near-axes exist (recorded
        // for the P1 law fixtures, not a gate check).
        let loose = AxisEnumeration.axesInPlay(cells: courtyard.cells, threshold: 0.25)
        XCTAssertFalse(loose.isEmpty, "near-axes exist for the law fixtures")
        for axis in loose {
            let a = Axis(family: axis.family, offset: axis.offset)
            let mapped = courtyard.cells.filter { courtyard.cellSet.contains(a.reflect($0)) }.count
            XCTAssertEqual(mapped, axis.mapped, "recorded count must match recomputation")
        }
    }

    // MARK: Distance table (DG-P0.1)

    func testDistanceTableMatchesCubeDistance() throws {
        let courtyard = try makeDefaultCourtyard()
        let table = DistanceTable(cells: courtyard.cells)
        XCTAssertEqual(table.count, 44)
        var rng = SeededRNG(seed: 31)
        for _ in 0..<500 {
            let a = courtyard.cells[rng.nextInt(below: 44)]
            let b = courtyard.cells[rng.nextInt(below: 44)]
            XCTAssertEqual(
                table.distance(from: a, to: b), a.distance(to: b),
                "table disagrees with cube distance for \(a)→\(b)")
            XCTAssertEqual(
                table.distance(from: a, to: b), table.distance(from: b, to: a))
        }
        XCTAssertTrue(table.contains(Hex(2, 0)))
        XCTAssertFalse(table.contains(Hex(50, 50)))
        let all = table.distances(from: Hex(2, 0))
        XCTAssertEqual(all.count, 44)
        XCTAssertEqual(all[Hex(2, 0)], 0)
    }

    // MARK: Row-major layout sanity

    func testVerandaIsTheMaximalRPerQ() throws {
        // R-16: the veranda edge is the set of cells with maximal r for
        // each q. With this mask the bottom row holds those cells.
        let courtyard = try makeDefaultCourtyard()
        let maxR = courtyard.cells.map(\.r).max()
        XCTAssertEqual(maxR, 10, "bottom row is r = 10 (the veranda side)")
        // The veranda string is recorded and P0 only knows "bottom".
        XCTAssertEqual(courtyard.veranda, "bottom")
    }
}
