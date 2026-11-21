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

    // MARK: SRC2.1 — the pending-advisor corner mark

    /// The match screen shows the "Pending advisor review" corner mark
    /// in DEBUG builds (every swell name and the canoe art are still
    /// pending). Runs only in the Debug configuration; the Release run
    /// skips it and instead asserts the mark is absent.
    func testPendingMarkPresentInDebug() throws {
        #if !DEBUG
            throw XCTSkip("debug-only check; runs in the Debug configuration")
        #else
            let app = XCUIApplication()
            app.launchArguments = ["-startMatch", "-seed", "7"]
            app.launch()

            // Confirm we are on the match screen (the controls bar).
            let place = app.buttons["Place"]
            XCTAssertTrue(place.waitForExistence(timeout: 10), "match controls visible")

            let mark = app.staticTexts["Pending advisor review"]
            XCTAssertTrue(
                mark.waitForExistence(timeout: 5),
                "corner mark present in the DEBUG build"
            )
        #endif
    }

    /// Release builds compile the corner mark out, so players never
    /// see it. Runs only in the Release configuration; the Debug run
    /// skips it and instead asserts the mark is present.
    func testPendingMarkAbsentInRelease() throws {
        #if DEBUG
            throw XCTSkip("release-only check; runs in the Release configuration")
        #else
            let app = XCUIApplication()
            app.launchArguments = ["-startMatch", "-seed", "7"]
            app.launch()

            // Confirm we are on the match screen (the controls bar).
            let place = app.buttons["Place"]
            XCTAssertTrue(place.waitForExistence(timeout: 10), "match controls visible")

            // Give any late-appearing element a moment, then assert the
            // mark is genuinely absent.
            Thread.sleep(forTimeInterval: 1)
            let mark = app.staticTexts["Pending advisor review"]
            XCTAssertFalse(
                mark.exists,
                "corner mark must be absent in the Release build"
            )
        #endif
    }

    // MARK: G2 check 1 — a full game vs Sailor completes

    /// Auto-pilot drives both sides of a match against the Sailor tier
    /// to completion; the results overlay (and its "Play again" button)
    /// appears when the match is over. Runs on iPad under `make test`
    /// and on Mac under `make test-mac` (the Mac automation half is
    /// SUBSTITUTED per issue #8 precedent).
    func testAutoPilotCompletesGameVsSailor() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-startMatch", "-seed", "7", "-autoPilot"]
        app.launch()

        // Confirm we are on the match screen (the controls bar is
        // always rendered, over or under the results overlay).
        let place = app.buttons["Place"]
        XCTAssertTrue(place.waitForExistence(timeout: 10), "match controls visible")

        // Auto-pilot plays both sides to completion; the results
        // overlay's "Play again" button appears only when the match is
        // over. A full Sailor game is a few dozen plies at the
        // auto-pilot pace, so allow generous time for the AI compute.
        let playAgain = app.buttons["Play again"]
        XCTAssertTrue(
            playAgain.waitForExistence(timeout: 120),
            "auto-pilot game vs Sailor completes and shows the results overlay"
        )
    }
}
