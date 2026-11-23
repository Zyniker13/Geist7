// Playout.swift — S1.3's headless playout driver: from a seed, play
// random-legal moves to the end, track incremental ownership, and
// return a summary. `Tools/sim` and the property tests drive this.
//
// The mover draws uniformly among the legal moves with the SeededRNG
// (deterministic); the reducer itself takes no randomness. The
// incremental Ownership store updates per action and is cross-checked
// against a from-scratch recomputation at game end (INV-2's machinery;
// the tests also run the per-action cross-check).

public struct PlayoutSummary: Codable, Sendable, Equatable {
    public var seed: UInt64
    public var plies: Int
    public var placements: Int
    public var rakeMoves: Int
    public var passes: Int
    public var endedBy: String  // "doublePass", "material"
    public var finalHash: UInt64
    public var scores: [PlayerID: Int]
    public var winner: String  // "one", "two"
    public var oddGroupsOne: Int
    public var oddGroupsTwo: Int

    public init() {
        seed = 0
        plies = 0
        placements = 0
        rakeMoves = 0
        passes = 0
        endedBy = ""
        finalHash = 0
        scores = [:]
        winner = ""
        oddGroupsOne = 0
        oddGroupsTwo = 0
    }
}

public enum PlayoutError: Error, Equatable {
    case illegalMove(Action, IllegalReason)
    case noProgress(Int)
    case ownershipMismatch(Hex, InfluenceTally, InfluenceTally)
}

public enum Playout {

    /// Plays one game from `seed` with uniform random-legal moves.
    /// `verifyEveryLegalMove` re-applies EVERY generated move through
    /// the reducer each ply (INV-10's per-game sweep — expensive; the
    /// sim leaves it off, the fuzz tests turn it on). The incremental
    /// ownership is cross-checked against a from-scratch recomputation
    /// at game end always, and per action when `crossCheckEachAction`.
    public static func play(
        seed: UInt64, courtyard: Courtyard, balance: Balance = .standard(),
        verifyEveryLegalMove: Bool = false, crossCheckEachAction: Bool = false,
        maxPlies: Int = 400
    ) throws -> PlayoutSummary {
        var rng = SeededRNG(seed: seed)
        var state = GameState.fresh(courtyardID: courtyard.id, balance: balance)
        var ownership = Ownership(courtyard: courtyard, balance: balance)
        var summary = PlayoutSummary()
        summary.seed = seed

        for ply in 0..<maxPlies {
            if state.isOver { break }
            let moves = LegalMoves.all(
                for: state.toMove, courtyard: courtyard, state: state,
                balance: balance)
            if verifyEveryLegalMove {
                // INV-10: every generated move must replay legally.
                for move in moves {
                    if case .pass = move { continue }
                    do {
                        _ = try Reducer.apply(
                            move, to: state, courtyard: courtyard,
                            balance: balance)
                    } catch let reason as IllegalReason {
                        throw PlayoutError.illegalMove(move, reason)
                    }
                }
            }
            guard !moves.isEmpty else {
                throw PlayoutError.noProgress(ply)
            }
            let chosen = moves[rng.nextInt(below: moves.count)]

            // Apply through the reducer.
            let (next, _) = try Reducer.apply(
                chosen, to: state, courtyard: courtyard, balance: balance)

            // Incremental ownership update.
            switch chosen {
            case .place(let cell, _, _):
                summary.placements += 1
                let stone = next.stone(at: cell)!
                ownership.applyStonePlacement(
                    stone, context: next.stones, balance: balance)
            case .rake:
                summary.rakeMoves += 1
                if let rake = next.rakes.last {
                    ownership.applyRake(
                        rake, anchorSize: next.stone(at: rake.anchor)!.size)
                }
            case .pass:
                summary.passes += 1
            case .resign:
                break
            }

            if crossCheckEachAction {
                try crossCheck(
                    ownership: &ownership, state: next, courtyard: courtyard,
                    balance: balance)
            }

            summary.plies += 1
            state = next
        }

        // INV-2's end-of-game cross-check (always, even when the
        // per-action check ran).
        try crossCheck(
            ownership: &ownership, state: state, courtyard: courtyard,
            balance: balance)

        // End classification and scoring (INV-8: from the final state).
        if state.isOver {
            summary.finalHash = try StateHashing.stableHash(state)
            summary.scores = state.finalScores
            summary.winner = (Score.winner(from: state.finalScores) ?? .two)
                == .one ? "one" : "two"
            // R-15's two end conditions: two consecutive passes, or all
            // material spent. The reducer ends on either; classify by
            // the pass count (material exhaustion leaves passes < 2
            // unless the last actions were passes).
            summary.endedBy = summary.passes >= 2 ? "doublePass" : "material"
            let groupsOne = Score.groups(of: state.stones(of: .one))
            let groupsTwo = Score.groups(of: state.stones(of: .two))
            summary.oddGroupsOne = groupsOne.filter { $0.count % 2 == 1 }.count
            summary.oddGroupsTwo = groupsTwo.filter { $0.count % 2 == 1 }.count
        }
        return summary
    }

    /// INV-2's comparison: rebuild from scratch and compare every cell.
    public static func crossCheck(
        ownership: inout Ownership, state: GameState, courtyard: Courtyard,
        balance: Balance
    ) throws {
        ownership.rebuild(state: state, balance: balance)
        let scratch = InfluenceEngine.computeAll(
            courtyard: courtyard, stones: state.stones, rakes: state.rakes,
            balance: balance)
        for cell in courtyard.cells {
            let a = ownership.tally(at: cell)
            let b = scratch[cell] ?? InfluenceTally()
            if a != b {
                throw PlayoutError.ownershipMismatch(cell, a, b)
            }
        }
    }
}
