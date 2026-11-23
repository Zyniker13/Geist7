// GameReplay.swift — S1.4's replay adapter: records a Dry Garden game
// into the S0.6 `Replay` envelope and verifies it deterministically.
//
// The rules engine takes no randomness (S1.1), so a replay's seed and
// the recorded action stream reproduce the match exactly: applying the
// same actions to the same start state yields the same final state
// (INV-4). The seed feeds the ACTION CHOOSER (Tools/sim's random-legal
// mover), not the reducer.

public struct GameRecord: Codable, Sendable, Equatable {
    /// The starting state's courtyard id.
    public var courtyardID: String
    /// Courtyard mask + features, so a replay reconstructs the yard
    /// without content files (P1's self-contained golden replays).
    public var courtyardMask: [String]
    public var courtyardFeatures: [Feature]
    /// The ordered actions from the start state.
    public var actions: [Action]
    /// The seed that drove the chooser (informational for P1).
    public var seed: UInt64
    /// The stable hash of the final state.
    public var finalHash: UInt64

    public init(
        courtyardID: String, courtyardMask: [String],
        courtyardFeatures: [Feature], actions: [Action], seed: UInt64,
        finalHash: UInt64
    ) {
        self.courtyardID = courtyardID
        self.courtyardMask = courtyardMask
        self.courtyardFeatures = courtyardFeatures
        self.actions = actions
        self.seed = seed
        self.finalHash = finalHash
    }
}

public enum GameReplay {

    /// Verifies a record: rebuilds the courtyard, applies every action
    /// in order, and compares the final state's stable hash (INV-4).
    /// Throws the first mismatch as a text error.
    public static func verify(_ record: GameRecord) throws {
        let courtyard = try Courtyard.parse(
            id: record.courtyardID, name: record.courtyardID,
            mask: record.courtyardMask, features: record.courtyardFeatures,
            veranda: "bottom")
        let balance = Balance.standard()
        var state = GameState.fresh(
            courtyardID: record.courtyardID, balance: balance)
        for (index, action) in record.actions.enumerated() {
            do {
                let (next, _) = try Reducer.apply(
                    action, to: state, courtyard: courtyard, balance: balance)
                state = next
            } catch let reason as IllegalReason {
                throw ReplayMismatch(
                    ply: index, action: action, reason: reason)
            }
        }
        let hash = try StateHashing.stableHash(state)
        guard hash == record.finalHash else {
            throw ReplayHashMismatch(
                expected: record.finalHash, actual: hash)
        }
    }

    /// Plays the record's actions without comparing (a convenience for
    /// the sim tool's report generation).
    public static func finalState(
        of record: GameRecord
    ) throws -> (courtyard: Courtyard, state: GameState) {
        let courtyard = try Courtyard.parse(
            id: record.courtyardID, name: record.courtyardID,
            mask: record.courtyardMask, features: record.courtyardFeatures,
            veranda: "bottom")
        let balance = Balance.standard()
        var state = GameState.fresh(
            courtyardID: record.courtyardID, balance: balance)
        for action in record.actions {
            let (next, _) = try Reducer.apply(
                action, to: state, courtyard: courtyard, balance: balance)
            state = next
        }
        return (courtyard, state)
    }
}

/// The recorded action is illegal at its ply (a corrupted replay).
public struct ReplayMismatch: Error, Equatable {
    public var ply: Int
    public var action: Action
    public var reason: IllegalReason
}

/// The replay reached a different final state than recorded (INV-4
/// violated).
public struct ReplayHashMismatch: Error, Equatable {
    public var expected: UInt64
    public var actual: UInt64
}
