// HexTests.swift — axial hex, R-12 directions, face normals, and the
// 36-case reflection table (ROADMAP Appendix A.6).

import XCTest

@testable import MTCore

final class HexTests: XCTestCase {
    func testDirectionVectorsR12() {
        // 0–5 clockwise from east: E, SE, SW, W, NW, NE.
        XCTAssertEqual(
            Hex.directionVectors.map { "\($0.q),\($0.r)" },
            ["1,0", "0,1", "-1,1", "-1,0", "0,-1", "1,-1"])
        XCTAssertEqual(Hex.directionNames, ["E", "SE", "SW", "W", "NW", "NE"])
    }

    func testNeighbors() {
        let origin = Hex(0, 0)
        XCTAssertEqual(origin.neighbor(0), Hex(1, 0))
        XCTAssertEqual(origin.neighbor(1), Hex(0, 1))
        XCTAssertEqual(origin.neighbor(2), Hex(-1, 1))
        XCTAssertEqual(origin.neighbor(3), Hex(-1, 0))
        XCTAssertEqual(origin.neighbor(4), Hex(0, -1))
        XCTAssertEqual(origin.neighbor(5), Hex(1, -1))
        // Off-origin neighbor uses deltas relative to that cell.
        XCTAssertEqual(Hex(3, 2).neighbor(4), Hex(3, 1))
    }

    func testOppositeDirections() {
        for d in 0..<6 {
            let there = Hex(2, 2).neighbor(d)
            let back = there.neighbor((d + 3) % 6)
            XCTAssertEqual(back, Hex(2, 2), "d=\(d) round-trip failed")
            XCTAssertEqual(Hex.opposite(d), (d + 3) % 6)
        }
    }

    func testDistance() {
        XCTAssertEqual(Hex(0, 0).distance(to: Hex(0, 0)), 0)
        XCTAssertEqual(Hex(0, 0).distance(to: Hex(1, 0)), 1)
        XCTAssertEqual(Hex(0, 0).distance(to: Hex(0, 1)), 1)
        XCTAssertEqual(Hex(0, 0).distance(to: Hex(1, 1)), 2)
        XCTAssertEqual(Hex(0, 0).distance(to: Hex(3, -2)), 3)
        XCTAssertEqual(Hex(-2, 1).distance(to: Hex(1, -1)), 3)
        // Symmetry.
        XCTAssertEqual(Hex(1, 2).distance(to: Hex(4, 0)), Hex(4, 0).distance(to: Hex(1, 2)))
    }

    func testFaceStruck() {
        // The face a ray travelling in direction d crosses on entering
        // a cell is the one whose normal is (d+3) mod 6.
        for d in 0..<6 {
            XCTAssertEqual(Hex.faceStruck(by: d), (d + 3) % 6)
        }
        XCTAssertEqual(Hex.faceStruck(by: 0), 3)  // eastbound strikes the west face
        XCTAssertEqual(Hex.faceStruck(by: 3), 0)  // westbound strikes the east face
    }

    func testStraightEntryReverses() {
        // A ray hitting a face head-on (n = faceStruck(d)) bounces back.
        for d in 0..<6 {
            let n = Hex.faceStruck(by: d)
            XCTAssertEqual(Hex.reflect(incoming: d, striking: n), (d + 3) % 6)
            XCTAssertEqual(Hex.reflectVertex(incoming: d), (d + 3) % 6)
        }
    }

    func testClosedFormMatchesHandTableAll36() {
        for d in 0..<6 {
            for n in 0..<6 {
                XCTAssertEqual(
                    Hex.reflect(incoming: d, striking: n),
                    InteractionTable.reflect[d][n],
                    "closed form != hand table at d=\(d), n=\(n)")
            }
        }
    }

    func testHandTableLiteral() {
        // The literal A.6 table, asserted row by row.
        XCTAssertEqual(
            InteractionTable.reflect,
            [
                [3, 5, 1, 3, 5, 1],
                [2, 4, 0, 2, 4, 0],
                [1, 3, 5, 1, 3, 5],
                [0, 2, 4, 0, 2, 4],
                [5, 1, 3, 5, 1, 3],
                [4, 0, 2, 4, 0, 2],
            ])
    }

    func testKnownAnswerCases() {
        // Roadmap A.6 spot checks.
        XCTAssertEqual(InteractionTable.out(incoming: 0, striking: 0), 3)
        XCTAssertEqual(InteractionTable.out(incoming: 0, striking: 1), 5)
        XCTAssertEqual(InteractionTable.out(incoming: 2, striking: 4), 3)
        XCTAssertEqual(InteractionTable.out(incoming: 5, striking: 2), 2)
    }

    func testOutInRangeNeverTraps() {
        // All 36 in-range lookups must succeed (preconditions hold).
        for d in 0..<6 {
            for n in 0..<6 {
                _ = InteractionTable.out(incoming: d, striking: n)
            }
        }
    }

    func testReflectionInvolution() {
        // Reflecting a reflected ray off the same face restores d
        // (mirror law): f(f(d)) = d where f(d) = (2n - d + 3) mod 6.
        for n in 0..<6 {
            for d in 0..<6 {
                let once = Hex.reflect(incoming: d, striking: n)
                let twice = Hex.reflect(incoming: once, striking: n)
                XCTAssertEqual(twice, d, "involution failed at n=\(n), d=\(d)")
            }
        }
    }
}
