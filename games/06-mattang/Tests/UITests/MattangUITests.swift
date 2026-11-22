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

    // MARK: MT-P3.2 / ADR-0016 — the tutorial lesson-1 scripted test

    /// The tutorial opens on lesson 1 under `-scenario tutorial`; the
    /// lesson title, step text, and Next control render, and stepping
    /// through lesson 1 reaches its complete step. The scripted core
    /// side (the lesson steps replay legally through the reducer) is
    /// pinned by `testLessonScriptsReplayLegally` in MTContent; this
    /// test pins the rendered half (ADR-0016's G2 sharpened-check
    /// addendum).
    func testTutorialLessonOnePlays() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-scenario", "tutorial"]
        app.launch()

        let title = app.staticTexts["One swell"]
        XCTAssertTrue(title.waitForExistence(timeout: 10), "lesson 1 opens")
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label BEGINSWITH 'This chart carries one swell'")
            ).firstMatch.exists,
            "step text renders")
        let advance = app.buttons.matching(
            NSPredicate(format: "label IN {'Next', 'Done'}")
        ).firstMatch
        XCTAssertTrue(advance.waitForExistence(timeout: 5), "Next control renders")

        // Step through lesson 1's three steps (highlight, highlight,
        // complete): the third click (Done) closes the lesson and
        // advances to lesson 2.
        advance.tap()
        _ = advance.waitForExistence(timeout: 5)
        advance.tap()
        _ = advance.waitForExistence(timeout: 5)
        advance.tap()
        let progress = app.staticTexts["Lesson 2 of 5"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5), "lesson 2 follows")
    }

    // MARK: SRC3.1 — About the Tradition (MT-P3.2)

    /// The menu opens the About screen; all four claim keys render with
    /// their sourced text, plus the no-teaching-navigation statement
    /// and the advisor-review placeholder.
    func testAboutOpensAndShowsClaims() throws {
        let app = XCUIApplication()
        app.launch()

        let aboutButton = app.buttons["About the Tradition"]
        XCTAssertTrue(aboutButton.waitForExistence(timeout: 10), "menu shows About")
        aboutButton.tap()

        let screen = app.otherElements["aboutScreen"].firstMatch
        let exists = screen.waitForExistence(timeout: 5)
        XCTAssertTrue(
            exists || app.staticTexts["About the Tradition"].waitForExistence(timeout: 5),
            "About screen opens")
        XCTAssertTrue(app.staticTexts["C-1"].exists, "claim C-1 renders")
        XCTAssertTrue(app.staticTexts["C-2"].exists, "claim C-2 renders")
        XCTAssertTrue(app.staticTexts["C-3"].exists, "claim C-3 renders")
        XCTAssertTrue(app.staticTexts["C-4"].exists, "claim C-4 renders")
        XCTAssertTrue(
            app.staticTexts[
                "[Advisor-written introduction to the tradition — pending cultural review.]"
            ]
            .exists,
            "advisor placeholder renders")
        app.buttons["Back"].tap()
        XCTAssertTrue(
            app.buttons["Play"].waitForExistence(timeout: 5), "back returns to the menu")
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

/// Drives the S2.5 recording flow: a full auto-pilot match at the
/// live pace, ending on the results screen. The `simctl io
/// recordVideo` capture around this run becomes
/// `docs/media/slice.mp4`. No element queries run during the match
/// (the scene's AX tree is not safe to poll mid-render); the flow is
/// timed sleeps around the one safe interaction point. `-startMatch`
/// guarantees a fresh seed-7 match regardless of any saved record.
final class SliceRecordingUITests: XCTestCase {
    func testSliceRecordingFlow() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-startMatch", "-seed", "7", "-autoPilot", "-debugOverlay",
        ]
        app.launch()

        // Confirm the match screen is up (a safe pre-match query), then
        // hold while the auto-pilot match plays out (~50 s on seed 7)
        // and lands on the results overlay for the recording tail.
        let place = app.buttons["Place"]
        XCTAssertTrue(place.waitForExistence(timeout: 10), "match controls visible")
        sleep(56)
    }
}
