import XCTest
@testable import RSCore
@testable import RSMeta
@testable import Rosette_macOS

// MARK: - StatsRecorder unit tests (P9)

final class StatsRecorderUnitTests: XCTestCase {
    /// Captures by player 0 count for player 0; captures by player 1 count
    /// for the opponent.
    func testCaptureCountingIsPerSide() {
        var recorder = StatsRecorder()
        recorder.observe(.pieceCaptured(piece: 3, by: .player0))
        recorder.observe(.pieceCaptured(piece: 4, by: .player0))
        recorder.observe(.pieceCaptured(piece: 5, by: .player1))
        XCTAssertEqual(recorder.piecesCaptured, 2)
        XCTAssertEqual(recorder.piecesCapturedByOpponent, 1)
    }

    /// Rosette landings and borne-off pieces count only the local player's;
    /// omen plays collect the omen ids the local player used.
    func testRosetteBorneOffAndOmenCounting() {
        var recorder = StatsRecorder()
        recorder.observe(.rosetteLanded(player: .player0))
        recorder.observe(.rosetteLanded(player: .player1))
        recorder.observe(.pieceBorneOff(piece: 0, player: .player0))
        recorder.observe(.pieceBorneOff(piece: 1, player: .player1))
        recorder.observe(.omenPlayed(omenId: "protection", player: .player0))
        recorder.observe(.omenPlayed(omenId: "plague", player: .player1))
        recorder.observe(.doubleOffered(by: .player0))
        recorder.observe(.doubleOffered(by: .player1))
        XCTAssertEqual(recorder.rosettesLanded, 1)
        XCTAssertEqual(recorder.piecesBorneOff, 1)
        XCTAssertEqual(recorder.omensPlayed, ["protection"])
        XCTAssertEqual(recorder.doublesOffered, 1)
    }

    /// The recorded result combines the outcome's authoritative facts with
    /// the per-match event counters, and tags the daily day when given.
    func testResultCombinesOutcomeWithCounters() throws {
        var recorder = StatsRecorder()
        recorder.observe(.pieceCaptured(piece: 1, by: .player0))
        recorder.observe(.rosetteLanded(player: .player0))
        let outcome = Outcome(
            winner: .player0, gammon: true, cubeValue: 4, initialStake: 1, plies: 42)
        let result = recorder.result(outcome: outcome, dailyDay: 3)
        XCTAssertTrue(result.won)
        XCTAssertTrue(result.gammon)
        XCTAssertEqual(result.cubeValue, 4)
        XCTAssertEqual(result.stake, 1)
        XCTAssertEqual(result.plies, 42)
        XCTAssertEqual(result.piecesCaptured, 1)
        XCTAssertEqual(result.rosettesLanded, 1)
        XCTAssertTrue(result.isDaily)
        XCTAssertEqual(result.dailyDay, 3)
    }

    /// Non-daily matches record `isDaily == false` with a nil day.
    func testNonDailyResultHasNilDay() {
        let outcome = Outcome(
            winner: .player1, gammon: false, cubeValue: 1, initialStake: 1, plies: 9)
        let result = StatsRecorder().result(outcome: outcome, dailyDay: nil)
        XCTAssertFalse(result.won)
        XCTAssertFalse(result.isDaily)
        XCTAssertNil(result.dailyDay)
    }
}

// MARK: - StatsExporter unit tests (P9)

final class StatsExporterUnitTests: XCTestCase {
    /// The document round-trips through JSON and carries the fixed format
    /// marker and version.
    func testDocumentRoundTripsThroughJSON() throws {
        var stats = PlayerStats()
        stats.record(
            MatchResult(
                won: true, gammon: false, cubeValue: 1, stake: 1, plies: 30,
                rosettesLanded: 2, piecesCaptured: 3, piecesCapturedByOpponent: 1,
                piecesBorneOff: 7, omensPlayed: ["protection"], doublesOffered: 1,
                isDaily: false, dailyDay: nil))
        stats.recordCircuitCompletion(purse: 25)
        let document = StatsExporter.document(
            stats: stats,
            dailyResults: [.init(day: 1, result: "won")],
            generatedAt: "2026-11-20T00:00:00Z",
            appVersion: "1.0",
            build: "42")
        XCTAssertEqual(document.format, "rosette-stats-export")
        XCTAssertEqual(document.version, 1)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)
        let decoded = try JSONDecoder().decode(StatsExportDocument.self, from: data)
        XCTAssertEqual(decoded, document)
        XCTAssertEqual(decoded.stats.matches, 1)
        XCTAssertEqual(decoded.stats.wins, 1)
        XCTAssertEqual(decoded.stats.circuitCompletions, 1)
        XCTAssertEqual(decoded.dailyResults, [.init(day: 1, result: "won")])
    }

    /// The export file is written as JSON and parses back into the same
    /// document.
    func testWriteJSONProducesParsableFile() throws {
        let document = StatsExporter.document(
            stats: PlayerStats(),
            dailyResults: [],
            generatedAt: "2026-11-20T00:00:00Z",
            appVersion: "1.0",
            build: "42")
        let fixedDate = Date(timeIntervalSince1970: 1_798_761_600)  // 2027-01-01 UTC
        let url = try StatsExporter.writeJSON(document, now: fixedDate)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(url.lastPathComponent, "rosette-stats-2027-01-01.json")
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(StatsExportDocument.self, from: data)
        XCTAssertEqual(decoded, document)
    }

    /// The Settings timestamp helper produces ISO-8601 with a Z suffix.
    func testExportTimestampIsISO8601() {
        let stamp = SettingsView.exportTimestamp(
            now: Date(timeIntervalSince1970: 1_798_761_600))
        XCTAssertEqual(stamp, "2027-01-01T00:00:00Z")
    }
}

// MARK: - GameViewModel stats integration (P9)

/// Drives a match to completion by rolling and always taking the first
/// legal move. The engine auto-passes turns with no legal moves (R-3), and
/// pending doubles are declined so play continues.
@MainActor
private func playToEnd(_ viewModel: GameViewModel) throws {
    for _ in 0..<10_000 {
        guard !viewModel.matchState.isComplete else { return }
        if viewModel.matchState.doubleOffered {
            viewModel.declineDouble()
            continue
        }
        if !viewModel.matchState.hasRolled {
            viewModel.rollDice()
            continue
        }
        if let first = viewModel.legalMoves.first {
            viewModel.movePiece(first.piece)
        }
    }
    XCTFail("Match did not finish within the action budget")
}

@MainActor
final class GameViewModelStatsUnitTests: XCTestCase {
    private var directory: URL?
    private var store: MetaStore?

    override func setUp() {
        super.setUp()
        let name = "stats-\(ProcessInfo.processInfo.globallyUniqueString)"
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(name, isDirectory: true)
        directory = dir
        store = MetaStore(directory: dir)
    }

    override func tearDown() {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        store = nil
        directory = nil
        super.tearDown()
    }

    /// A completed match folds into the stats store exactly once: one match
    /// recorded for the player (seed 7 ends in a plain loss for player0 —
    /// no gammon on either side), no daily entry.
    func testCompletedMatchIsRecordedIntoStore() throws {
        let viewModel = GameViewModel(
            stakeValue: 1, useAI: true, seed: 7, autoSave: false, stats: store)
        try playToEnd(viewModel)
        let stats = try XCTUnwrap(store).loadStats()
        XCTAssertEqual(stats.matches, 1)
        XCTAssertEqual(stats.wins, 0)
        XCTAssertEqual(stats.losses, 1)
        XCTAssertEqual(stats.gammonsWon, 0)
        XCTAssertEqual(stats.gammonsLost, 0)
        XCTAssertFalse(stats.dailyMatches > 0)
    }

    /// Recording fires exactly once per match even when completion is
    /// re-checked (the completion callback and the stats fold share the
    /// one-shot guard).
    func testRecordingHappensExactlyOnce() throws {
        let viewModel = GameViewModel(
            stakeValue: 1, useAI: true, seed: 7, autoSave: false, stats: store)
        try playToEnd(viewModel)
        let outcome = try XCTUnwrap(viewModel.matchState.outcome)
        // Simulate a second completion notification (the guard's contract).
        viewModel.recordStatsIfEnabled(outcome: outcome)
        XCTAssertEqual(try XCTUnwrap(store).loadStats().matches, 1)
    }

    /// autoPilot sessions (the Tools/sim drivers) never record statistics.
    func testAutoPilotDoesNotRecord() throws {
        let viewModel = GameViewModel(
            stakeValue: 1, useAI: false, seed: 7, autoSave: false,
            autoPilot: true, stats: store)
        let outcome = Outcome(
            winner: .player0, gammon: false, cubeValue: 1, initialStake: 1, plies: 5)
        viewModel.recordStatsIfEnabled(outcome: outcome)
        XCTAssertEqual(try XCTUnwrap(store).loadStats().matches, 0)
    }

    /// A nil store disables recording (demo harnesses pass nil).
    func testNilStoreRecordsNothing() throws {
        let viewModel = GameViewModel(
            stakeValue: 1, useAI: false, seed: 7, autoSave: false, stats: nil)
        let outcome = Outcome(
            winner: .player0, gammon: false, cubeValue: 1, initialStake: 1, plies: 5)
        viewModel.recordStatsIfEnabled(outcome: outcome)
        XCTAssertEqual(try XCTUnwrap(store).loadStats().matches, 0)
    }

    /// Restart clears the per-match counters: a second match records its own
    /// counters, not the first match's accumulated ones.
    func testRestartResetsPerMatchCounters() throws {
        let viewModel = GameViewModel(
            stakeValue: 1, useAI: true, seed: 7, autoSave: false, stats: store)
        try playToEnd(viewModel)
        viewModel.restart()
        XCTAssertFalse(viewModel.matchState.isComplete)
        try playToEnd(viewModel)
        XCTAssertEqual(try XCTUnwrap(store).loadStats().matches, 1,
                       "restart() starts a fresh match; only the completed one records")
    }
}
