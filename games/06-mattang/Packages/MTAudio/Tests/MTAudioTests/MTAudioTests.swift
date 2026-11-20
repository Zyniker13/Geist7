import XCTest

@testable import MTAudio

final class MTAudioTests: XCTestCase {
    func testPackageCompiles() {
        XCTAssertEqual(MTAudioInfo.identifier, "MTAudio")
    }
}
