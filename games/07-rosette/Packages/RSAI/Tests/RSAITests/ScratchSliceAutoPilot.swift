import Foundation
import RSContent
import RSCore
import Testing

@testable import RSAI

/// Scratch: headless replica of the app's autoPilot loop at seed 42 to
/// diagnose the slice-test timeout (RS-P7). Mirrors GameViewModel.aiTurn:
/// offer decision BEFORE the roll (R-10), bot-driven moves for both sides,
/// autoPilot human always accepts, player1 answers via its MatchBot.
/// Manual-only tool; disabled in suites.
private func scratchErr(_ s: String) {
    FileHandle.standardError.write(Data((s + "\n").utf8))
}

struct ScratchSliceAutoPilot {
    @Test(.disabled("manual slice-diagnosis harness; kept for the next seed/AI change"))
    func scratchSeed42AutoPilot() async throws {
        var state = MatchState(
            ruleset: .finkel,
            track: RuleSet.finkel.makeTrack(),
            dice: .tetra4,
            pieces: (0..<7).flatMap { id in
                PlayerID.allCases.map { Piece.making(id: id, owner: $0) }
            },
            currentPlayer: .player0,
            diceValue: nil,
            movablePieceIds: [],
            extraRoll: false,
            stake: Stake(value: 1),
            cube: .centered,
            cubeDead: false,
            doubleOffered: false,
            hasDoubledThisTurn: false,
            omensHeld: [:],
            omensPlayed: [:],
            pendingOmen: nil,
            splitRemaining: nil,
            splitActive: false,
            hasRolled: false,
            borneOff: [.player0: 0, .player1: 0],
            plies: 0,
            isComplete: false,
            outcome: nil
        )
        var rng = SeededRNG(seed: 42)
        var omenRng = SeededRNG(seed: 43)
        var botRng = SeededRNG(seed: 44)
        let bot = OptimalBot(table: SolvedTableStore(), depth: 2)

        func apply(_ action: Action) {
            do {
                let result = try Reducer.apply(
                    action, to: state, rng: &rng, omenRng: &omenRng, diceSource: nil)
                state = result.state
            } catch {
                scratchErr("APPLY-ERROR \(action) \(error)")
            }
        }

        var actions = 0
        var offers = 0
        var acceptedDoubles = 0
        var stalledTurns = 0
        let clock = ContinuousClock()
        let start = clock.now
        while !state.isComplete, actions < 60_000 {
            actions += 1
            if !state.hasRolled {
                // R-10 offer decision, before the roll. Owner rule: only the
                // cube owner (or anyone, when centred) may offer.
                if !state.hasDoubledThisTurn, !state.cubeDead,
                    state.cube.owner == -1
                        || state.cube.owner == state.currentPlayer.rawValue
                {
                    let wants: Bool
                    if state.currentPlayer == .player1 {
                        wants = bot.wantsDouble(state: state, rng: &botRng)
                    } else {
                        // Demo rule: offer on the first meaningful lead.
                        let own = state.borneOff[.player0] ?? 0
                        let other = state.borneOff[.player1] ?? 0
                        wants = own > other && own >= 1
                    }
                    if wants {
                        apply(.offerDouble)
                        if state.doubleOffered {
                            offers += 1
                            // Answer: player0 (autoPilot) always accepts;
                            // player1 answers via its bot policy.
                            let answerer: PlayerID =
                                state.currentPlayer == .player0 ? .player1 : .player0
                            let accept: Bool
                            if answerer == .player1 {
                                accept = bot.decideDouble(state: state, rng: &botRng)
                            } else {
                                accept = true
                            }
                            if accept { acceptedDoubles += 1 }
                            apply(accept ? .acceptDouble : .concede)
                        }
                        // A rejected offer falls through to the roll.
                        continue
                    }
                }
                apply(.roll)
                continue
            }
            let moves = MoveGen.legalMoves(
                for: state.currentPlayer,
                amount: state.diceValue ?? 1,
                pieces: state.pieces,
                track: state.track,
                rules: state.ruleset
            )
            if let move = bot.chooseMove(from: state, moves: moves, rng: &botRng) {
                apply(.move(move.piece))
            } else {
                stalledTurns += 1
                scratchErr(
                    "STALL ply=\(state.plies) player=\(state.currentPlayer) moves=\(moves.count) rolled=\(state.hasRolled) dice=\(state.diceValue ?? -1)")
                break
            }
        }
        let elapsed = clock.now - start
        scratchErr(
            "RESULT complete=\(state.isComplete) outcome=\(String(describing: state.outcome)) plies=\(state.plies) actions=\(actions) offers=\(offers) accepted=\(acceptedDoubles) cube=\(state.cube) stalled=\(stalledTurns) elapsed=\(elapsed)")
        #expect(true)
    }
}
