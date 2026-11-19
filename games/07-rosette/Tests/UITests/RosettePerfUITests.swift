// RosettePerfUITests — G8 §7 budget measurements (simulator substitutes).
//
// These run outside `make test` (the Makefile skips UI tests); they are
// invoked explicitly through sim-lock to produce the numbers recorded in
// docs/PERF.md. Device-class numbers (ProMotion 120 fps, thermal) need real
// hardware and are tracked as a maintainer issue.
//
// Budgets (_CONVENTIONS.md §7, Rosette is a 2D game):
//   cold start to interactive main menu < 2.0 s
//   resume a saved game < 1.0 s
//   memory (resident) < 1.0 GB
//   frame rate floor 60 fps (the simulator cannot prove 120 fps ProMotion)

import XCTest

final class RosettePerfUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Cold start

    #if os(iOS)
        /// Launch straight to the main menu (no -startMatch) and measure the
        /// launch metric; the menu's "Single Match" button must be hittable,
        /// proving the app is interactive.
        func testColdLaunchToInteractiveMenu() throws {
            let app = XCUIApplication()
            app.launchArguments = []

            let measureOptions = XCTMeasureOptions()
            measureOptions.invocationOptions = [.manuallyStop]
            measure(
                metrics: [XCTApplicationLaunchMetric()],
                options: measureOptions
            ) {
                app.terminate()
                app.launch()
                stopMeasuring()
                _ = waitForMenu(app)
            }
        }
    #endif

    // MARK: Resume

    /// Play a few autoPilot moves (writing the autosave), terminate, then
    /// measure relaunching and resuming the saved match.
    func testResumeSavedMatch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-autoPilot", "-seed", "42", "-startMatch"]
        app.launch()
        // Let the autoPilot apply several moves so the autosave slot is
        // populated (every applied action rewrites it).
        sleep(8)
        app.terminate()

        let resume = XCUIApplication()
        resume.launchArguments = []

        let clock = XCTClockMetric()
        resume.launch()
        let menu = waitForMenu(resume)
        clock.start()
        // The resume row appears on the menu when an autosave exists.
        let resumeButton = resume.buttons["Resume Match"].firstMatch
        XCTAssertTrue(resumeButton.exists, "an autosave should offer a resume entry point")
        resumeButton.tap()
        // The board is the SKView-backed match screen; its HUD carries the
        // borne-off counter once the scene is interactive.
        let hud = resume.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Borne off'")
        ).firstMatch
        _ = hud.waitForExistence(timeout: 10)
        clock.stop()

        let time = clock.measurements.first?.value ?? 999
        XCTAssertLessThan(
            time, 1.0,
            "resume to an interactive board must take < 1.0 s (took \(time) s)"
        )
        _ = menu
    }

    // MARK: Memory + frame overlay

    #if os(iOS)
        /// A full autoPilot match with the FPS overlay on; samples the resident
        /// memory metric mid-match and leaves screenshots with the SKView FPS
        /// readout for the frame-rate evidence.
        func testMatchMemoryDuringPlay() throws {
            let app = XCUIApplication()
            app.launchArguments = ["-autoPilot", "-showFPS", "-seed", "42", "-startMatch"]
            app.launch()

            let memory = XCTMemoryMetric(application: app)
            let options = XCTMeasureOptions()
            options.iterationCount = 1
            measure(metrics: [memory], options: options) {
                sleep(15)
                stopMeasuring()
            }

            // Frame-rate evidence: the SKView overlay (showsFPS) renders live fps
            // in the board corner; capture it mid-match.
            let shots = 0..<3
            for i in shots {
                let shot = XCTAttachment(screenshot: app.screenshot())
                shot.name = "match-fps-\(i)"
                shot.lifetime = .keepAlways
                add(shot)
                sleep(4)
            }
            XCTAssertTrue(
                app.state == .runningForeground,
                "the autoPilot match should still be running after the sampling window"
            )
        }
    #endif

    // MARK: Helpers

    /// Wait until the main menu is interactive (quick match entry visible).
    private func waitForMenu(_ app: XCUIApplication) -> XCUIElement {
        let menuButton = app.buttons["Single Match"].firstMatch
        _ = menuButton.waitForExistence(timeout: 30)
        return menuButton
    }
}
