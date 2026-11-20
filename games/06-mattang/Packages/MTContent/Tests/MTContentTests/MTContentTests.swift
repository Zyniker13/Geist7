import XCTest

@testable import MTContent

final class MTContentTests: XCTestCase {
    func testPackageCompiles() {
        XCTAssertEqual(MTContentInfo.identifier, "MTContent")
    }

    /// Every glossary entry ships as "pending" until the Marshallese
    /// cultural advisor approves it; the manifest mirrors that.
    func testAllGlossaryEntriesPending() throws {
        let url = Bundle.module.url(
            forResource: "glossary", withExtension: "json",
            subdirectory: "Content"
        )
        let data = try Data(contentsOf: XCTUnwrap(url))
        let doc = try JSONDecoder().decode(GlossaryDoc.self, from: data)
        XCTAssertFalse(doc.entries.isEmpty)
        XCTAssertTrue(doc.entries.allSatisfy { $0.status == "pending" })
    }
}

struct GlossaryDoc: Codable {
    var schemaVersion: Int
    var game: String
    var language: String
    var entries: [Entry]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case game, language, entries
    }

    struct Entry: Codable {
        var key: String
        var term: String
        var gloss: String
        var status: String
        var source: String
    }
}
