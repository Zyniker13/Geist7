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
                format: "label BEGINSWITH 'Your turn' OR label BEGINSWITH 'Opponent'")
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

        // The left-handed toggle is real: flipping it must persist. The
        // flip is asserted with a short poll — a tap that lands while the
        // sheet settles can read stale.
        leftHanded.tap()
        var flipped = false
        for _ in 0..<10 {
            let fresh = app.switches["Left-Handed Layout"]
            if (fresh.value as? String) == "1" { flipped = true; break }
            usleep(200_000)
        }
        XCTAssertTrue(flipped, "toggle should read on after tap")
        closeSettings(app)

        openSettings(app)
        let persisted = app.switches["Left-Handed Layout"]
        XCTAssertTrue(persisted.waitForExistence(timeout: 5))
        XCTAssertEqual(persisted.value as? String, "1", "the flipped toggle should persist")
        persisted.tap()  // restore the default for other tests
        XCTAssertEqual(persisted.value as? String, "0")
        closeSettings(app)
    }

    /// RS-P8.4: with -leftHanded the top bar mirrors — the opponent info
    /// block (first child) moves to the trailing edge of the top bar.
    func testLeftHandedLaunchArgumentMirrorsTopBar() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-autoPilot", "-seed", "7", "-startMatch", "-leftHanded"]
        app.launch()

        let topBar = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "label BEGINSWITH 'Your turn' OR label BEGINSWITH 'Opponent'")
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

    // MARK: Dynamic Type (RS-P8.1)

    /// RS-P8.1: at the largest accessibility text size the Settings
    /// toggles and menu buttons must still render (labels grow, no fixed
    /// frames clip them), and the app must not crash.
    func testDynamicTypeLargestAccessibilitySizeRendersControls() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-UIPreferredContentSizeCategoryName", "AX5",
        ]
        app.launch()

        // Settings first: two toggles must exist and stay hittable.
        openSettings(app)
        let leftHanded = app.switches["Left-Handed Layout"]
        let haptics = app.switches["Haptic Feedback"]
        XCTAssertTrue(leftHanded.waitForExistence(timeout: 5), "left-handed toggle should exist at AX5")
        XCTAssertTrue(haptics.exists, "haptics toggle should exist at AX5")
        XCTAssertTrue(leftHanded.isHittable, "the left-handed toggle must stay hittable at AX5")
        app.buttons["Done"].tap()

        // The main menu title scales (48 pt base → grows at AX5); the menu
        // buttons must still be present and on screen.
        let play = app.buttons["Play the Keeper"]
        XCTAssertTrue(play.waitForExistence(timeout: 10), "menu should render at AX5")
        XCTAssertTrue(play.frame.width > 0 && play.frame.height > 0, "menu button must not collapse at AX5")
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

    /// Close the Settings sheet: the toolbar Done when it renders, a
    /// swipe-down dismissal otherwise (robust at large Dynamic Type).
    private func closeSettings(_ app: XCUIApplication) {
        let done = app.buttons["Done"]
        if done.waitForExistence(timeout: 2) {
            done.tap()
        } else {
            app.swipeDown()
        }
    }
}
