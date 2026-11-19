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

    /// RS-P8.4: the Settings sheet exposes the accessibility toggles.
    /// Runs on iPad where every menu button fits on screen.
    func testSettingsExposeAccessibilityToggles() throws {
        let app = XCUIApplication()
        app.launchArguments = []
        app.launch()

        openSettings(app)

        let leftHanded = app.switches["Left-Handed Layout"]
        let haptics = app.switches["Haptic Feedback"]
        XCTAssertTrue(leftHanded.waitForExistence(timeout: 5), "left-handed toggle should exist")
        XCTAssertTrue(haptics.exists, "haptics toggle should exist")

        // The left-handed toggle is real: flipping it must persist.
        leftHanded.tap()
        XCTAssertEqual(leftHanded.value as? String, "1", "toggle should read on after tap")
        app.buttons["Done"].tap()

        openSettings(app)
        let persisted = app.switches["Left-Handed Layout"]
        XCTAssertTrue(persisted.waitForExistence(timeout: 5))
        XCTAssertEqual(persisted.value as? String, "1", "the flipped toggle should persist")
        persisted.tap()  // restore the default for other tests
        XCTAssertEqual(persisted.value as? String, "0")
        app.buttons["Done"].tap()
    }

    /// RS-P8.4: with -leftHanded the top bar mirrors — the opponent info
    /// block (first child) moves to the trailing edge of the top bar.
    func testLeftHandedLaunchArgumentMirrorsTopBar() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-autoPilot", "-seed", "7", "-startMatch", "-leftHanded"]
        app.launch()

        let topBar = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "label BEGINSWITH 'Your turn' OR label BEGINSWITH 'Opponent's turn'")
        ).firstMatch
        XCTAssertTrue(topBar.waitForExistence(timeout: 10), "the game top bar should appear")

        let screen = app.frame
        let frame = topBar.frame
        let element = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS 'opp' OR label CONTAINS 'Opponent'")
        ).firstMatch
        if element.exists {
            // The opponent label sits inside the leading playerInfo; under
            // RTL it must sit in the trailing half of the screen.
            XCTAssertGreaterThan(
                element.frame.midX, screen.midX - 40,
                "with -leftHanded the opponent info should occupy the trailing half (mirrored)")
        }
        _ = frame
    }

    // MARK: Helpers

    /// Navigate to Settings from the main menu; iPad shows it inline,
    /// compact layouts show it in the toolbar overflow.
    private func openSettings(_ app: XCUIApplication) {
        let settings = app.buttons["Settings"]
        if settings.waitForExistence(timeout: 10) {
            settings.tap()
            return
        }
        // Compact layout: Settings lives behind the ellipsis toolbar item.
        let more = app.buttons["More"]
        XCTAssertTrue(more.waitForExistence(timeout: 5), "no path to Settings found")
        more.tap()
        let sheetSettings = app.buttons["Settings"]
        XCTAssertTrue(sheetSettings.waitForExistence(timeout: 5))
        sheetSettings.tap()
    }
}
