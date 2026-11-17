// RSContent — Content loader tests.

import XCTest
@testable import RSContent
@testable import RSCore

final class RSContentTests: XCTestCase {
    var loader: ContentLoader = ContentLoader()

    func testLoadTaverns() throws {
        let taverns = try loader.loadTaverns()
        XCTAssertGreaterThan(taverns.count, 0, "Should load at least one tavern")
        for tavern in taverns {
            XCTAssertFalse(tavern.id.isEmpty, "Tavern ID must not be empty")
            XCTAssertFalse(tavern.name.isEmpty, "Tavern name must not be empty")
            XCTAssertGreaterThan(tavern.stake, 0, "Tavern stake must be positive")
        }
    }

    func testLoadOpponents() throws {
        let opponents = try loader.loadOpponents()
        XCTAssertGreaterThan(opponents.count, 0, "Should load at least one opponent")
        for opponent in opponents {
            XCTAssertFalse(opponent.id.isEmpty, "Opponent ID must not be empty")
            XCTAssertFalse(opponent.name.isEmpty, "Opponent name must not be empty")
        }
    }

    func testLoadOmens() throws {
        let omens = try loader.loadOmens()
        XCTAssertGreaterThan(omens.count, 0, "Should load at least one omen")
        for omen in omens {
            XCTAssertFalse(omen.id.isEmpty, "Omen ID must not be empty")
            XCTAssertGreaterThan(omen.cost, 0, "Omen cost must be positive")
        }
    }

    func testLoadRulesets() throws {
        let rulesets = try loader.loadRulesets()
        XCTAssertGreaterThan(rulesets.count, 0, "Should load at least one ruleset")
        for ruleset in rulesets {
            XCTAssertFalse(ruleset.id.isEmpty, "Ruleset ID must not be empty")
            XCTAssertGreaterThan(ruleset.boardSize, 0, "Board size must be positive")
            XCTAssertGreaterThan(ruleset.pieceCount, 0, "Piece count must be positive")
        }
    }

    func testLoadBalance() throws {
        let balance = try loader.loadBalance()
        XCTAssertFalse(balance.diceModifier.isEmpty, "Dice modifier must not be empty")
    }

    func testLoadTutorial() throws {
        let lessons = try loader.loadTutorial()
        XCTAssertGreaterThan(lessons.count, 0, "Should load at least one tutorial lesson")
    }

    func testTavernsCount12() throws {
        let taverns = try loader.loadTaverns()
        XCTAssertEqual(taverns.count, 12, "Should have exactly 12 taverns (3 regions × 4)")
    }

    func testOmensCount6() throws {
        let omens = try loader.loadOmens()
        XCTAssertEqual(omens.count, 6, "Should have exactly 6 omens")
    }

    func testRulesetsCount5() throws {
        let rulesets = try loader.loadRulesets()
        XCTAssertEqual(rulesets.count, 5, "Should have exactly 5 rulesets")
    }

    func testOpponentsCount12() throws {
        let opponents = try loader.loadOpponents()
        XCTAssertEqual(opponents.count, 12, "Should have exactly 12 opponents")
    }

    func testTutorialCount3() throws {
        let lessons = try loader.loadTutorial()
        XCTAssertEqual(lessons.count, 3, "Should have exactly 3 tutorial lessons")
    }

    func testTavernDefHasHistoryLabel() throws {
        let taverns = try loader.loadTaverns()
        for tavern in taverns {
            XCTAssertNotNil(tavern.label, "Tavern must have a history label")
        }
    }

    func testRulesetDefHasHistoryLabel() throws {
        let rulesets = try loader.loadRulesets()
        for ruleset in rulesets {
            XCTAssertNotNil(ruleset.label, "Ruleset must have a history label")
        }
    }
}
