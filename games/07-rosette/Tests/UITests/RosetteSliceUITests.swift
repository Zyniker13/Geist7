// RosetteSliceUITests — G2 vertical-slice checks.
//
// The app is launched in autoPilot mode: both sides play the simple
// heuristic AI with fast timers and a fixed seed, so the match plays out
// deterministically to the results screen. The test asserts the slice's
// contract: a full Finkel match completes, and a double is offered AND
// accepted along the way (the cube reads ×2).

import XCTest

final class RosetteSliceUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAutoPilotMatchCompletesWithAcceptedDouble() throws {
        let app = XCUIApplication()
        // -startMatch opens a single match straight from launch (the menu's
        // quick-match entry became "Single Match" behind a config sheet in
        // P3; the slice test wants the match itself, not the sheet flow).
        app.launchArguments = ["-autoPilot", "-showFPS", "-seed", "42", "-startMatch"]
        app.launch()

        // The auto-piloted match must reach the results overlay, and the
        // doubling cube must reach ×2 (offer accepted) before it ends.
        let cubeDoubled = app.staticTexts["Cube ×2"]
        let victory = app.staticTexts["Victory!"]
        let defeat = app.staticTexts["Defeat"]

        // A full Finkel match at 0.05 s/ply typically runs ~10–30 s; allow a
        // generous ceiling (420 one-second polls) for slower test machines.
        var sawDoubledCube = false
        var finished = false
        for _ in 0..<420 {
            if cubeDoubled.exists { sawDoubledCube = true }
            if victory.exists || defeat.exists {
                finished = true
                break
            }
            sleep(1)
        }

        XCTAssertTrue(finished, "the auto-piloted match should reach the results screen")
        XCTAssertTrue(sawDoubledCube, "a double should be offered and accepted (Cube ×2 shown)")

        // The results overlay must show the settlement line (score · cube · plies).
        let settlement = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Score:'")
        ).firstMatch
        XCTAssertTrue(settlement.exists, "results overlay should show the score line")
    }

    /// RS-P7: the daily match must settle through the completion callback —
    /// the result recorded, shown on the daily screen after leaving the
    /// results overlay. Regression for the G6 smoke finding: the old
    /// @Published onReceive raced `outcome` derivation and completed dailies
    /// were never recorded.
    func testDailyMatchAutoPilotRecordsResult() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-daily", "-autoPilot"]
        app.launch()

        // The auto-piloted daily plays out to the results overlay.
        let victory = app.staticTexts["Victory!"]
        let defeat = app.staticTexts["Defeat"]
        var finished = false
        for _ in 0..<420 {
            if victory.exists || defeat.exists {
                finished = true
                break
            }
            sleep(1)
        }
        XCTAssertTrue(finished, "the auto-piloted daily match should reach the results overlay")

        // Leave the overlay; the daily screen must show the recorded result.
        let done = app.buttons["Results Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "daily results overlay should offer Done")
        done.tap()

        let result = app.staticTexts["Daily Result"]
        XCTAssertTrue(result.waitForExistence(timeout: 10), "returning from the daily match should show today's result")
        let text = result.label
        XCTAssertTrue(
            text.contains("Won") || text.contains("Lost"),
            "daily result should show the outcome, got: \(text)")
    }
}
