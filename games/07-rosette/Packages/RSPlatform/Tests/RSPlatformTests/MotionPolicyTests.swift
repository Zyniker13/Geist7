// RSPlatform — MotionPolicy tests (RS-P8.1).

import XCTest
@testable import RSPlatform

final class MotionPolicyTests: XCTestCase {

    func test_diceTumbleEnabledInvertsReduceMotion() {
        XCTAssertTrue(MotionPolicy.diceTumbleEnabled(reduceMotion: false))
        XCTAssertFalse(MotionPolicy.diceTumbleEnabled(reduceMotion: true))
    }
}
