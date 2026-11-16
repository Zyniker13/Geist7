import XCTest

final class UITests: XCTestCase {
    func testAppLaunchesToMainMenu() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Rosette"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Quick Match (vs AI)"].exists)
    }
}
