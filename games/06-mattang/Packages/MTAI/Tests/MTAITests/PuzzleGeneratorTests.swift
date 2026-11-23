// PuzzleGeneratorTests.swift — the MT-P4.2 miner's contract tests.
//
// The unit layer pins the AND/OR verifier's semantics on
// hand-authored positions where the right answer is known by
// construction: a hero placed (as the miner does) near the rival
// atoll — one landing ride → unique and solvable; no ride →
// unsolvable; two rides → ambiguous; and a searched plies-2 forced
// line whose every defender reply is re-checked with the same
// verifier. The full 120-row mining run is the G4 gate's evidence
// (Tools/mine-puzzles at the §5 budget).

import MTCore
import XCTest

@testable import MTAI

final class PuzzleGeneratorTests: XCTestCase {
    private let generator = PuzzleGenerator()
    private let chart = Fixtures.sliceChart()

    /// The rival's atoll cells (the ride targets for p1 puzzles).
    private var rivalAtoll: Set<Hex> { Set(chart.atoll(for: .p2).cells) }

    // MARK: - Position builders (the miner's overlay reconstruction)

    /// A state on the slice chart with `islands` placed, the hero
    /// canoe of `owner` at sea on `hero` (strength ≥ 1, empty, not an
    /// atoll cell), every other canoe at home, and `toMove` to move.
    /// Mirrors Tools/mine-puzzles' overlayState and
    /// MTContent.Loader.puzzleState.
    private func heroState(
        hero: Hex, owner: PlayerID = .p1, islands: [Hex] = [], toMove: PlayerID? = nil
    ) -> GameState? {
        var state = Reducer.initial(chart: chart)
        for cell in islands.sorted(by: Hex.rowMajor) {
            guard let (next, _) = try? Reducer.apply(.placeIsland(cell), to: state) else {
                return nil
            }
            state = next
        }
        guard state.field.strength(at: hero) >= 1,
            !state.isOccupied(hero), !chart.atollCells.contains(hero)
        else { return nil }
        guard
            let id = CanoeID.allCanoeIDs.first(where: {
                state.canoe($0).owner == owner && state.canoe($0).location == .home
            })
        else { return nil }
        state.canoes[id] = CanoeState(owner: owner, location: .sea(hero), becalmed: false)
        if let toMove { state.toMove = toMove }
        return state
    }

    /// Sea cells (strength ≥ 1 on the traced field) with exactly
    /// `count` neighbour cells belonging to the rival atoll — a hero
    /// there has exactly `count` distinct one-step landing rides.
    private func cellsWithRivalNeighbours(_ count: Int, islands: [Hex] = []) -> [Hex] {
        var state = Reducer.initial(chart: chart)
        for cell in islands.sorted(by: Hex.rowMajor) {
            guard let (next, _) = try? Reducer.apply(.placeIsland(cell), to: state) else {
                return []
            }
            state = next
        }
        let rival = Set(chart.atoll(for: .p1.opponent).cells)
        var found: [Hex] = []
        let radius = chart.ocean.radius
        for q in (-radius)...radius {
            for r in max(-radius, -q - radius)...min(radius, -q + radius) {
                let cell = Hex(q, r)
                guard chart.ocean.contains(cell),
                    state.field.strength(at: cell) >= 1,
                    !state.isOccupied(cell), !chart.atollCells.contains(cell)
                else { continue }
                let rides = cell.neighbors().filter { rival.contains($0) }.count
                if rides == count { found.append(cell) }
            }
        }
        return found.sorted(by: Hex.rowMajor)
    }

    // MARK: - Ply-1 semantics (the ADR-0019 degenerate case)

    /// A hero with exactly one one-step ride to the rival atoll
    /// verifies uniquely; the winning action lands a canoe.
    func testPly1SolvableUniqueVerifies() throws {
        let hero = try XCTUnwrap(
            cellsWithRivalNeighbours(1).first,
            "slice geometry must offer a one-ride cell")
        let state = try XCTUnwrap(heroState(hero: hero))
        let win = try XCTUnwrap(generator.verify(state: state, owner: .p1, plies: 1))
        let (after, events) = try Reducer.apply(win, to: state)
        XCTAssertTrue(
            events.contains { if case .landed = $0 { return true } else { return false } },
            "the unique winning action lands")
        XCTAssertEqual(after.landed[.p1], 1)
    }

    /// A hero with no ride to the rival atoll has no winning first
    /// action (launches, placements, and tows never land).
    func testPly1UnsolvableFails() throws {
        let noRide = cellsWithRivalNeighbours(0)
        let hero = try XCTUnwrap(
            noRide.first { $0.distance(to: chart.atoll(for: .p2).cells.first!) <= 4 },
            "slice geometry must offer a near-atoll cell with no ride")
        let state = try XCTUnwrap(heroState(hero: hero))
        XCTAssertNil(generator.verify(state: state, owner: .p1, plies: 1))
    }

    /// Two distinct one-step rides in reach → not unique → nil.
    func testPly1AmbiguousFails() throws {
        let hero = try XCTUnwrap(
            cellsWithRivalNeighbours(2).first ?? cellsWithRivalNeighbours(3).first,
            "the P2 rim cluster must offer a multi-ride cell")
        let state = try XCTUnwrap(heroState(hero: hero))
        XCTAssertNil(generator.verify(state: state, owner: .p1, plies: 1))
    }

    // MARK: - Multi-ply semantics (the MT-P4.2 machinery)

    /// A plies-2 forced line: whenever the probe walk finds one, the
    /// verifier's answer is cross-checked — after the claimed winning
    /// action, EVERY defender reply must leave a position where the
    /// owner still forces a landing within one more action.
    func testPly2ForcedLineVerifies() throws {
        var found: (GameState, Action)?
        let p1Atoll = chart.atoll(for: .p1)
        searchLoop: for launchCell in p1Atoll.cells.flatMap({ $0.neighbors() })
            where chart.ocean.contains(launchCell)
        {
            for direction in 0..<6 {
                var current = launchCell
                for _ in 0..<(Balance.sailRange + 2) {
                    let next = current.neighbor(direction)
                    guard chart.ocean.contains(next),
                        !chart.atollCells.contains(next),
                        state0().field.strength(at: next) >= 1
                    else { break }
                    current = next
                    guard
                        let state = heroState(hero: current),
                        let win = generator.verify(state: state, owner: .p1, plies: 2)
                    else { continue }
                    found = (state, win)
                    break searchLoop
                }
            }
        }
        guard let (state, win) = found else {
            throw XCTSkip("no plies-2 forced line found in the probe walk")
        }
        let (afterWin, _) = try Reducer.apply(win, to: state)
        let replies = Reducer.legalActions(in: afterWin)
        XCTAssertFalse(replies.isEmpty)
        let replyMemo = PuzzleGenerator.Memo()
        for reply in replies {
            let (afterReply, _) = try Reducer.apply(reply, to: afterWin)
            XCTAssertTrue(
                generator.forcedLanding(in: afterReply, owner: .p1, plies: 1, memo: replyMemo),
                "defender reply \(reply) escapes the claimed forced line")
        }
    }

    /// A hero from which no single legal action (sail, tow, launch —
    /// the engine's full action list) can bring any p1 canoe adjacent
    /// to the rival atoll, nor land outright, is unsolvable at plies 2:
    /// after the owner's first action the canoes are still not
    /// ride-adjacent, defender replies (island placements, passes)
    /// never move canoes, and a plies-1 landing action needs a canoe
    /// already ride-adjacent. The hero is chosen by exactly that
    /// structural property, near the rival atoll.
    func testPly2DefenderEscapeFails() throws {
        let noRide = cellsWithRivalNeighbours(0)
        var hero: Hex?
        var state: GameState?
        scan: for candidate in noRide where candidate.distance(to: chart.atoll(for: .p2).cells.first!) <= 6 {
            guard let candidateState = heroState(hero: candidate) else { continue }
            for action in Reducer.legalActions(in: candidateState) {
                guard let (next, events) = try? Reducer.apply(action, to: candidateState) else {
                    continue
                }
                let landed = events.contains { event in
                    if case .landed = event { return true }
                    return false
                }
                let rideAdjacent = next.canoes.values.contains { canoe in
                    guard canoe.owner == .p1, case .sea(let position) = canoe.location else {
                        return false
                    }
                    return position.neighbors().contains { rivalAtoll.contains($0) }
                }
                if landed || rideAdjacent { continue scan }
            }
            hero = candidate
            state = candidateState
            break
        }
        let pinned = try XCTUnwrap(hero, "the slice must offer an unreachable no-ride cell")
        XCTAssertNil(
            generator.verify(state: try XCTUnwrap(state), owner: .p1, plies: 2),
            "unreachable hero \(pinned) must not verify at plies 2")
        XCTAssertTrue(
            generator.winningFirstActions(
                in: try XCTUnwrap(state), owner: .p1, plies: 2
            ).isEmpty)
    }

    /// Only the goal owner's turn counts: with the opponent to move,
    /// the owner has no winning first actions even from a one-ride
    /// cell.
    func testNotOnMoveYieldsNoWinners() throws {
        let hero = try XCTUnwrap(cellsWithRivalNeighbours(1).first)
        let state = try XCTUnwrap(heroState(hero: hero, toMove: .p2))
        XCTAssertTrue(generator.winningFirstActions(in: state, owner: .p1, plies: 1).isEmpty)
    }

    /// The memo actually memoizes: a second verification of the same
    /// position is a cache hit and returns the same answer.
    func testMemoConsistency() throws {
        let hero = try XCTUnwrap(cellsWithRivalNeighbours(1).first)
        let state = try XCTUnwrap(heroState(hero: hero))
        let memo = PuzzleGenerator.Memo()
        let first = generator.forcedLanding(in: state, owner: .p1, plies: 1, memo: memo)
        let countAfterFirst = memo.count
        XCTAssertGreaterThan(countAfterFirst, 0, "the memo recorded the verification")
        let second = generator.forcedLanding(in: state, owner: .p1, plies: 1, memo: memo)
        XCTAssertEqual(first, second, "the memo must not change the answer")
        XCTAssertEqual(memo.count, countAfterFirst, "the second call must be a cache hit")
    }

    // MARK: - helpers

    /// The opening state (no islands) — only its traced field is read.
    private func state0() -> GameState {
        var canoes: [CanoeID: CanoeState] = [:]
        for id in CanoeID.allCanoeIDs {
            canoes[id] = CanoeState(owner: id.player, location: .home, becalmed: false)
        }
        return GameState(
            chart: chart, islands: [], poolRemaining: Balance.islandPool,
            canoes: canoes, landed: [.p1: 0, .p2: 0],
            toMove: .p1, stuckTurns: 0,
            field: Field.compute(
                ocean: chart.ocean, swells: chart.swells, islands: [],
                atollCells: chart.atollCells),
            status: .ongoing)
    }
}
