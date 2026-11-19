import Testing
@testable import RSPlatform

/// RS-P7.2b: number-key navigation on the Mac. Runs under `swift test` —
/// the macOS app-hosted unit runner cannot initialize test sessions on the
/// local build machine (see the S7.2 maintainer issue), so the key→move
/// resolution is exercised here and the view model keeps a thin glue layer.
@Suite("Mac piece-key navigation (RS-P7.2b)")
struct MacPieceKeyTests {

    @Test("keys 1–7 map to move indices 0–6")
    func keyOrdering() {
        #expect(MacPieceKey.moveIndex(forNumberKey: 1, legalMoveCount: 7) == 0)
        #expect(MacPieceKey.moveIndex(forNumberKey: 4, legalMoveCount: 7) == 3)
        #expect(MacPieceKey.moveIndex(forNumberKey: 7, legalMoveCount: 7) == 6)
    }

    @Test("keys outside 1–7 are rejected")
    func outOfRange() {
        #expect(MacPieceKey.moveIndex(forNumberKey: 0, legalMoveCount: 7) == nil)
        #expect(MacPieceKey.moveIndex(forNumberKey: 8, legalMoveCount: 7) == nil)
        #expect(MacPieceKey.moveIndex(forNumberKey: -1, legalMoveCount: 7) == nil)
    }

    @Test("keys past the legal-move count are rejected")
    func pastCount() {
        #expect(MacPieceKey.moveIndex(forNumberKey: 4, legalMoveCount: 3) == nil)
        #expect(MacPieceKey.moveIndex(forNumberKey: 2, legalMoveCount: 3) == 1)
    }

    @Test("no legal moves means no key applies")
    func emptyMoves() {
        #expect(MacPieceKey.moveIndex(forNumberKey: 1, legalMoveCount: 0) == nil)
    }
}
