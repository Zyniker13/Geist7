// AccessibilityUITests — RS-P8.1 accessibility checks.
//
// The app is launched in autoPilot mode with a fixed seed, so the match
// plays out deterministically. While the match is on screen the HUD must
// expose its accessibility labels (RS-P8.1): the top bar announces turn,
// dice, and score as a single element; the odds panel carries a
// "Win rate:" label; and the SpriteKit dice display carries a "Rolled N"
// label.

import XCTest

final class AccessibilityUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testHUDAccessibilityLabelsDuringMatch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-autoPilot", "-seed", "42", "-startMatch"]
        app.launch()

        let topBar = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "label BEGINSWITH 'Your turn' OR label BEGINSWITH 'Opponent's turn'")
        ).firstMatch
        let odds = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH 'Win rate:'")
        ).firstMatch
        let dice = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH 'Rolled '")
        ).firstMatch

        let victory = app.staticTexts["Victory!"]
        let defeat = app.staticTexts["Defeat"]

        // A full Finkel match at 0.05 s/ply typically runs ~10–30 s; allow a
        // generous ceiling (420 one-second polls) for slower test machines.
        var sawTopBar = false
        var sawOdds = false
        var sawDice = false
        var finished = false
        for _ in 0..<420 {
            if topBar.exists { sawTopBar = true }
            if odds.exists { sawOdds = true }
            if dice.exists { sawDice = true }
            if victory.exists || defeat.exists {
                finished = true
                break
            }
            sleep(1)
        }

        XCTAssertTrue(finished, "the auto-piloted match should reach the results screen")
        XCTAssertTrue(sawTopBar, "the top bar should announce turn, dice, and score (RS-P8.1)")
        XCTAssertTrue(sawOdds, "the odds panel should carry a 'Win rate:' label (RS-P8.1)")
        XCTAssertTrue(sawDice, "the dice display should carry a 'Rolled N' label (RS-P8.1)")
    }
}
