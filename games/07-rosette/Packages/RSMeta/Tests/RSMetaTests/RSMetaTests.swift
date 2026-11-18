import Foundation
import RSCore
import XCTest

@testable import RSMeta

final class RSMetaTests: XCTestCase {
    // MARK: Daily match

    func testDailyDerivationIsDeterministicAcrossThirtyDays() {
        let days = Array(20_000...20_029)
        var seenSeeds = Set<UInt64>()
        for day in days {
            let date = Date(timeIntervalSince1970: Double(day) * 86_400)
            let a = DailyMatch.make(forDate: date)
            let b = DailyMatch.make(forDate: date)
            XCTAssertEqual(a.seed, b.seed, "same UTC day must give the same seed")
            XCTAssertEqual(a.diceSequence, b.diceSequence, "same UTC day must give the same dice")
            XCTAssertEqual(a.day, day)
            seenSeeds.insert(a.seed)
        }
        XCTAssertEqual(seenSeeds.count, days.count, "thirty days must give thirty distinct seeds")
    }

    func testDailyDiceSequenceStaysInsideTheTetra4Support() {
        let daily = DailyMatch.make(forDate: Date(timeIntervalSince1970: 20_000 * 86_400))
        let support = Set(DiceModel.tetra4.outcomes.map(\.value))
        for value in daily.diceSequence {
            XCTAssertTrue(support.contains(value), "value \(value) outside tetra4 support")
        }
        XCTAssertEqual(daily.diceSequence.count, 5000)
    }

    func testDailyMatchReplayIsIdentical() throws {
        let date = Date(timeIntervalSince1970: 20_042 * 86_400)
        let player = RosetteBot(personality: .careful, strength: 3)
        let a = try DailyMatch.play(forDate: date, player: player)
        let b = try DailyMatch.play(forDate: date, player: player)
        XCTAssertEqual(a.events, b.events, "same date and player must replay identically")
        XCTAssertNotNil(a.finalState.outcome)
    }

    func testDailyOpponentCyclesStrength() {
        XCTAssertEqual(DailyMatch.opponent(forDay: 0).strength, 2)
        XCTAssertEqual(DailyMatch.opponent(forDay: 1).strength, 3)
        XCTAssertEqual(DailyMatch.opponent(forDay: 2).strength, 4)
        XCTAssertEqual(DailyMatch.opponent(forDay: 3).strength, 2)
    }

    // MARK: MatchResult

    func testMatchResultFromRecordAggregatesEvents() throws {
        let record = try BotMatch.play(
            seed: 7,
            ruleset: .finkel,
            dice: .tetra4,
            stake: 3,
            bot0: RosetteBot(personality: .careful, strength: 3),
            bot1: RosetteBot(personality: .greedy, strength: 3)
        )
        let p0 = MatchResult.from(record: record, perspective: .player0)
        let p1 = MatchResult.from(record: record, perspective: .player1)
        let totalRosettes = record.events.count(where: {
            if case .rosetteLanded = $0 { return true }
            return false
        })
        XCTAssertEqual(p0.rosettesLanded + p1.rosettesLanded, totalRosettes)
        XCTAssertEqual(p0.won, !p1.won, "exactly one seat wins")
        XCTAssertEqual(p0.stake, 3)
        XCTAssertEqual(p0.cubeValue, record.finalState.cube.value)
        XCTAssertEqual(p0.plies, record.finalState.outcome?.plies ?? -1)
    }

    // MARK: PlayerStats

    func testStatsWinLossStreaksAndNetStake() {
        var stats = PlayerStats()
        let win = MatchResult(
            won: true, gammon: false, cubeValue: 2, stake: 4, plies: 100,
            rosettesLanded: 2, piecesCaptured: 1, piecesCapturedByOpponent: 0,
            piecesBorneOff: 14, omensPlayed: [], doublesOffered: 1
        )
        let loss = MatchResult(
            won: false, gammon: false, cubeValue: 1, stake: 4, plies: 90,
            rosettesLanded: 0, piecesCaptured: 0, piecesCapturedByOpponent: 2,
            piecesBorneOff: 0, omensPlayed: [], doublesOffered: 0
        )
        stats.record(win)
        stats.record(win)
        stats.record(loss)
        stats.record(win)
        XCTAssertEqual(stats.matches, 4)
        XCTAssertEqual(stats.wins, 3)
        XCTAssertEqual(stats.losses, 1)
        XCTAssertEqual(stats.winStreak, 1, "a loss resets the streak")
        XCTAssertEqual(stats.bestWinStreak, 2)
        // +8 +8 -4 +8 = 20
        XCTAssertEqual(stats.netStake, 20)
        // Three wins: 3 doubles, 3 x 2 rosettes, 3 captures.
        XCTAssertEqual(stats.doublesOffered, 3)
        XCTAssertEqual(stats.rosettesLanded, 6)
        XCTAssertEqual(stats.piecesCaptured, 3)
    }

    func testStatsGammonDoublesTheStake() {
        var stats = PlayerStats()
        stats.record(MatchResult(
            won: true, gammon: true, cubeValue: 2, stake: 4, plies: 80,
            rosettesLanded: 0, piecesCaptured: 0, piecesCapturedByOpponent: 0,
            piecesBorneOff: 14, omensPlayed: [], doublesOffered: 0
        ))
        stats.record(MatchResult(
            won: false, gammon: true, cubeValue: 1, stake: 4, plies: 80,
            rosettesLanded: 0, piecesCaptured: 0, piecesCapturedByOpponent: 0,
            piecesBorneOff: 0, omensPlayed: [], doublesOffered: 0
        ))
        XCTAssertEqual(stats.gammonsWon, 1)
        XCTAssertEqual(stats.gammonsLost, 1)
        // +16 (4*2*2) - 8 (4*1*2) = 8
        XCTAssertEqual(stats.netStake, 8)
    }

    func testStatsHighCubeWins() {
        var stats = PlayerStats()
        stats.record(MatchResult(
            won: true, gammon: false, cubeValue: 8, stake: 2, plies: 100,
            rosettesLanded: 0, piecesCaptured: 0, piecesCapturedByOpponent: 0,
            piecesBorneOff: 14, omensPlayed: [], doublesOffered: 0
        ))
        stats.record(MatchResult(
            won: true, gammon: false, cubeValue: 4, stake: 2, plies: 100,
            rosettesLanded: 0, piecesCaptured: 0, piecesCapturedByOpponent: 0,
            piecesBorneOff: 14, omensPlayed: [], doublesOffered: 0
        ))
        XCTAssertEqual(stats.highCubeWins, 1, "only cube 8+ counts")
    }

    func testStatsOmenKindsUseTheResolver() {
        var stats = PlayerStats()
        let kinds: [String: String] = [
            "omen_a": "reroll", "omen_b": "reroll", "omen_c": "unsafeRosettes"
        ]
        stats.record(
            MatchResult(
                won: true, gammon: false, cubeValue: 1, stake: 2, plies: 100,
                rosettesLanded: 0, piecesCaptured: 0, piecesCapturedByOpponent: 0,
                piecesBorneOff: 14, omensPlayed: ["omen_a", "omen_b", "omen_c"],
                doublesOffered: 0
            ),
            omenKind: { kinds[$0] }
        )
        XCTAssertEqual(stats.omensPlayed, 3)
        XCTAssertEqual(stats.omenKinds, Set(["reroll", "unsafeRosettes"]))
    }

    func testStatsDailyStreakFollowsConsecutiveDays() {
        var stats = PlayerStats()
        func daily(_ day: Int) -> MatchResult {
            MatchResult(
                won: true, gammon: false, cubeValue: 1, stake: 2, plies: 100,
                rosettesLanded: 0, piecesCaptured: 0, piecesCapturedByOpponent: 0,
                piecesBorneOff: 14, omensPlayed: [], doublesOffered: 0,
                isDaily: true, dailyDay: day
            )
        }
        stats.record(daily(100))
        stats.record(daily(101))
        stats.record(daily(102))
        XCTAssertEqual(stats.dailyStreak, 3)
        // Same day again: no double count.
        stats.record(daily(102))
        XCTAssertEqual(stats.dailyDays.count, 3)
        XCTAssertEqual(stats.dailyStreak, 3)
        // Skip a day: streak restarts.
        stats.record(daily(105))
        XCTAssertEqual(stats.dailyStreak, 1)
        XCTAssertEqual(stats.bestDailyStreak, 3)
        XCTAssertEqual(stats.dailyMatches, 5)
    }

    func testStatsCircuitCompletions() {
        var stats = PlayerStats()
        stats.recordCircuitCompletion(purse: 60)
        stats.recordCircuitCompletion(purse: 120)
        stats.recordCircuitCompletion(purse: 90)
        XCTAssertEqual(stats.circuitCompletions, 3)
        XCTAssertEqual(stats.bestCircuitPurse, 120)
    }

    // MARK: Achievements

    func testCatalogHasExactlyTwentyUniqueAchievements() {
        XCTAssertEqual(AchievementCatalog.count, 20)
        XCTAssertEqual(Set(AchievementCatalog.all.map(\.id)).count, 20, "ids must be unique")
        for achievement in AchievementCatalog.all {
            XCTAssertFalse(achievement.name.isEmpty)
            XCTAssertFalse(achievement.description.isEmpty)
            XCTAssertFalse(achievement.icon.isEmpty)
        }
    }

    func testAchievementsUnlockOnFirstMatchAndFirstWin() {
        var stats = PlayerStats()
        var state = AchievementState()
        let result = MatchResult(
            won: true, gammon: false, cubeValue: 1, stake: 2, plies: 100,
            rosettesLanded: 1, piecesCaptured: 0, piecesCapturedByOpponent: 0,
            piecesBorneOff: 14, omensPlayed: [], doublesOffered: 0
        )
        stats.record(result)
        let newly = state.evaluate(stats: stats, result: result, day: 100)
        XCTAssertTrue(newly.contains("first-match"))
        XCTAssertTrue(newly.contains("first-win"))
        XCTAssertTrue(newly.contains("rosette-first"))
        XCTAssertTrue(newly.contains("bear-off"))
        XCTAssertEqual(state.unlockedDays["first-win"], 100)
        // A second evaluation unlocks nothing new.
        let again = state.evaluate(stats: stats, result: result, day: 100)
        XCTAssertTrue(again.isEmpty)
    }

    func testAchievementWinStreaks() {
        var stats = PlayerStats()
        var state = AchievementState()
        let win = MatchResult(
            won: true, gammon: false, cubeValue: 1, stake: 2, plies: 100,
            rosettesLanded: 0, piecesCaptured: 0, piecesCapturedByOpponent: 0,
            piecesBorneOff: 14, omensPlayed: [], doublesOffered: 0
        )
        for _ in 0..<3 {
            stats.record(win)
            state.evaluate(stats: stats, result: win)
        }
        XCTAssertTrue(state.isUnlocked("streak-3"))
        XCTAssertFalse(state.isUnlocked("streak-5"))
        for _ in 0..<2 {
            stats.record(win)
            state.evaluate(stats: stats, result: win)
        }
        XCTAssertTrue(state.isUnlocked("streak-5"))
    }

    func testAchievementOmenCollectorNeedsAllThreeKinds() {
        var stats = PlayerStats()
        var state = AchievementState()
        let kinds: [String: String] = [
            "omen_a": "reroll", "omen_b": "reroll", "omen_c": "unsafeRosettes"
        ]
        let result = MatchResult(
            won: true, gammon: false, cubeValue: 1, stake: 2, plies: 100,
            rosettesLanded: 0, piecesCaptured: 0, piecesCapturedByOpponent: 0,
            piecesBorneOff: 14, omensPlayed: ["omen_a", "omen_b", "omen_c"],
            doublesOffered: 0
        )
        stats.record(result, omenKind: { kinds[$0] })
        state.evaluate(stats: stats, result: result)
        XCTAssertTrue(state.isUnlocked("omen-first"))
        XCTAssertFalse(state.isUnlocked("omen-collector"), "two kinds is not all three")
        let third = MatchResult(
            won: true, gammon: false, cubeValue: 1, stake: 2, plies: 100,
            rosettesLanded: 0, piecesCaptured: 0, piecesCapturedByOpponent: 0,
            piecesBorneOff: 14, omensPlayed: ["omen_d"], doublesOffered: 0
        )
        var kinds2 = kinds
        kinds2["omen_d"] = "extraRosette"
        stats.record(third, omenKind: { kinds2[$0] })
        state.evaluate(stats: stats, result: third)
        XCTAssertTrue(state.isUnlocked("omen-collector"))
    }

    func testAchievementCubeChampionCountsHighCubeWins() {
        var stats = PlayerStats()
        var state = AchievementState()
        let high = MatchResult(
            won: true, gammon: false, cubeValue: 8, stake: 2, plies: 100,
            rosettesLanded: 0, piecesCaptured: 0, piecesCapturedByOpponent: 0,
            piecesBorneOff: 14, omensPlayed: [], doublesOffered: 0
        )
        for _ in 0..<4 {
            stats.record(high)
            state.evaluate(stats: stats, result: high)
        }
        XCTAssertFalse(state.isUnlocked("cube-master"))
        stats.record(high)
        state.evaluate(stats: stats, result: high)
        XCTAssertTrue(state.isUnlocked("cube-master"))
    }

    func testAchievementDoubleDownAndGammon() {
        var stats = PlayerStats()
        var state = AchievementState()
        let doubleWin = MatchResult(
            won: true, gammon: false, cubeValue: 4, stake: 2, plies: 100,
            rosettesLanded: 0, piecesCaptured: 0, piecesCapturedByOpponent: 0,
            piecesBorneOff: 14, omensPlayed: [], doublesOffered: 1
        )
        stats.record(doubleWin)
        state.evaluate(stats: stats, result: doubleWin)
        XCTAssertTrue(state.isUnlocked("double-down"))
        let gammonWin = MatchResult(
            won: true, gammon: true, cubeValue: 1, stake: 2, plies: 80,
            rosettesLanded: 0, piecesCaptured: 0, piecesCapturedByOpponent: 0,
            piecesBorneOff: 14, omensPlayed: [], doublesOffered: 0
        )
        stats.record(gammonWin)
        state.evaluate(stats: stats, result: gammonWin)
        XCTAssertTrue(state.isUnlocked("gammon"))
    }

    func testAchievementComeback() {
        var stats = PlayerStats()
        var state = AchievementState()
        let comeback = MatchResult(
            won: true, gammon: false, cubeValue: 1, stake: 2, plies: 150,
            rosettesLanded: 0, piecesCaptured: 0, piecesCapturedByOpponent: 3,
            piecesBorneOff: 14, omensPlayed: [], doublesOffered: 0
        )
        stats.record(comeback)
        state.evaluate(stats: stats, result: comeback)
        XCTAssertTrue(state.isUnlocked("comeback"))
    }

    func testAchievementDailyStreaks() {
        var stats = PlayerStats()
        var state = AchievementState()
        func daily(_ day: Int) -> MatchResult {
            MatchResult(
                won: true, gammon: false, cubeValue: 1, stake: 2, plies: 100,
                rosettesLanded: 0, piecesCaptured: 0, piecesCapturedByOpponent: 0,
                piecesBorneOff: 14, omensPlayed: [], doublesOffered: 0,
                isDaily: true, dailyDay: day
            )
        }
        for day in [100, 101, 102] {
            let r = daily(day)
            stats.record(r)
            state.evaluate(stats: stats, result: r, day: day)
        }
        XCTAssertTrue(state.isUnlocked("daily-first"))
        XCTAssertTrue(state.isUnlocked("daily-streak-3"))
        XCTAssertFalse(state.isUnlocked("daily-streak-7"))
    }

    func testAchievementCircuitAndVeteran() {
        var stats = PlayerStats()
        var state = AchievementState()
        stats.recordCircuitCompletion(purse: 120)
        state.evaluate(stats: stats, result: nil)
        XCTAssertTrue(state.isUnlocked("circuit-first"))
        XCTAssertTrue(state.isUnlocked("circuit-rich"))
        let loss = MatchResult(
            won: false, gammon: false, cubeValue: 1, stake: 2, plies: 100,
            rosettesLanded: 0, piecesCaptured: 0, piecesCapturedByOpponent: 0,
            piecesBorneOff: 0, omensPlayed: [], doublesOffered: 0
        )
        for _ in 0..<50 {
            stats.record(loss)
            state.evaluate(stats: stats, result: loss)
        }
        XCTAssertTrue(state.isUnlocked("veteran"))
    }

    func testAchievementOmenChampionCountsTwentyFive() {
        var stats = PlayerStats()
        var state = AchievementState()
        let withOmen = MatchResult(
            won: true, gammon: false, cubeValue: 1, stake: 2, plies: 100,
            rosettesLanded: 0, piecesCaptured: 0, piecesCapturedByOpponent: 0,
            piecesBorneOff: 14, omensPlayed: ["omen_a"], doublesOffered: 0
        )
        for _ in 0..<24 {
            stats.record(withOmen)
            state.evaluate(stats: stats, result: withOmen)
        }
        XCTAssertFalse(state.isUnlocked("omen-master"))
        stats.record(withOmen)
        state.evaluate(stats: stats, result: withOmen)
        XCTAssertTrue(state.isUnlocked("omen-master"))
    }

    // MARK: Leaderboard

    func testLeaderboardCapsAtTenPerKind() {
        var board = LocalLeaderboard()
        for i in 0..<12 {
            board.submit(name: "alice\(i)", score: i, kind: .dailyWins, day: 100 + i)
        }
        let top = board.top(.dailyWins)
        XCTAssertEqual(top.count, 10)
        XCTAssertEqual(top.first?.score, 11)
        // Scores 0 and 1 fell off.
        XCTAssertFalse(top.contains { $0.score <= 1 })
    }

    func testLeaderboardKeepsKindsSeparate() {
        var board = LocalLeaderboard()
        for i in 0..<12 {
            board.submit(name: "alice\(i)", score: i, kind: .dailyWins, day: 100)
            board.submit(name: "bob\(i)", score: i, kind: .circuitPurse, day: 100)
        }
        XCTAssertEqual(board.top(.dailyWins).count, 10)
        XCTAssertEqual(board.top(.circuitPurse).count, 10)
        XCTAssertEqual(board.entries.count, 20)
    }

    func testLeaderboardTiesBreakToTheEarlierDay() {
        var board = LocalLeaderboard()
        board.submit(name: "late", score: 50, kind: .dailyWins, day: 200)
        board.submit(name: "early", score: 50, kind: .dailyWins, day: 100)
        board.submit(name: "best", score: 60, kind: .dailyWins, day: 300)
        let top = board.top(.dailyWins)
        XCTAssertEqual(top.map(\.name), ["best", "early", "late"])
    }

    // MARK: MetaStore

    private func tempDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("rs-meta-tests-\(getpid())", isDirectory: true)
    }

    func testMetaStoreRoundTrips() throws {
        let dir = tempDirectory()
        try? FileManager.default.removeItem(at: dir)
        let store = MetaStore(directory: dir)
        var stats = PlayerStats()
        stats.record(MatchResult(
            won: true, gammon: false, cubeValue: 2, stake: 4, plies: 100,
            rosettesLanded: 1, piecesCaptured: 0, piecesCapturedByOpponent: 0,
            piecesBorneOff: 14, omensPlayed: [], doublesOffered: 0
        ))
        var state = AchievementState()
        state.evaluate(stats: stats, result: nil)
        var board = LocalLeaderboard()
        board.submit(name: "alice", score: 7, kind: .dailyWins, day: 100)

        try store.saveStats(stats)
        try store.saveAchievements(state)
        try store.saveLeaderboard(board, .dailyWins)

        let loadedStats = store.loadStats()
        let loadedState = store.loadAchievements()
        let loadedBoard = store.loadLeaderboard(.dailyWins)
        XCTAssertEqual(loadedStats, stats)
        XCTAssertEqual(loadedState, state)
        XCTAssertEqual(loadedBoard, board)
    }

    func testMetaStoreMissingFilesFallBackToDefaults() throws {
        let dir = tempDirectory().appendingPathComponent("empty", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        let store = MetaStore(directory: dir)
        XCTAssertEqual(store.loadStats(), PlayerStats())
        XCTAssertEqual(store.loadAchievements(), AchievementState())
        XCTAssertEqual(store.loadLeaderboard(.circuitPurse), LocalLeaderboard())
    }

    func testMetaStoreCorruptFileFallsBackToDefaults() throws {
        let dir = tempDirectory().appendingPathComponent("corrupt", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: dir.appendingPathComponent("stats.json"))
        let store = MetaStore(directory: dir)
        XCTAssertEqual(store.loadStats(), PlayerStats())
    }
}
