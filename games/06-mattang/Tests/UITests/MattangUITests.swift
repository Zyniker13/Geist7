// MattangUITests.swift — P0 smoke UI tests: app launches to the
// placeholder menu on iPad-class simulators.

import XCTest

final class MattangUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPlaceholderMenuLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        let title = app.staticTexts["Mattang"]
        XCTAssertTrue(title.waitForExistence(timeout: 10), "title visible")
        XCTAssertTrue(
            app.staticTexts["Swell-reading abstract strategy"].exists,
            "subtitle present"
        )
    }

    func testDebugOverlayVisibleWithLaunchFlag() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-debugOverlay", "-seed", "42"]
        app.launch()

        XCTAssertTrue(
            app.staticTexts["seed 42"].waitForExistence(timeout: 10),
            "debug overlay shows the seed line"
        )
        XCTAssertTrue(
            app.staticTexts["tick 0"].exists,
            "debug overlay shows the tick line"
        )
        let hashLine = app.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH 'hash'"))
            .firstMatch
        XCTAssertTrue(hashLine.exists, "debug overlay shows a state hash")
    }
}
