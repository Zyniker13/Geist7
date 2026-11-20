import XCTest

@testable import MTRender

final class MTRenderTests: XCTestCase {
    func testPackageCompiles() {
        XCTAssertEqual(MTRenderInfo.identifier, "MTRender")
    }
}
