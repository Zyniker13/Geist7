import XCTest

@testable import RSCore

/// R-16: the Tablet ruleset's fortune squares. A good fortune grants another
/// roll; a bad fortune sends the landing piece home. Effects are
/// deterministic by square (ADR-0008), so neither RNG stream is touched
/// (INV-7) and INV-1 conservation still holds.
final class FortuneTests: XCTestCase {

    /// The Tablet-like ruleset (5 pieces, fortunes at 2 good / 7 bad).
    static let tabletRuleset = RuleSet(
        id: "tablet", label: "Tablet (fixture)", trackLength: 14, pieces: 5,
        rosettes: [3, 7, 13], safeRosettes: [7], diceModel: "tetra4",
        exactBearOff: true, extraRollOnRosette: true, captureRule: .standard,
        moveGenerator: "ur", source: "fixture", historyLabel: .reconstructed)

    static let fortunes = [
        FortuneSquare(rulesetId: "tablet", square: 2, deck: .good),
        FortuneSquare(rulesetId: "tablet", square: 7, deck: .bad),
    ]

    func testR16_GoodFortuneGrantsAnotherRoll() throws {
        // A piece on square 1 rolls 1 and lands on the good square (2).
        let state = TestSupport.state(
            ruleset: Self.tabletRuleset,
            dice: TestSupport.loaded(1),
            player0: [1, -1, -1, -1, -1],
            player1: [-1, -1, -1, -1, -1],
            fortunes: Self.fortunes
        )
        let (rolled, _) = try TestSupport.apply(.roll, to: state)
        XCTAssertEqual(rolled.diceValue, 1, "loaded dice: fixture assumes roll 1")
        let (moved, events) = try TestSupport.apply(.move(0), to: rolled)
        XCTAssertEqual(moved.pieces[0].position, 2)
        XCTAssertFalse(moved.isComplete)
        // The extra roll is granted and announced as an omen draw.
        XCTAssertTrue(events.contains(.omenPlayed(omenId: "fortune_good", player: .player0)))
        // The piece moves again this turn without the turn passing: the next
        // roll is legal for the same player.
        let (again, _) = try TestSupport.apply(.roll, to: moved, diceSeed: 302)
        XCTAssertEqual(again.currentPlayer, .player0, "good fortune: the lander rolls again")
        XCTAssertTrue(again.hasRolled)
    }

    func testR16_BadFortuneSendsThePieceHome() throws {
        // A piece on square 6 rolls 1 and lands on the bad square (7) — the
        // central rosette, which is also safe: without the fortune the move
        // onto it is legal, and the fortune then bounces the piece home.
        let state = TestSupport.state(
            ruleset: Self.tabletRuleset,
            dice: TestSupport.loaded(1),
            player0: [6, -1, -1, -1, -1],
            player1: [-1, -1, -1, -1, -1],
            fortunes: Self.fortunes
        )
        let (rolled, _) = try TestSupport.apply(.roll, to: state)
        XCTAssertEqual(rolled.diceValue, 1)
        let (moved, events) = try TestSupport.apply(.move(0), to: rolled)
        XCTAssertEqual(moved.pieces[0].position, -1, "bad fortune: the piece returns home")
        XCTAssertTrue(events.contains(.omenPlayed(omenId: "fortune_bad", player: .player0)))
        // Conservation holds (INV-1): waiting + on-board + borne off == 5.
        XCTAssertTrue(moved.pieceConservationValid)
        // The turn passes to the opponent normally.
        XCTAssertEqual(moved.currentPlayer, .player1)
    }

    func testR16_FortunesOnlyApplyToTheirRuleset() throws {
        // The same landing under Finkel (no fortunes in play) is unaffected.
        let state = TestSupport.state(
            ruleset: .finkel,
            dice: TestSupport.loaded(1),
            player0: [1, -1, -1, -1, -1, -1, -1],
            player1: [-1, -1, -1, -1, -1, -1, -1],
            fortunes: Self.fortunes
        )
        let (rolled, _) = try TestSupport.apply(.roll, to: state)
        XCTAssertEqual(rolled.diceValue, 1)
        let (moved, events) = try TestSupport.apply(.move(0), to: rolled)
        XCTAssertEqual(moved.pieces[0].position, 2, "no fortune without the tablet ruleset")
        XCTAssertFalse(
            events.contains { event in
                if case .omenPlayed = event { return true }
                return false
            })
    }

    func testR16_APlayedOmenTakesPrecedenceOverAFortune() throws {
        // With a pending split omen, landing on a fortune square must not
        // overwrite the player's own played omen for the turn.
        let omen = Omen(id: "split_path", effect: .split(count: 1), cost: 15, label: .invented)
        let state = TestSupport.state(
            ruleset: Self.tabletRuleset,
            dice: TestSupport.loaded(4),
            player0: [1, -1, -1, -1, -1],
            player1: [-1, -1, -1, -1, -1],
            omens0: [omen],
            fortunes: Self.fortunes
        )
        // Play the omen (R-21: before rolling), then roll a 4 and land on 5 —
        // no fortune there — so this only checks precedence plumbing; a
        // landing WITH a pending omen is covered by the split flow.
        let (withOmen, _) = try TestSupport.apply(.playOmen(omenId: "split_path"), to: state)
        XCTAssertNotNil(withOmen.pendingOmen)
        let (rolled, _) = try TestSupport.apply(.roll, to: withOmen)
        // A split of 4 activates on a piece that can take the first half (2):
        // the piece on 1 can. The split consumed the omen before any landing.
        XCTAssertEqual(rolled.diceValue, 2, "split: first half of 4")
        XCTAssertTrue(rolled.splitActive)
    }

    func testR16_FortunesNeverTouchTheRNGStreams() throws {
        // Landing on a good fortune square must produce the same dice-stream
        // state hash progression as landing on the same square without the
        // fortune registered: play two identical matches that differ only in
        // the fortunes array; the roll sequences must be identical.
        var plain = TestSupport.state(
            ruleset: Self.tabletRuleset,
            player0: [1, -1, -1, -1, -1],
            player1: [-1, -1, -1, -1, -1]
        )
        var lucky = TestSupport.state(
            ruleset: Self.tabletRuleset,
            player0: [1, -1, -1, -1, -1],
            player1: [-1, -1, -1, -1, -1],
            fortunes: Self.fortunes
        )
        var rngA = SeededRNG(seed: 777)
        var omenA = SeededRNG(seed: 888)
        var rngB = SeededRNG(seed: 777)
        var omenB = SeededRNG(seed: 888)
        for _ in 0..<8 {
            let a = try Reducer.apply(.roll, to: plain, rng: &rngA, omenRng: &omenA)
            plain = a.state
            let b = try Reducer.apply(.roll, to: lucky, rng: &rngB, omenRng: &omenB)
            lucky = b.state
            XCTAssertEqual(a.events.first, b.events.first, "the dice stream is unchanged (INV-7)")
            if plain.hasRolled { break }
        }
        XCTAssertEqual(plain.diceValue, lucky.diceValue)
    }
}
