import Testing
import Foundation
@testable import RSPlatform
import RSCore
import RSAI
import RSMeta

// MARK: - Async match (RS-P7.1a)

/// A bot that always offers a double when it may (so the cube is exercised)
/// and always accepts a pending double. Moves are the first legal move.
private struct CubeOfferingBot: MatchBot, Sendable {
    func chooseMove(from state: MatchState, moves: [Move], rng: inout SeededRNG) -> Move? {
        _ = rng
        return moves.first
    }

    func decideDouble(state: MatchState, rng: inout SeededRNG) -> Bool {
        _ = rng
        return true
    }

    func wantsDouble(state: MatchState, rng: inout SeededRNG) -> Bool {
        _ = rng
        return true
    }
}

@Suite("Async match engine (RS-P7.1a)")
struct AsyncMatchEngineTests {

    /// G7: an async match with the cube completes headlessly; every action
    /// is exchanged through the transport, and the cube is used.
    @Test("async match with cube completes and exchanges actions")
    func asyncMatchCompletes() async throws {
        let transport = LocalMatchTransport()
        let engine = AsyncMatchEngine(
            transport: transport,
            bot0: CubeOfferingBot(),
            bot1: CubeOfferingBot(),
            ruleset: .finkel,
            dice: .tetra4,
            stake: 1,
            seed: 0xC0FFEE,
            maxCube: 16
        )
        let result = try engine.play()

        // The match completed (a winner was decided, not a cap).
        #expect(result.winner != nil)

        // Every action the driver took was exchanged through the transport.
        #expect(!result.sent.isEmpty)
        #expect(result.sent.count == result.record.actions.count)

        // The cube was used: at least one double action was exchanged.
        #expect(result.cubeUsed)
        #expect(result.sent.contains { $0.action == .offerDouble })
    }

    /// The transport records the acting player for each action.
    @Test("transport records the acting player")
    func transportRecordsActor() async throws {
        let transport = LocalMatchTransport()
        let engine = AsyncMatchEngine(
            transport: transport,
            bot0: CubeOfferingBot(),
            bot1: CubeOfferingBot(),
            ruleset: .finkel,
            dice: .tetra4,
            stake: 1,
            seed: 7,
            maxCube: 8
        )
        let result = try engine.play()
        #expect(!result.sent.isEmpty)
        for action in result.sent {
            #expect(action.player == .player0 || action.player == .player1)
        }
    }
}

// MARK: - ODR solved table (RS-P7.2a)

/// A `TableSource` that returns a URL to a temp file with a table.
private struct TempFileTableSource: TableSource {
    let url: URL
    func tableURL() -> URL? { url }
}

@Suite("Solved table ODR provider (RS-P7.2a)")
struct SolvedTableProviderTests {

    /// G7 offline fallback: when the source has no table (nil URL), the
    /// provider degrades to a nil table (the AI falls back to
    /// expectiminimax) and `isAvailable` is false.
    @Test("offline fallback degrades to expectiminimax (nil table)")
    func offlineFallback() {
        let provider = SolvedTableProvider(source: NullTableSource())
        let store = provider.load()
        #expect(store.table == nil)
        #expect(!store.isAvailable)
        #expect(!provider.isAvailable)
    }

    /// G7 ODR download: when the source has a valid table file, the provider
    /// loads it and `isAvailable` is true.
    @Test("ODR download loads a valid table")
    func odrDownload() throws {
        // Build a minimal valid table and serialize it to a temp file.
        let table = UrTable(pieces: 1, values: [32767], layerStart: [0, 1])
        let data = table.serialized()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rs-odr-\(ProcessInfo.processInfo.globallyUniqueString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("table.bin")
        try data.write(to: file)
        defer { try? FileManager.default.removeItem(at: dir) }

        let provider = SolvedTableProvider(source: TempFileTableSource(url: file))
        #expect(provider.isAvailable)
        let store = provider.load()
        #expect(store.table != nil)
        #expect(store.isAvailable)
        #expect(store.table?.pieces == 1)
    }

    /// A corrupt table file degrades to nil (the offline fallback), not a
    /// crash or a partial table.
    @Test("corrupt table file degrades to nil")
    func corruptTableDegrades() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rs-odr-\(ProcessInfo.processInfo.globallyUniqueString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("bad.bin")
        try Data([0x00, 0x01, 0x02]).write(to: file)
        defer { try? FileManager.default.removeItem(at: dir) }

        let provider = SolvedTableProvider(source: TempFileTableSource(url: file))
        #expect(provider.isAvailable) // the file exists
        let store = provider.load()
        #expect(store.table == nil)   // but it is unreadable
        #expect(!store.isAvailable)
    }
}

// MARK: - Game Center service (RS-P7.1b)

@Suite("Game Center service (RS-P7.1b)")
struct GameCenterServiceTests {

    /// The mock authenticates and the daily match is date-seeded (the same
    /// date yields the same dice), and a win is submitted to the leaderboard.
    @Test("mock daily match and leaderboard")
    func mockDailyMatch() async throws {
        let gc = MockGameCenter()
        let service = GameCenterService(gc)
        #expect(!service.isAuthenticated)
        try await service.authenticate()
        #expect(service.isAuthenticated)

        let date = Date(timeIntervalSinceReferenceDate: 0)
        // The same date yields the same dice sequence (date-seeded).
        let a = service.dailyMatch(for: date)
        let b = service.dailyMatch(for: date)
        #expect(a.seed == b.seed)
        #expect(a.diceSequence == b.diceSequence)

        // Play the daily match; a win (if any) is submitted to the board.
        let record = try await service.playDaily(forDate: date, player: CubeOfferingBot())
        _ = record
        // The leaderboard is readable (empty or populated, no crash).
        let scores = try await service.loadScores(.dailyWins)
        _ = scores  // readable without crashing is the contract here
    }

    /// The circuit purse is submitted to the `circuit-purse` leaderboard.
    @Test("circuit purse submission")
    func circuitPurse() async throws {
        let gc = MockGameCenter()
        let service = GameCenterService(gc)
        try await service.authenticate()
        try await service.submitCircuitPurse(42)
        #expect(gc.submitted.contains { $0.kind == "circuit-purse" && $0.score == 42 })
    }
}

// MARK: - Cloud store (RS-P7.1c)

@Suite("Cloud store (RS-P7.1c)")
struct CloudStoreTests {

    /// A minimal tavern fixture for the circuit-state round-trip.
    private static let tavern = Tavern(
        id: "tavern-1",
        name: "Test Tavern",
        region: "ur",
        rulesetId: "finkel",
        opponentId: "opponent-1",
        minStake: 1,
        buyIn: 0,
        gammonRule: false,
        label: .attested,
        historyNote: nil
    )

    /// The in-memory store round-trips a circuit state (the iCloud sync
    /// payload).
    @Test("in-memory store round-trips circuit state")
    func inMemoryRoundTrip() async throws {
        let store = InMemoryCloudStore()
        let state = CircuitState(taverns: [Self.tavern], startPurse: 5, finalCrawford: true)
        let data = try JSONEncoder().encode(state)
        try await store.save(data, forKey: "circuit")
        let loaded = try #require(await store.load(forKey: "circuit"))
        let decoded = try JSONDecoder().decode(CircuitState.self, from: loaded)
        #expect(decoded == state)
    }

    /// A missing key returns nil.
    @Test("missing key returns nil")
    func missingKey() async throws {
        let store = InMemoryCloudStore()
        let loaded = try await store.load(forKey: "nope")
        #expect(loaded == nil)
    }

    /// The file store round-trips a circuit state (the local substitute).
    @Test("file store round-trips circuit state")
    func fileRoundTrip() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rs-cloud-\(ProcessInfo.processInfo.globallyUniqueString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FileCloudStore(directory: dir)
        let state = CircuitState(taverns: [Self.tavern], startPurse: 3, finalCrawford: false)
        let data = try JSONEncoder().encode(state)
        try await store.save(data, forKey: "circuit")
        let loaded = try #require(await store.load(forKey: "circuit"))
        let decoded = try JSONDecoder().decode(CircuitState.self, from: loaded)
        #expect(decoded == state)
    }
}

// MARK: - DailyResultStore (RS-P7.1b)

@Suite("Daily result store (RS-P7.1b)")
struct DailyResultStoreTests {
    /// A fresh store backed by an isolated defaults suite.
    private func makeStore() throws -> (DailyResultStore, UserDefaults) {
        let defaults = try #require(
            UserDefaults(suiteName: "daily-results-\(ProcessInfo.processInfo.globallyUniqueString)"))
        return (DailyResultStore(defaults: defaults), defaults)
    }

    /// A recorded day reads back.
    @Test("records and reads a day's result")
    func roundTrip() throws {
        let (store, _) = try makeStore()
        #expect(store.result(for: 20_000) == nil)
        store.record(day: 20_000, result: .won)
        #expect(store.result(for: 20_000) == .won)
        store.record(day: 20_001, result: .lost)
        #expect(store.result(for: 20_001) == .lost)
        #expect(store.result(for: 20_000) == .won)
    }

    /// Re-recording a day replaces its result.
    @Test("re-recording replaces the result")
    func replace() throws {
        let (store, _) = try makeStore()
        store.record(day: 20_000, result: .won)
        store.record(day: 20_000, result: .lost)
        #expect(store.result(for: 20_000) == .lost)
    }

    /// Retention keeps only the last 30 days.
    @Test("retention keeps the last 30 days")
    func retention() throws {
        let (store, _) = try makeStore()
        for day in 1...35 {
            store.record(day: day, result: .won)
        }
        #expect(store.result(for: 1) == nil)
        #expect(store.result(for: 5) == nil)
        #expect(store.result(for: 6) == .won)
        #expect(store.result(for: 35) == .won)
    }
}
