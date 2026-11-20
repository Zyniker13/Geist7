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

    /// `-snapshotPly 40` stages the board ~20 plies deep before the first
    /// frame renders, so the burst captures mid-game (not opening) positions;
    /// `-aiDelay 0.5` keeps the match evolving at a pace the ~30 s burst
    /// window cannot run past a mid-match state.
    @MainActor
    func testCaptureMatchBurst() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-startMatch", "-seed", "7", "-autoPilot", "-aiDelay", "0.5",
            "-snapshotPly", "40",
        ]
        app.launch()
        for index in 1...18 {
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            shot.name = String(format: "match-%02d", index)
            shot.lifetime = .keepAlways
            add(shot)
            Thread.sleep(forTimeInterval: 1.6)
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

    /// The menu tap was starved in earlier runs (issue #10), leaving a
    /// main-menu screenshot named "circuit"; `-circuit` pushes the tavern
    /// circuit directly on appear.
    @MainActor
    func testCaptureCircuitShot() {
        let app = XCUIApplication()
        app.launchArguments = ["-circuit"]
        app.launch()
        Thread.sleep(forTimeInterval: 3)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "circuit"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
#endif
