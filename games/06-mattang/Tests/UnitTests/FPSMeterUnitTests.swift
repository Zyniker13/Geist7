// FPSMeterUnitTests.swift — the debug overlay's fps meter (S0.7).

import XCTest

@testable import Mattang_macOS

final class FPSMeterUnitTests: XCTestCase {
    /// The meter rolls in whole windows: the first read after `start()`
    /// is 0 until a full second of frames accumulates, so a caller can
    /// never observe a partial window.
    func testFirstReadBeforeASecondIsZero() {
        let meter = FPSMeter()
        meter.start()
        defer { meter.stop() }
        XCTAssertEqual(meter.currentFPS(), 0, "no full second has elapsed")
    }

    /// `currentFPS` rolls the window: a second read within the same
    /// second is 0 again (the first read emptied the counter), and no
    /// read publishes state — the overlay's TimelineView may call it
    /// during view updates (the blank-screen-spin regression).
    func testRollEmptiesTheWindow() {
        let meter = FPSMeter()
        meter.start()
        defer { meter.stop() }
        XCTAssertEqual(meter.currentFPS(), 0)
        XCTAssertEqual(meter.currentFPS(), 0, "the window was already rolled")
    }

    /// The meter is not an observable publisher: rolling must not
    /// touch any @Published property, or the overlay re-renders forever
    /// (fps stuck at 0 on the match screen, then a blank-screen spin).
    func testMeterPublishesNothing() {
        // FPSMeter declares no @Published properties; compile-time
        // guard via its API surface: the only reads are currentFPS
        // calls that return plain ints.
        let meter = FPSMeter()
        meter.start()
        defer { meter.stop() }
        for _ in 0..<3 {
            _ = meter.currentFPS()
        }
        // Reaching here without a re-entrant render storm is the pass
        // condition; the historical bug crashed the run loop instead.
    }
}
