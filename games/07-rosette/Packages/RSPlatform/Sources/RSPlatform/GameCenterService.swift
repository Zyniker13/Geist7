import Foundation
import RSCore
import RSMeta

// MARK: - GameCenterScore

/// One named score on a Game Center leaderboard (RS-P7.1).
public struct GameCenterScore: Sendable, Equatable {
    public let name: String
    public let score: Int

    public init(name: String, score: Int) {
        self.name = name
        self.score = score
    }
}

// MARK: - GameCenterLike

/// The Game Center surface the app uses (RS-P7.1): authentication,
/// leaderboard submission, and leaderboard reads. The real implementation
/// wraps GameKit (`GameKitGameCenter`); tests and the offline local build
/// use `MockGameCenter`. Keeping the surface this small means the app never
/// touches GameKit directly, so the daily match and circuit purse work with
/// no Apple account (the local substitute, `_CONVENTIONS.md` §8.2).
public protocol GameCenterLike: Sendable {
    /// Whether the local player is authenticated.
    var isAuthenticated: Bool { get }
    /// Authenticate the local player.
    func authenticate() async throws
    /// Submit a score to a leaderboard (by kind id).
    func submit(score: Int, to kind: String) async throws
    /// Load the top scores from a leaderboard (by kind id).
    func loadScores(kind: String) async throws -> [GameCenterScore]
}

// MARK: - GameCenterService

/// The app-facing Game Center service (RS-P7.1). Wraps a `GameCenterLike`
/// and exposes the two Game Center features the game ships: the **daily
/// match** (reusing RSMeta's date-seeded `DailyMatch`, so every player on
/// the same UTC day plays the same dice) and the **circuit purse**
/// (submitting the player's purse to the `circuit-purse` leaderboard).
///
/// The service is headless and needs no Apple account: with a
/// `MockGameCenter` it runs fully offline.
public final class GameCenterService: Sendable {
    private let gc: any GameCenterLike

    public init(_ gc: any GameCenterLike) {
        self.gc = gc
    }

    /// The leaderboard kind ids (match RSMeta's `LeaderboardKind` raw values).
    public enum Kind: String, Sendable {
        case dailyWins = "daily-wins"
        case circuitPurse = "circuit-purse"
    }

    /// Whether the local player is authenticated.
    public var isAuthenticated: Bool { gc.isAuthenticated }

    /// Authenticate the local player.
    public func authenticate() async throws {
        try await gc.authenticate()
    }

    /// The daily match for `date` (RS-P7.1): the date-seeded dice sequence
    /// and opponent every player that day plays.
    public func dailyMatch(for date: Date) -> DailyMatch {
        DailyMatch.make(forDate: date)
    }

    /// Play the daily match for `date` as `player` and, on a win, submit the
    /// win to the `daily-wins` leaderboard. Returns the match record.
    @discardableResult
    public func playDaily(
        forDate date: Date,
        player: some MatchBot,
        stake: Int = 2
    ) async throws -> BotMatch.Record {
        let record = try DailyMatch.play(forDate: date, player: player, stake: stake)
        if let winner = record.events.last {
            if case .matchWon(let w, _) = winner, w == .player0 {
                try await gc.submit(score: 1, to: Kind.dailyWins.rawValue)
            }
        }
        return record
    }

    /// Submit the player's circuit purse to the `circuit-purse` leaderboard
    /// (RS-P7.1). The purse is in-game gold only (no real money).
    public func submitCircuitPurse(_ purse: Int) async throws {
        try await gc.submit(score: purse, to: Kind.circuitPurse.rawValue)
    }

    /// Submit a raw score to a leaderboard kind (the app uses this for the
    /// daily-win mirror count; `submitCircuitPurse` covers the purse).
    public func submit(score: Int, to kind: Kind) async throws {
        try await gc.submit(score: score, to: kind.rawValue)
    }

    /// Load the top scores for a leaderboard kind.
    public func loadScores(_ kind: Kind) async throws -> [GameCenterScore] {
        try await gc.loadScores(kind: kind.rawValue)
    }
}

// MARK: - MockGameCenter

/// An in-memory `GameCenterLike` (RS-P7.1). Records submissions and serves
/// canned scores. Used by the tests and by the offline local build.
public final class MockGameCenter: GameCenterLike, @unchecked Sendable {
    private let lock = NSLock()
    private var _isAuthenticated = false
    private var _submitted: [(kind: String, score: Int)] = []
    private var _scores: [String: [GameCenterScore]] = [:]

    public init(scores: [String: [GameCenterScore]] = [:]) {
        lock.withLock { _scores = scores }
    }

    public var isAuthenticated: Bool {
        lock.withLock { _isAuthenticated }
    }

    public func authenticate() async throws {
        lock.withLock { _isAuthenticated = true }
    }

    public func submit(score: Int, to kind: String) async throws {
        lock.withLock { _submitted.append((kind: kind, score: score)) }
    }

    public func loadScores(kind: String) async throws -> [GameCenterScore] {
        lock.withLock { _scores[kind] ?? [] }
    }

    /// The submissions made so far, in order (test hook).
    public var submitted: [(kind: String, score: Int)] {
        lock.withLock { _submitted }
    }
}

// MARK: - GameKitGameCenter

/// The real Game Center `GameCenterLike` (RS-P7.1), wrapping GameKit.
///
/// OWNER-ONLY / UNTESTED: requires a signed-in Apple account with Game
/// Center enabled on the app (App Store Connect + a Game Center capability).
/// Per `_CONVENTIONS.md` §8.2 this is a local substitute in the build; the
/// real account work is a maintainer issue. The API calls follow the
/// documented GameKit flow (authenticate → submit score / load scores) but
/// have not been exercised against a live account.
#if canImport(GameKit)
import GameKit

public final class GameKitGameCenter: GameCenterLike, @unchecked Sendable {
    private let lock = NSLock()
    private var _isAuthenticated = false

    public init() {}

    public var isAuthenticated: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isAuthenticated
    }

    public func authenticate() async throws {
        // Authenticate the local player. The completion handler is the
        // documented GameKit flow; we resolve once it fires. GameKit may
        // invoke the handler more than once, so resolve the continuation
        // exactly once.
        let once = ResumeOnce()
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
                guard once.claim() else { return }
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                // In a real app the view controller is presented by the UI
                // layer to sign the player in; here we only record the
                // outcome once it is no longer presented.
                if viewController == nil, GKLocalPlayer.local.isAuthenticated {
                    self?.lock.withLock { self?._isAuthenticated = true }
                }
                cont.resume()
            }
        }
    }

    public func submit(score: Int, to kind: String) async throws {
        // The documented class-method flow (GameKit iOS 14+ / macOS 11+):
        // submit one score to one leaderboard ID for the local player.
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            GKLeaderboard.submitScore(
                score,
                context: 0,
                player: GKLocalPlayer.local,
                leaderboardIDs: [kind]
            ) { error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume()
                }
            }
        }
    }

    public func loadScores(kind: String) async throws -> [GameCenterScore] {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[GameCenterScore], Error>) in
            // The documented flow: load the leaderboard by App Store Connect
            // ID, then read its global all-time entries.
            GKLeaderboard.loadLeaderboards(IDs: [kind]) { leaderboards, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                guard let leaderboard = leaderboards?.first else {
                    cont.resume(returning: [])
                    return
                }
                leaderboard.loadEntries(
                    for: .global,
                    timeScope: .allTime,
                    range: NSRange(location: 1, length: 100)
                ) { _, entries, _, error in
                    if let error {
                        cont.resume(throwing: error)
                        return
                    }
                    let scores = (entries ?? []).map {
                        GameCenterScore(name: $0.player.displayName, score: $0.score)
                    }
                    cont.resume(returning: scores)
                }
            }
        }
    }
}

/// Resolves exactly once (GameKit may fire its handler more than once).
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    /// Returns true on the first call, false afterwards.
    func claim() -> Bool {
        lock.withLock {
            if done { return false }
            done = true
            return true
        }
    }
}
#endif
