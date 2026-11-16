import XCTest

@testable import RSCore

final class SeededRNGTests: XCTestCase {
  func testDeterministic() {
    var rng1 = SeededRNG(seed: 42)
    var rng2 = SeededRNG(seed: 42)
    for _ in 0..<100 {
      XCTAssertEqual(rng1.next(), rng2.next())
    }
  }

  func testDifferentSeedsDiverge() {
    var rng1 = SeededRNG(seed: 42)
    var rng2 = SeededRNG(seed: 43)
    XCTAssertNotEqual(rng1.next(), rng2.next())
  }

  func testNextLimit() {
    var rng = SeededRNG(seed: 12345)
    for _ in 0..<1000 {
      let val = rng.next(10)
      XCTAssert(val >= 0 && val < 10)
    }
  }

  func testReproducibility() {
    var rng = SeededRNG(seed: 999)
    let seq1 = (0..<50).map { _ in rng.next(100) }
    var rng2 = SeededRNG(seed: 999)
    let seq2 = (0..<50).map { _ in rng2.next(100) }
    XCTAssertEqual(seq1, seq2)
  }
}

final class FixedTests: XCTestCase {
  func testFromInt() {
    let fixed = Fixed(3, scale: 2)
    XCTAssertEqual(fixed.value, 300)
    XCTAssertEqual(fixed.scale, 2)
  }

  func testFromDouble() {
    let fixedDouble = Fixed(3.14, scale: 2)
    XCTAssertEqual(fixedDouble.value, 314)
    XCTAssertEqual(fixedDouble.scale, 2)
  }

  func testEquality() {
    let first = Fixed(1, scale: 2)
    let second = Fixed(1, scale: 2)
    let third = Fixed(1, scale: 3)
    XCTAssertEqual(first, second)
    XCTAssertNotEqual(first, third)
  }

  func testHashable() {
    let set: Set<Fixed> = [Fixed(1, scale: 2), Fixed(1, scale: 2), Fixed(2, scale: 2)]
    XCTAssertEqual(set.count, 2)
  }

  func testDoubleConversion() {
    let fixedVal = Fixed(Int64(314), scale: 2)
    XCTAssertEqual(fixedVal.doubleValue, 3.14, accuracy: 0.001)
  }
}
