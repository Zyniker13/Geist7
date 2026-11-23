// FixedTests.swift — Q32.32 known-answer and property tests.

import XCTest

@testable import DGCore

final class FixedTests: XCTestCase {
    func testConstants() {
        XCTAssertEqual(Fixed.zero.raw, 0)
        XCTAssertEqual(Fixed.one.raw, 1 << 32)
        XCTAssertEqual(Fixed.half.raw, 1 << 31)
        XCTAssertEqual(Fixed(2).intValue, 2)
    }

    func testKnownAnswerMultiplication() {
        // 1.5 * 2.25 = 3.375
        let a = Fixed(raw: 3 << 31)  // 1.5
        let b = Fixed(raw: 9 << 30)  // 2.25  (9 << 29 would be 1.125)
        XCTAssertEqual((a * b).doubleValue, 3.375, accuracy: 1e-9)
    }

    func testMultiplyNegativeOperands() {
        // Regression: signs must come from magnitudes, not bit patterns.
        let negTwo = Fixed(-2)
        let three = Fixed(3)
        XCTAssertEqual((negTwo * three).doubleValue, -6.0, accuracy: 1e-9)
        XCTAssertEqual((negTwo * negTwo).doubleValue, 4.0, accuracy: 1e-9)
        XCTAssertEqual((three * negTwo).doubleValue, -6.0, accuracy: 1e-9)
    }

    func testKnownAnswerDivision() {
        // 7 / 2 = 3.5
        let result = Fixed(7) / Fixed(2)
        XCTAssertEqual(result.doubleValue, 3.5, accuracy: 1e-9)
    }

    func testDivideNegativeOperands() {
        // Regression: signs must come from magnitudes, not bit patterns.
        let negTen = Fixed(-10)
        let four = Fixed(4)
        XCTAssertEqual((negTen / four).doubleValue, -2.5, accuracy: 1e-9)
        // 4 / −10 = −0.4 exactly; Q32.32 holds it (0.4 = 2/5 needs more
        // than 32 fraction bits in binary, so keep a coarse accuracy).
        XCTAssertEqual((four / negTen).doubleValue, -0.4, accuracy: 1e-6)
        XCTAssertEqual((negTen / negTen).doubleValue, 1.0, accuracy: 1e-9)
    }

    func testFractionalPrecision() {

        let quarter = Fixed(0.25)
        XCTAssertEqual(quarter.raw, 1 << 30)
        let sum = quarter + quarter + quarter + quarter
        XCTAssertEqual(sum.raw, Fixed.one.raw)
    }

    func testComparisonAndNegation() {
        let a = Fixed(3)
        let b = Fixed(5)
        XCTAssertTrue(a < b)
        XCTAssertEqual((-a).doubleValue, -3.0, accuracy: 1e-9)
        XCTAssertEqual((-(-a)).raw, a.raw)
    }

    func testLerp() {
        let from = Fixed(0)
        let to = Fixed(10)
        XCTAssertEqual(from.lerp(to: to, Fixed.half).doubleValue, 5.0, accuracy: 1e-9)
        XCTAssertEqual(from.lerp(to: to, Fixed.zero).doubleValue, 0.0, accuracy: 1e-9)
        XCTAssertEqual(from.lerp(to: to, Fixed.one).doubleValue, 10.0, accuracy: 1e-9)
    }

    func testDoubleRoundTrip() {
        for value in [-100.0, -0.5, 0.0, 0.25, 1.0, 123.456, 9999.9] {
            let f = Fixed(value)
            XCTAssertEqual(f.doubleValue, value, accuracy: 1e-6)
        }
    }

    func testArithmeticOperatorsChain() {
        let value = (Fixed(4) + Fixed(2) - Fixed(1)) * Fixed(3) / Fixed(5)
        XCTAssertEqual(value.doubleValue, 3.0, accuracy: 1e-9)
    }

    func testInPlaceOperators() {
        var value = Fixed(2)
        value += Fixed(3)
        XCTAssertEqual(value.doubleValue, 5.0, accuracy: 1e-9)
        value *= Fixed(2)
        XCTAssertEqual(value.doubleValue, 10.0, accuracy: 1e-9)
        value -= Fixed(4)
        XCTAssertEqual(value.doubleValue, 6.0, accuracy: 1e-9)
        value /= Fixed(4)
        XCTAssertEqual(value.doubleValue, 1.5, accuracy: 1e-9)
    }

    func testCodableRoundTrip() throws {
        let original = Fixed(123.456)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Fixed.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
