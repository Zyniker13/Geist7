// HexTests.swift — axial hex geometry (R-16, DG-P0.1).

import XCTest

@testable import DGCore

final class HexTests: XCTestCase {
    func testDistanceKnownAnswers() {
        // The axial metric: (|dq| + |dr| + |dq + dr|) / 2.
        XCTAssertEqual(Hex(0, 0).distance(to: Hex(3, 3)), 6)
        XCTAssertEqual(Hex(0, 0).distance(to: Hex(-1, -1)), 2)
        XCTAssertEqual(Hex(2, -1).distance(to: Hex(-2, 1)), 4)
        XCTAssertEqual(Hex(0, 0).distance(to: Hex(0, 0)), 0)
        XCTAssertEqual(Hex(5, 0).distance(to: Hex(-5, 0)), 10)
        // Straight lines: pure-r and pure-q walks are the shortest.
        XCTAssertEqual(Hex(0, 0).distance(to: Hex(0, 5)), 5)
        XCTAssertEqual(Hex(0, 0).distance(to: Hex(5, 0)), 5)
        // The two diagonal-step forms: +q−r steps are 1 apart each.
        XCTAssertEqual(Hex(0, 0).distance(to: Hex(3, -3)), 3)
    }

    func testDistanceSymmetricOnRandomPairs() {
        // DG-P0.1 acceptance: distance symmetric and triangle inequality
        // hold on 10,000 random pairs.
        var rng = SeededRNG(seed: 2026)
        for _ in 0..<10_000 {
            let a = Hex(rng.nextInt(below: 41) - 20, rng.nextInt(below: 41) - 20)
            let b = Hex(rng.nextInt(below: 41) - 20, rng.nextInt(below: 41) - 20)
            XCTAssertEqual(
                a.distance(to: b), b.distance(to: a),
                "asymmetric distance \(a) \(b)")
        }
    }

    func testTriangleInequalityOnRandomTriples() {
        var rng = SeededRNG(seed: 2027)
        for _ in 0..<10_000 {
            let a = Hex(rng.nextInt(below: 31) - 15, rng.nextInt(below: 31) - 15)
            let b = Hex(rng.nextInt(below: 31) - 15, rng.nextInt(below: 31) - 15)
            let c = Hex(rng.nextInt(below: 31) - 15, rng.nextInt(below: 31) - 15)
            XCTAssertLessThanOrEqual(
                a.distance(to: c), a.distance(to: b) + b.distance(to: c),
                "triangle inequality violated")
        }
    }

    func testNeighborsAtDistanceOne() {
        let origin = Hex(4, 4)
        for d in 0..<6 {
            XCTAssertEqual(origin.distance(to: origin.neighbor(d)), 1)
        }
    }

    func testDirectionVectorsCoverAllSixNeighbors() {
        let origin = Hex(0, 0)
        var unique = Set<Hex>()
        for d in 0..<6 {
            unique.insert(origin.neighbor(d))
        }
        XCTAssertEqual(unique.count, 6)
        // Direction names match the clockwise-from-east convention.
        XCTAssertEqual(Hex.directionNames.count, 6)
        XCTAssertEqual(Hex.directionNames[0], "E")
        XCTAssertEqual(Hex.directionNames[3], "W")
    }

    func testOppositeDirection() {
        for d in 0..<6 {
            XCTAssertEqual(Hex.opposite(d), (d + 3) % 6)
            // Walking out and back returns to the origin.
            let start = Hex(2, 3)
            XCTAssertEqual(start.neighbor(d).neighbor(Hex.opposite(d)), start)
        }
        // Out-of-range directions wrap (floored modulo).
        XCTAssertEqual(Hex.opposite(7), 4)
        XCTAssertEqual(Hex.opposite(-1), 2)
    }

    func testVectorArithmetic() {
        let a = Hex(1, 2)
        let b = Hex(3, -1)
        XCTAssertEqual(a + b, Hex(4, 1))
        XCTAssertEqual(a - b, Hex(-2, 3))
    }

    func testCodableRoundTrip() throws {
        let original = Hex(q: -3, r: 7)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Hex.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testHashableAndSendable() {
        let set: Set<Hex> = [Hex(0, 0), Hex(1, 0), Hex(0, 0)]
        XCTAssertEqual(set.count, 2)
    }
}
