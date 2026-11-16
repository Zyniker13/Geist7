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
        app.launchArguments = ["-autoPilot", "-showFPS", "-seed", "42"]
        app.launch()

        // Main menu: start the quick match.
        let quickMatch = app.buttons["Quick Match (vs AI)"]
        XCTAssertTrue(quickMatch.waitForExistence(timeout: 15), "main menu should show Quick Match")
        quickMatch.tap()

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
}
