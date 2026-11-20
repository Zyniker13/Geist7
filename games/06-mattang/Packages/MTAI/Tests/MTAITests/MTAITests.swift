import XCTest

@testable import MTAI

final class MTAITests: XCTestCase {
    func testPackageCompiles() {
        XCTAssertEqual(MTAIInfo.identifier, "MTAI")
    }
}
