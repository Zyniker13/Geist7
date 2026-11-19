import Foundation
import RSCore

// MARK: - SentAction

/// One action exchanged between the two players of an async match
/// (RS-P7.1). The action is the move (or double decision) and the player is
/// the side that made it. The transport records these in order so a match
/// can be replayed or audited.
public struct SentAction: Sendable, Hashable {
    public let action: Action
    public let player: PlayerID

    public init(action: Action, player: PlayerID) {
        self.action = action
        self.player = player
    }
}

// MARK: - MatchTransport

/// The channel over which an async match's actions are exchanged
/// (RS-P7.1). In production this is a Game Center async match (each action
/// is a `GKMatch` turn); locally it is an in-memory transport. The engine
/// sends every action through the transport before the match completes, so
/// the recorded actions are exactly the moves the two sides exchanged.
public protocol MatchTransport: Sendable {
    /// Send one action from one player to the other.
    func send(_ action: Action, from player: PlayerID) throws
    /// The actions sent so far, in order.
    func sentActions() -> [SentAction]
}

// MARK: - LocalMatchTransport

/// An in-memory `MatchTransport` (RS-P7.1). Records every sent action. Used
/// by the tests and by the local (offline) async match, where the two sides
/// are in the same process.
public final class LocalMatchTransport: MatchTransport, @unchecked Sendable {
    private var sent: [SentAction] = []
    private let lock = NSLock()

    public init() {}

    public func send(_ action: Action, from player: PlayerID) {
        lock.lock()
        defer { lock.unlock() }
        sent.append(SentAction(action: action, player: player))
    }

    public func sentActions() -> [SentAction] {
        lock.lock()
        defer { lock.unlock() }
        return sent
    }
}

// MARK: - AsyncMatchEngine

/// Plays an async match between two bots, exchanging every action through a
/// `MatchTransport` (RS-P7.1). The match is driven by `BotMatch.play` (the
/// same deterministic driver the circuit simulation uses); the engine hooks
/// each action into the transport so the two sides' moves are recorded as
/// they are exchanged. The cube mechanic is part of the match: the driver
/// offers and decides doubles (R-10), and the engine records those actions
/// like any other.
///
/// The engine is headless: it needs no UI, no network, and no Game Center
/// account. A `LocalMatchTransport` (or a mock Game Center transport) is
/// enough to verify that an async match with the cube completes.
///
/// The engine is immutable after init and a match is played to completion
/// on a single thread, so it is safe to share across concurrency domains
/// (`@unchecked Sendable`; the `MatchBot` protocol is not `Sendable`).
public final class AsyncMatchEngine: @unchecked Sendable {

    /// The transport the actions are exchanged through.
    public let transport: any MatchTransport

    /// The two bots (player 0 and player 1).
    public let bot0: any MatchBot
    public let bot1: any MatchBot

    /// The ruleset.
    public let ruleset: RuleSet

    /// The dice model.
    public let dice: DiceModel

    /// The stake.
    public let stake: Int

    /// The match seed.
    public let seed: UInt64

    /// A fixed dice sequence (the daily match); nil for a seeded RNG.
    public let diceSequence: [Int]?

    /// The maximum cube value (R-10).
    public let maxCube: Int

    public init(
        transport: any MatchTransport,
        bot0: any MatchBot,
        bot1: any MatchBot,
        ruleset: RuleSet,
        dice: DiceModel,
        stake: Int,
        seed: UInt64,
        diceSequence: [Int]? = nil,
        maxCube: Int = 64
    ) {
        self.transport = transport
        self.bot0 = bot0
        self.bot1 = bot1
        self.ruleset = ruleset
        self.dice = dice
        self.stake = stake
        self.seed = seed
        self.diceSequence = diceSequence
        self.maxCube = maxCube
    }

    /// The result of a completed async match.
    public struct Result: Sendable {
        /// The full match record (actions, events, final state).
        public let record: BotMatch.Record
        /// The actions exchanged through the transport, in order.
        public let sent: [SentAction]
        /// Whether the cube was doubled at least once (R-10).
        public let cubeUsed: Bool
        /// The winner, if the match completed.
        public var winner: PlayerID? {
            record.events.compactMap { event -> PlayerID? in
                if case .matchWon(let w, _) = event { return w }
                return nil
            }.last
        }
    }

    /// Play the async match to completion, sending every action through the
    /// transport. Returns the completed match record and the exchanged
    /// actions. Throws if the match does not complete.
    public func play() throws -> Result {
        let record = try BotMatch.play(
            seed: seed,
            ruleset: ruleset,
            dice: dice,
            stake: stake,
            bot0: bot0,
            bot1: bot1,
            maxCube: maxCube,
            diceSequence: diceSequence,
            onAction: { [transport] action, actor in
                try? transport.send(action, from: actor)
            }
        )
        let sent = transport.sentActions()
        let cubeUsed = record.events.contains {
            if case .cubeDoubled = $0 { return true }
            return false
        }
        return Result(record: record, sent: sent, cubeUsed: cubeUsed)
    }
}
