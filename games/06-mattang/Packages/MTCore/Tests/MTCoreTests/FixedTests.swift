// FixedTests.swift — Q32.32 known-answer tests.

import XCTest

@testable import MTCore

final class FixedTests: XCTestCase {
    func testRawLayout() {
        XCTAssertEqual(Fixed.zero.raw, 0)
        XCTAssertEqual(Fixed.one.raw, 1 << 32)
        XCTAssertEqual(Fixed.half.raw, 1 << 31)
        XCTAssertEqual(Fixed(2).raw, Int64(2) << 32)
        XCTAssertEqual(Fixed(0.5).raw, 1 << 31)
        XCTAssertEqual(Fixed(-3).raw, Int64(-3) << 32)
    }

    func testIntRoundTrip() {
        for v in [-5, -1, 0, 1, 7, 1234] {
            XCTAssertEqual(Fixed(v).intValue, v)
            XCTAssertEqual(Fixed(v).doubleValue, Double(v), accuracy: 1e-9)
        }
    }

    func testSaturatingIntInit() {
        // Int32 range clamp per Fixed.swift contract.
        XCTAssertEqual(Fixed(Int(Int32.max) + 100).intValue, Int(Int32.max))
        XCTAssertEqual(Fixed(Int(Int32.min) - 100).intValue, Int(Int32.min))
    }

    func testDoubleRounding() {
        // Nearest-representable rounding: 0.1 is not exact, error < 2^-33.
        XCTAssertEqual(Fixed(0.1).doubleValue, 0.1, accuracy: 1e-9)
        XCTAssertEqual(Fixed(0.25).raw, 1 << 30)
        // Huge inputs saturate instead of wrapping.
        XCTAssertEqual(Fixed(1e30).raw, Int64.max)
        XCTAssertEqual(Fixed(-1e30).raw, Int64.min)
    }

    func testAddSubtract() {
        XCTAssertEqual(Fixed(2) + Fixed(3), Fixed(5))
        XCTAssertEqual(Fixed(5) - Fixed(3), Fixed(2))
        XCTAssertEqual(Fixed(2) - Fixed(3), Fixed(-1))
        XCTAssertEqual(Fixed.half + Fixed.half, Fixed.one)
    }

    func testMultiplyKnownAnswers() {
        XCTAssertEqual(Fixed(2) * Fixed(3), Fixed(6))
        XCTAssertEqual(Fixed(0.5) * Fixed(0.5), Fixed(0.25))
        XCTAssertEqual(Fixed(1.5) * Fixed(1.5), Fixed(2.25))
        XCTAssertEqual(Fixed(-2) * Fixed(3), Fixed(-6))
        XCTAssertEqual(Fixed(-2) * Fixed(-3), Fixed(6))
    }

    func testMultiplyFractionalPrecision() {
        let product = Fixed(0.1) * Fixed(0.1)
        XCTAssertEqual(product.doubleValue, 0.01, accuracy: 1e-9)
    }

    func testDivideKnownAnswers() {
        // Q32.32 division: result.raw == trunc(lhs.raw << 32 / rhs.raw).
        XCTAssertEqual((Fixed(1) / Fixed(2)).raw, 1 << 31)
        XCTAssertEqual((Fixed(1) / Fixed(3)).raw, 1_431_655_765)  // floor(2^32/3)
        XCTAssertEqual((Fixed(3) / Fixed(4)).raw, 3_221_225_472)  // 0xC0000000
        XCTAssertEqual(Fixed(6) / Fixed(2), Fixed(3))
        XCTAssertEqual(Fixed(-7) / Fixed(2), Fixed(-3.5))
        XCTAssertEqual(Fixed(7) / Fixed(-2), Fixed(-3.5))
        XCTAssertEqual(Fixed(-7) / Fixed(-2), Fixed(3.5))
    }

    func testDivideRoundTripPrecision() {
        // (a/b)*b stays within one ulp-scale of a for in-range values.
        let a = Fixed(1)
        let b = Fixed(3)
        let product = (a / b) * b
        XCTAssertEqual(product.doubleValue, 1.0, accuracy: 1e-8)
    }

    func testNegate() {
        XCTAssertEqual(-Fixed(3), Fixed(-3))
        XCTAssertEqual(-(-Fixed(3)), Fixed(3))
        // Int64.min negation saturates to Int64.max rather than trapping.
        let mostNegative = Fixed(raw: Int64.min)
        XCTAssertEqual(-mostNegative, Fixed(raw: Int64.max))
    }

    func testComparisonAndCodable() throws {
        XCTAssertTrue(Fixed(0.25) < Fixed(0.5))
        XCTAssertTrue(Fixed(-1) < Fixed.zero)
        XCTAssertEqual(Fixed(1.5), Fixed(1.5))
        let data = try JSONEncoder().encode(Fixed(1.5))
        XCTAssertEqual(try JSONDecoder().decode(Fixed.self, from: data), Fixed(1.5))
    }

    func testLerp() {
        XCTAssertEqual(Fixed(0).lerp(to: Fixed(10), Fixed.half), Fixed(5))
        XCTAssertEqual(Fixed(0).lerp(to: Fixed(10), Fixed.zero), Fixed(0))
        XCTAssertEqual(Fixed(0).lerp(to: Fixed(10), Fixed.one), Fixed(10))
    }
}
