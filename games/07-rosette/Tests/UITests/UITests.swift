import XCTest

final class UITests: XCTestCase {
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticText["Rosette"].exists)
    }
}
