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
