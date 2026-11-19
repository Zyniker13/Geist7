import XCTest

final class UITests: XCTestCase {
    func testAppLaunchesToMainMenu() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Rosette"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Single Match"].exists)
        XCTAssertTrue(app.buttons["Tavern Circuit"].exists)
    }
}

/// Drives the P3 slice flow for the S2.5 recording: menu → tavern circuit →
/// sit down → a few live turns against the AI.
final class SliceRecordingUITests: XCTestCase {
    func testCircuitSliceFlow() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Rosette"].waitForExistence(timeout: 10))

        app.buttons["Tavern Circuit"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Sit Down"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["Sit Down"].firstMatch.tap()

        // The match opens in a sheet; roll, let the AI answer, repeat.
        let roll = app.buttons["Roll Dice"].firstMatch
        XCTAssertTrue(roll.waitForExistence(timeout: 10))
        for _ in 0..<5 {
            if roll.exists {
                roll.tap()
            }
            // Wait for the turn to come back around (AI plays in between).
            _ = roll.waitForExistence(timeout: 12)
        }
        // Let the visible play continue for the recording tail.
        sleep(12)
    }
}

#if os(macOS)
/// RS-P7.2: on macOS, keys 1–7 pick a piece and apply a move (S7.2).
/// Drives a single match through the keyboard and asserts the turn cycles
/// (moves consumed, AI answers, our next turn arrives).
final class MacKeyboardUITests: XCTestCase {
    func testNumberKeysApplyMoves() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["Single Match"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["Single Match"].firstMatch.click()
        XCTAssertTrue(app.buttons["Start"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["Start"].firstMatch.click()

        let roll = app.buttons["Roll Dice"].firstMatch
        let dice = app.staticTexts
            .matching(NSPredicate(format: "label MATCHES 'Roll [0-9]+'"))
            .firstMatch

        var typedCycles = 0
        var completedAfterTyping = false
        for _ in 0..<6 {
            // Wait for our turn; the AI answers in between.
            if !roll.waitForExistence(timeout: 30) { break }
            roll.click()

            // Dice are on the table: keys pick pieces.
            if dice.waitForExistence(timeout: 8) {
                for _ in 0..<5 {
                    app.typeText("1")
                    usleep(350_000)
                    if roll.exists { break }
                }
                typedCycles += 1
                // The turn must cycle back: our keyboard moves were consumed
                // and the AI answered. A stalled keyboard leaves us holding
                // dice forever.
                if roll.waitForExistence(timeout: 60) {
                    completedAfterTyping = true
                    break
                }
            }
        }

        XCTAssertTrue(typedCycles >= 1, "keyboard input applied to at least one turn")
        XCTAssertTrue(completedAfterTyping, "turn cycled after keyboard moves")
    }
}
#endif
