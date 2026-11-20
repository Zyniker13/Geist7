import XCTest

#if os(iOS)
/// Release screenshot capture for `docs/release/SCREENSHOTS.md`.
///
/// The in-match captures avoid AX queries entirely (issue #10: SpriteKit
/// AX snapshots starve): the match plays itself via `-autoPilot` with a
/// fixed seed, and the test screenshots on a timer. The static shots use
/// launch arguments to reach SwiftUI screens that are safe to drive.
final class RosetteSnapshotUITests: XCTestCase {
    override func tearDown() {
        XCUIDevice.shared.press(.home)
    }

    @MainActor
    func testCaptureMatchBurst() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-startMatch", "-seed", "7", "-autoPilot", "-aiDelay", "0.12",
        ]
        app.launch()
        for index in 1...40 {
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            shot.name = String(format: "match-%02d", index)
            shot.lifetime = .keepAlways
            add(shot)
            Thread.sleep(forTimeInterval: 0.8)
        }
    }

    @MainActor
    func testCaptureDailyShot() {
        let app = XCUIApplication()
        app.launchArguments = ["-daily"]
        app.launch()
        Thread.sleep(forTimeInterval: 3)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "daily"
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testCaptureCircuitShot() {
        let app = XCUIApplication()
        app.launch()
        Thread.sleep(forTimeInterval: 3)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "circuit"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
#endif
