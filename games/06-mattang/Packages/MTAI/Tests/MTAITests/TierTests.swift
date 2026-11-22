// TierTests.swift — the tier ladder's contract tests.
//
// The unit layer pins the ladder's ordering contract with small-N
// samples on cheap charts; the full-depth, 500-game soak runs in the
// G4 gate (Tools/sim --soak). Deep tiers at full depth on the
// radius-7 slice take minutes per ply in a DEBUG test build — the
// A.5 search's own budget — so the in-suite tier checks run the deep
// tiers at their reduced unit depths (testDepth) and full games on
// the radius-3 chart (≈100× cheaper per ply, identical engine
// surface). Full-depth behavior is not untested: `soak` exercises it
// and its p95/§7-budget bounds are recorded in docs/BALANCE.md.

import MTCore
import XCTest

@testable import MTAI

final class TierTests: XCTestCase {
    /// A fresh opening state on the slice chart with a seeded field.
    private func openingState(seed: UInt64) -> GameState {
        Self.opening(seed: seed)
    }

    /// The tier's reduced in-suite depth (file header): deep tiers run
    /// their depth-independent contract checks at depth 2 so the whole
    /// MTAI suite finishes in minutes in DEBUG. Navigator's full 4 and
    /// Deep Water's full 6 cost minutes per ply on the radius-7 slice
    /// in a DEBUG build; their full-depth behavior stays covered by
    /// the G4 soak, whose p95s are recorded in docs/BALANCE.md.
    private static func unit(_ tier: Tier) -> Tier {
        guard tier.depth > 2 else { return tier }
        return Tier(id: tier.id, depth: 2, noiseBand: tier.noiseBand)
    }

    /// Paddler's noise band picks among near-best actions but stays
    /// deterministic per seed.
    func testPaddlerDeterministicPerSeed() {
        let state = openingState(seed: 11)
        for _ in 0..<2 {
            var rng = SeededRNG(seed: 11)
            let a = Player(tier: .paddler).chooseAction(in: state, rng: &rng)
            var rng2 = SeededRNG(seed: 11)
            let b = Player(tier: .paddler).chooseAction(in: state, rng: &rng2)
            XCTAssertEqual(a, b, "same seed, same action")
        }
    }

    /// Different seeds may differ for the noise tier but never for a
    /// zero-band tier. Deep tiers run at their unit depths (see the
    /// file header) — a tier's seed-independence is depth-independent.
    func testZeroBandTiersIgnoreSeed() {
        let state = openingState(seed: 12)
        for tier in Tier.ladder.dropFirst() {
            var rngA = SeededRNG(seed: 1)
            var rngB = SeededRNG(seed: 2)
            let a = Player(tier: Self.unit(tier)).chooseAction(in: state, rng: &rngA)
            let b = Player(tier: Self.unit(tier)).chooseAction(in: state, rng: &rngB)
            XCTAssertEqual(a, b, "\(tier.id) is seed-independent")
        }
    }

    /// Every tier's choice is a legal action (the ladder's invariant),
    /// on a mid-game position too. Legality is a property of the
    /// chosen action against legalActions, not of the search depth, so
    /// deep tiers run at their unit depths here.
    func testEveryTierChoosesLegalAction() {
        for tier in Tier.ladder {
            for seed: UInt64 in [13, 15] {
                let state = openingState(seed: seed)
                var rng = SeededRNG(seed: 14)
                let action = Player(tier: Self.unit(tier)).chooseAction(
                    in: state, rng: &rng)
                XCTAssertTrue(
                    Reducer.legalActions(in: state).contains(action),
                    "\(tier.id) chose a legal action at seed \(seed)")
            }
        }
    }

    /// Every tier's choice is legal in a developed mid-game position
    /// (islands down, canoes at sea) — the opening-only check cannot
    /// see placement-adjacent regressions.
    func testEveryTierChoosesLegalActionMidGame() throws {
        for tier in Tier.ladder {
            // Play Paddler-vs-Paddler 8 plies from a fixed opening to
            // reach a developed position cheaply and deterministically.
            var state = Self.opening(seed: 31)
            var stream = SeededRNG(seed: 32)
            for _ in 0..<8 {
                var side = SeededRNG(seed: stream.nextUInt64())
                let action = Player(tier: .paddler).chooseAction(
                    in: state, rng: &side)
                _ = stream.nextUInt64()
                state = try Reducer.apply(action, to: state).state
                if state.status.isOver { break }
            }
            var rng = SeededRNG(seed: 33)
            let action = Player(tier: Self.unit(tier)).chooseAction(
                in: state, rng: &rng)
            XCTAssertTrue(
                Reducer.legalActions(in: state).contains(action),
                "\(tier.id) chose a legal action mid-game")
        }
    }

    /// A small ladder sample on the radius-3 chart (see the file
    /// header): deeper tiers must not lose to shallower ones over
    /// these games. The full ≥ 75% gate runs in the G4 soak.
    func testNavigatorBeatsSailorInSample() {
        let sample = Self.playLadderPair(
            higher: .navigator, lower: .sailor, games: 6, seed: 100)
        XCTAssertGreaterThanOrEqual(
            sample.higherWins, sample.lowerWins,
            "Navigator does not lose to Sailor in the 6-game sample")
    }

    /// The top of the ladder over the same cheap chart: full-depth
    /// Deep Water on radius 3 is still minutes per game in DEBUG, so
    /// the unit tier runs at its reduced depth; the direction only
    /// needs a tier strictly stronger than Navigator's opponent.
    func testDeepWaterDoesNotLoseToSailorInSample() {
        let sample = Self.playLadderPair(
            higher: .deepWater, lower: .sailor, games: 4, seed: 200)
        XCTAssertGreaterThanOrEqual(
            sample.higherWins + sample.splits, sample.lowerWins,
            "Deep Water does not lose to Sailor in the 4-game sample")
    }

    /// REGRESSION (P4 soak diagnosis): the root must return its scored
    /// list best-first by the FINAL iteration's values — chooseAction
    /// plays the head. The old run() returned the list in search
    /// order, so the root played the PREVIOUS iteration's best (a
    /// depth-2 tier played its depth-1 best; the deepest ply never
    /// chose), and the noise band compared against the first action's
    /// value instead of the maximum.
    func testRootScoresAreValueSorted() {
        let state = Self.smallOpening(seed: 40)
        let scores = AlphaBeta(tier: .sailor).rootScores(in: state)
        XCTAssertGreaterThan(
            scores.count, 1, "the opening offers several actions")
        for index in 1..<scores.count {
            XCTAssertGreaterThanOrEqual(
                scores[index - 1].value, scores[index].value,
                "root scores must be non-increasing at \(index)")
        }
        var rng = SeededRNG(seed: 41)
        let chosen = AlphaBeta(tier: .sailor).chooseAction(
            in: state, rng: &rng)
        XCTAssertEqual(
            chosen, scores[0].action,
            "chooseAction plays the best root score")
    }

    /// REGRESSION (P4 soak diagnosis): the search must see R-23. A
    /// would-be third repetition of a position ends the game by the
    /// R-11 tie-break, and the AI must not choose it when the
    /// tie-break goes against the mover. Search.apply used to wipe
    /// `visited`, so every repetition looked free and the engine
    /// walked into tie-break losses (the "P2 won every mixed game"
    /// soak pattern).
    func testSearchAvoidsThirdRepetitionLoss() throws {
        let chart = Fixtures.chart()
        // p2 has already landed a canoe: any R-11 tie-break goes to p2
        // on the landed count alone, so a third repetition is a LOSS
        // for the mover. x is becalmed at (0,0) (strength 0); y stands
        // alongside on the only strong cell in its neighbourhood, so
        // y has no sail and the mover's actions are the five tows of
        // x. Towing x onto (0,-1) (strength 1, distance 2 from the
        // rival atoll) is the evaluation's best tow by a margin.
        let x = CanoeID(player: .p1, index: 0)
        let y = CanoeID(player: .p1, index: 1)
        var state = Fixtures.state(
            chart: chart,
            field: Fixtures.field(strong: [
                Hex(1, 0): 1, Hex(0, -1): 1, Hex(1, -2): 1, Hex(-1, 1): 1,
            ]),
            pool: 0,
            locations: [x: .sea(Hex(0, 0)), y: .sea(Hex(-1, 1))],
            becalmed: [x],
            landed: [.p1: 0, .p2: 1],
            toMove: .p1)
        // The position after that tow has occurred twice. Reducer
        // records the key before flipping the turn, so the recorded
        // state still has p1 to move.
        var after = state
        after.canoes[x] = CanoeState(
            owner: .p1, location: .sea(Hex(0, -1)), becalmed: false)
        let key = Zobrist.positionKey(of: after)
        state.visited[key, default: 0] = 2

        // Control: the real rules end the game on that tow, and the
        // tie-break goes to p2 on the landed count.
        let (doomed, _) = try Reducer.apply(.tow(x, Hex(0, -1)), to: state)
        guard case .tiebreak(let winner) = doomed.status else {
            return XCTFail("the third repetition must end the game by R-11")
        }
        XCTAssertEqual(winner, .p2, "p2's landing wins the tie-break")

        // The engine must not choose the doomed tow, and its choice
        // must remain one of the other legal tows.
        var rng = SeededRNG(seed: 5)
        let chosen = AlphaBeta(tier: .sailor).chooseAction(
            in: state, rng: &rng)
        XCTAssertNotEqual(
            chosen, .tow(x, Hex(0, -1)),
            "the search must see the R-23 tie-break loss")
        XCTAssertTrue(
            Reducer.legalActions(in: state).contains(chosen),
            "the choice stays legal")
    }

    /// The self-play completion harness: two named tiers play `games`
    /// games from seeded openings. Returns the win/split tally.
    /// Shared with the G4 soak and the balance sim. In-suite samples
    /// play on the radius-3 chart (`smallOpening` below) and run the
    /// deep tiers at their unit depths; the G4 soak plays the same
    /// harness at full depth on the radius-7 slice via `sim --soak`.
    /// Seats alternate across games (even games seat the higher tier
    /// P1, odd games P2) so a seat-biased chart cannot read as a tier
    /// gap — the soak's own rule, mirrored here.
    static func playLadderPair(
        higher: Tier, lower: Tier, games: Int, seed: UInt64
    ) -> (higherWins: Int, lowerWins: Int, splits: Int) {
        var higherWins = 0
        var lowerWins = 0
        var splits = 0
        for game in 0..<games {
            let higherIsP1 = game % 2 == 0
            var state = Self.smallOpening(seed: seed &+ UInt64(game))
            var rng = SeededRNG(seed: seed &+ UInt64(game) &+ 10_000)
            var plies = 0
            while !state.status.isOver && plies < 600 {
                let mover = state.toMove
                let highSide = (mover == .p1) == higherIsP1
                let tier = Self.unit(highSide ? higher : lower)
                var side = SeededRNG(seed: rng.nextUInt64())
                let action = Player(tier: tier).chooseAction(
                    in: state, rng: &side)
                _ = rng.nextUInt64()
                do {
                    state = try Reducer.apply(action, to: state).state
                } catch {
                    preconditionFailure("illegal AI action: \(error)")
                }
                plies += 1
            }
            switch state.status.winner {
            case .p1: higherWins += 1
            case .p2: lowerWins += 1
            case nil: splits += 1
            }
        }
        return (higherWins, lowerWins, splits)
    }

    /// A deterministic opening state (shared with the soak harness):
    /// the slice chart's traced opening field, canoes at home. The
    /// per-game seed chooses the game's action-stream seed, not the
    /// field — the opening position is chart-canonical, so pair
    /// results differ by seed and color only through play.
    static func opening(seed: UInt64) -> GameState {
        Self.opening(on: Fixtures.sliceChart(), seed: seed)
    }

    /// The radius-3 chart's opening, for the in-suite ladder samples
    /// (the file header explains the depth/size budget split).
    static func smallOpening(seed: UInt64) -> GameState {
        Self.opening(
            on: Fixtures.chart(
                swells: [
                    Swell.major(id: "e", entrySide: 0, direction: 3),
                    Swell.minor(id: "n", entrySide: 4, direction: 1),
                ]),
            seed: seed)
    }

    private static func opening(on chart: Chart, seed: UInt64) -> GameState {
        let field = Field.compute(
            ocean: chart.ocean, swells: chart.swells, islands: [],
            atollCells: chart.atollCells)
        var canoes: [CanoeID: CanoeState] = [:]
        for id in CanoeID.allCanoeIDs {
            canoes[id] = CanoeState(owner: id.player, location: .home, becalmed: false)
        }
        return GameState(
            chart: chart, islands: [], poolRemaining: Balance.islandPool,
            canoes: canoes, landed: [.p1: 0, .p2: 0],
            toMove: .p1, stuckTurns: 0, field: field, status: .ongoing)
    }
}
