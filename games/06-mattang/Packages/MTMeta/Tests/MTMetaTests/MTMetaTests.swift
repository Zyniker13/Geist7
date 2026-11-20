import XCTest

@testable import MTMeta

final class MTMetaTests: XCTestCase {
    func testPackageCompiles() {
        XCTAssertEqual(MTMetaInfo.identifier, "MTMeta")
    }
}
