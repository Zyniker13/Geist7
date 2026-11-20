// Rosette — unit tests for the handedness layout decisions (RS-P8.4)
// and the supporting launch argument.

import XCTest

@testable import Rosette_macOS

final class GameViewLayoutTests: XCTestCase {
    func testDefaultLayoutIsLeftToRight() {
        XCTAssertEqual(
            GameViewLayout.layoutDirection(leftHanded: false),
            .leftToRight)
    }

    func testLeftHandedLayoutMirrorsRightToLeft() {
        XCTAssertEqual(
            GameViewLayout.layoutDirection(leftHanded: true),
            .rightToLeft)
    }

    func testLeftHandedLaunchArgumentForcesMirroredLayout() {
        XCTAssertTrue(LaunchArguments.parse(["-leftHanded"]).leftHanded)
        XCTAssertFalse(LaunchArguments.parse([]).leftHanded)
    }

    func testLeftHandedKeyIsStable() {
        // The key is shared between the Settings toggle (@AppStorage) and
        // the game view; renaming it would silently reset preferences.
        XCTAssertEqual(GameViewLayout.leftHandedKey, "layout.leftHanded")
    }
}
