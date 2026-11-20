import XCTest

@testable import MTPlatform

final class MTPlatformTests: XCTestCase {
    func testPackageCompiles() {
        XCTAssertEqual(MTPlatformInfo.identifier, "MTPlatform")
    }
}
