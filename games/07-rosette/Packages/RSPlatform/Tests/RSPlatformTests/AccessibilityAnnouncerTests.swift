// RSPlatform — AccessibilityAnnouncer tests (RS-P8.1).
//
// The message builders are pure; `post` is a platform hook and is not
// asserted on (it would require a running screen reader).

import XCTest
@testable import RSPlatform

final class AccessibilityAnnouncerTests: XCTestCase {

    func test_rollAnnouncementSingular() {
        XCTAssertEqual(
            AccessibilityAnnouncer.rollAnnouncement(
                value: 5, legalMoves: 1, oddsText: "Chance to capture next roll: 40%"),
            "Rolled 5. 1 legal move. Chance to capture next roll: 40%")
    }

    func test_rollAnnouncementPlural() {
        XCTAssertEqual(
            AccessibilityAnnouncer.rollAnnouncement(
                value: 3, legalMoves: 3, oddsText: "Win rate: 55%"),
            "Rolled 3. 3 legal moves. Win rate: 55%")
    }

    func test_rollAnnouncementNoMoves() {
        XCTAssertEqual(
            AccessibilityAnnouncer.rollAnnouncement(
                value: 4, legalMoves: 0, oddsText: "Win rate: 10%"),
            "Rolled 4. no legal moves. Win rate: 10%")
    }
}
