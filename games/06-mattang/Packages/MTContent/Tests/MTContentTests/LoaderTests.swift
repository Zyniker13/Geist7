// LoaderTests.swift — the G3 content surface: all four charts load
// and validate, the voyage campaign references real charts, the
// tutorial script is internally consistent, and the shipped puzzle
// set is fully verified (solvable, unique first move) against the
// real reducer.

import XCTest

@testable import MTContent
@testable import MTCore

final class LoaderTests: XCTestCase {
    // MARK: - Puzzles (MT-P4.2 wiring: shipped rows ↔ the real engine)

    /// Every shipped puzzle row reconstructs into a state that is
    /// winnable by the real reducer: some legal action lands a canoe
    /// (a landing ends the game, so the row is solvable), exactly one
    /// does (the puzzle's unique first move), and the landing event
    /// fires with the goal owner's landed count rising. For a
    /// plies-2 row, after the unique first move EVERY defender reply
    /// must leave a plies-1 landing available — the same AND/OR
    /// semantics the miner's verifier uses, re-checked here from the
    /// shipped file so the row and the engine never drift apart.
    func testShippedPuzzlesAreWinnableByTheReducer() throws {
        let defs = try ContentLoader.puzzles()
        XCTAssertGreaterThanOrEqual(
            defs.count, 30, "the shipped pool starts at the G3 count and grows")
        for def in defs {
            let state = try ContentLoader.puzzleState(def)
            XCTAssertEqual(state.toMove.rawValue, def.toMove)
            let landing = legalLandingActions(in: state, owner: state.toMove)
            XCTAssertEqual(
                landing.count, 1,
                "\(def.id): expected exactly one landing action")
            let (after, events) = try Reducer.apply(try XCTUnwrap(landing.first), to: state)
            XCTAssertTrue(
                events.contains { if case .landed = $0 { return true }; return false },
                "\(def.id): the unique action must land")
            XCTAssertEqual(
                after.landed[state.toMove], 1, "\(def.id): landed count must rise")
            if def.plies >= 2 {
                let replies = Reducer.legalActions(in: after)
                XCTAssertFalse(replies.isEmpty, "\(def.id): no defender reply")
                for reply in replies {
                    let (afterReply, _) = try Reducer.apply(reply, to: after)
                    XCTAssertFalse(
                        legalLandingActions(in: afterReply, owner: state.toMove).isEmpty,
                        "\(def.id): reply \(reply) escapes the forced line")
                }
            }
        }
    }

    /// The legal actions whose application lands a canoe for `owner`.
    private func legalLandingActions(in state: GameState, owner: PlayerID) -> [Action] {
        Reducer.legalActions(in: state).filter { action in
            guard let (next, events) = try? Reducer.apply(action, to: state) else {
                return false
            }
            let landed = events.contains { event in
                if case .landed = event { return true }
                return false
            }
            return landed && next.landed[owner, default: 0] > state.landed[owner, default: 0]
        }
    }

    // MARK: - Charts (G3 count: 4)

    /// All four authored charts load and pass the engine's structural
    /// validation. `single_swell` is the tutorial chart (one swell,
    /// mirror symmetry), `crossroads` and `lagoon_mirror` complete the
    /// G3 set per ADR-0017.
    func testAllChartsLoadAndValidate() throws {
        let charts = try ContentLoader.charts()
        XCTAssertEqual(
            charts.map(\.id),
            ["two_swells_basic", "single_swell", "crossroads", "lagoon_mirror"],
            "authored order is the lesson arc")
        for chart in charts {
            XCTAssertTrue(chart.validate().isEmpty, "\(chart.id): \(chart.validate())")
        }
    }

    /// The G3 chart set's symmetries: the tutorial chart is the
    /// mirror chart (INV-6 holds there), `lagoon_mirror` carries the
    /// §A.3 sample row's rotate180 declaration (ADR-0017: authored
    /// tie-free with paired full-sweep swells).
    func testChartSymmetries() throws {
        let charts = try ContentLoader.charts()
        let byID = Dictionary(uniqueKeysWithValues: charts.map { ($0.id, $0) })
        XCTAssertEqual(try XCTUnwrap(byID["single_swell"]).symmetry, .mirror)
        XCTAssertEqual(try XCTUnwrap(byID["lagoon_mirror"]).symmetry, .rotate180)
        XCTAssertEqual(try XCTUnwrap(byID["two_swells_basic"]).symmetry, .none)
        XCTAssertEqual(try XCTUnwrap(byID["crossroads"]).symmetry, .none)
    }

    /// INV-6 holds on every shipped symmetric chart: the traced field
    /// respects the declared symmetry.
    func testShippedChartsRespectTheirSymmetry() throws {
        let charts = try ContentLoader.charts()
        for chart in charts where chart.symmetry != .none {
            let field = Field.compute(
                ocean: chart.ocean, swells: chart.swells,
                islands: chart.preIslands, atollCells: chart.atollCells)
            for cell in chart.ocean.allCells {
                let image = chart.symmetryImage(of: cell)
                XCTAssertEqual(
                    field.strength(at: cell), field.strength(at: image),
                    "\(chart.id): strength \(cell) vs image \(image)")
            }
        }
    }

    /// A.7 G3 sharpened check: no Marshallese term appears in a chart
    /// or swell row's id (ids are neutral latin ids; display names
    /// come only from pending glossary entries).
    func testChartIdsAreNeutral() throws {
        let restricted = [
            "mattang", "meddo", "rebbelib", "wapepe", "booj", "okar", "dilep", "kaelep",
        ]
        for chart in try ContentLoader.charts() {
            for term in restricted {
                XCTAssertFalse(
                    chart.id.lowercased().contains(term),
                    "chart id \(chart.id) contains restricted term \(term)")
            }
        }
        for swell in try ContentLoader.swellDefs() {
            for term in restricted {
                XCTAssertFalse(
                    swell.id.lowercased().contains(term),
                    "swell id \(swell.id) contains restricted term \(term)")
            }
        }
    }

    // MARK: - Voyages (G3 count: 6)

    /// Six voyages, each referencing an authored chart and an
    /// opponent tier the game actually has (§5 sample row shape).
    func testVoyageCampaign() throws {
        let voyages = try ContentLoader.voyages()
        XCTAssertEqual(voyages.count, 6, "G3 campaign count")
        XCTAssertEqual(voyages.map(\.id), ["v01", "v02", "v03", "v04", "v05", "v06"])
        let tierNames: Set<String> = ["sailor", "deep_water"]
        for voyage in voyages {
            XCTAssertTrue(tierNames.contains(voyage.opponent), "\(voyage.id): \(voyage.opponent)")
            XCTAssertNotNil(voyage.title, "\(voyage.id) has a title")
        }
        // Difficulty climbs: the first three sail vs Sailor, the last
        // three vs the deep-water tier (§7's default neutral names).
        XCTAssertEqual(voyages.prefix(3).allSatisfy { $0.opponent == "sailor" }, true)
        XCTAssertEqual(voyages.suffix(3).allSatisfy { $0.opponent == "deep_water" }, true)
    }

    // MARK: - Tutorial (G3 count: 5 lessons)

    /// Five lessons, the pillar-3 arc ("one island, one swell, then
    /// more"), each ending in a complete step.
    func testTutorialArc() throws {
        let lessons = try ContentLoader.lessons()
        XCTAssertEqual(lessons.count, 5, "G3 lesson count")
        XCTAssertEqual(
            lessons.map(\.id),
            ["l1_one_swell", "l2_one_island", "l3_launch", "l4_first_sail", "l5_two_swells"])
        // MT-P3.1: the "one island, one swell" sequence is lessons 1–2.
        XCTAssertEqual(lessons[0].chart, "single_swell")
        XCTAssertEqual(lessons[1].chart, "single_swell")
        XCTAssertEqual(lessons[1].steps.first?.kind, .placeIsland)
        for lesson in lessons {
            XCTAssertEqual(lesson.steps.last?.kind, .complete, lesson.id)
        }
    }

    /// Every scripted action in every lesson is legal when replayed:
    /// place_island cells are legal placements in the reconstructed
    /// lesson position, launch cells are legal launches, and sail
    /// paths validate (R-7/R-17/R-8). Lesson 2's island placement is
    /// the A.7 sharpened-G2 check's scripted board.
    func testLessonScriptsReplayLegally() throws {
        for lesson in try ContentLoader.lessons() {
            let chart = try XCTUnwrap(try ContentLoader.chart(id: lesson.chart), lesson.id)
            var state = Reducer.initial(chart: chart)
            var launched: CanoeID?
            for (index, step) in lesson.steps.enumerated() {
                // A lesson is a single-player guided script: keep the
                // learner as the mover across the applied steps (the
                // highlight/complete steps don't touch the state).
                if !state.status.isOver { state.toMove = .p1 }
                switch step.kind {
                case .placeIsland:
                    let cell = Hex(step.cell![0], step.cell![1])
                    guard Reducer.isLegal(.placeIsland(cell), in: state) else {
                        XCTFail("\(lesson.id) step \(index): illegal placement \(cell)")
                        return
                    }
                    state = (try Reducer.apply(.placeIsland(cell), to: state)).state
                case .launch:
                    let cell = Hex(step.launchCell![0], step.launchCell![1])
                    guard Reducer.isLegal(.launch(cell), in: state) else {
                        XCTFail("\(lesson.id) step \(index): illegal launch \(cell)")
                        return
                    }
                    let (next, events) = try Reducer.apply(.launch(cell), to: state)
                    state = next
                    for event in events {
                        if case .launched(let id, _) = event { launched = id }
                    }
                case .sail:
                    let path = step.path!.map { Hex($0[0], $0[1]) }
                    let id = try XCTUnwrap(launched, "\(lesson.id) sails before launching")
                    guard Reducer.isLegal(.sail(id, path), in: state) else {
                        XCTFail("\(lesson.id) step \(index): illegal sail \(path)")
                        return
                    }
                    state = (try Reducer.apply(.sail(id, path), to: state)).state
                case .highlightNodes, .complete:
                    break
                }
            }
        }
    }

    /// Lesson 2 ("one island, one swell") produces the node highlight
    /// the A.7 sharpened-G2 check predicts: after the scripted island
    /// placement, the field's node set is exactly the nodes Core
    /// computes from scratch on the same board (INV-2 shape, and the
    /// highlight the tutorial UI must render).
    func testLessonTwoNodeHighlightMatchesCore() throws {
        let lesson = try XCTUnwrap(
            try ContentLoader.lessons().first { $0.id == "l2_one_island" })
        let chart = try XCTUnwrap(try ContentLoader.chart(id: lesson.chart))
        var state = Reducer.initial(chart: chart)
        let place = try XCTUnwrap(lesson.steps.first { $0.kind == .placeIsland })
        let cell = Hex(place.cell![0], place.cell![1])
        state = (try Reducer.apply(.placeIsland(cell), to: state)).state
        // Core's incremental update == a from-scratch trace (INV-2), so
        // the predicted highlight is the incremental node set.
        let fromScratch = Field.compute(
            ocean: chart.ocean, swells: chart.swells,
            islands: state.islands, atollCells: chart.atollCells)
        var nodeCells: [Hex] = []
        for c in chart.ocean.allCells where state.field.isNode(c) {
            nodeCells.append(c)
        }
        nodeCells.sort(by: Hex.rowMajor)
        var scratchNodes: [Hex] = []
        for c in chart.ocean.allCells where fromScratch.isNode(c) {
            scratchNodes.append(c)
        }
        scratchNodes.sort(by: Hex.rowMajor)
        XCTAssertEqual(nodeCells, scratchNodes, "node highlight matches a from-scratch trace")
        // single_swell carries one swell, so R-6 nodes (≥2 distinct
        // swells) cannot exist here; the lesson's highlight is the
        // swell band (cells with strength), which the placement must
        // visibly reshape (the island bends rays).
        XCTAssertTrue(nodeCells.isEmpty, "one swell forms no R-6 nodes")
        let band = chart.ocean.allCells.filter { state.field.strength(at: $0) > 0 }
        let bandScratch = chart.ocean.allCells.filter { fromScratch.strength(at: $0) > 0 }
        XCTAssertEqual(Set(band), Set(bandScratch), "band matches a from-scratch trace")
        let bandBefore = chart.ocean.allCells.filter {
            Reducer.initial(chart: chart).field.strength(at: $0) > 0
        }
        XCTAssertNotEqual(Set(band), Set(bandBefore), "the island placement reshapes the band")
    }

    // MARK: - Puzzles (G3 count: 30; verification here is the miner's
    // independent check)

    /// The shipped puzzle set decodes, reconstructs, and — the point —
    /// every puzzle is a real forced landing: the mover can land
    /// within `plies` own moves against EVERY defender reply, and the
    /// winning first move is unique.
    func testAllPuzzlesAreForcedLandingsWithUniqueFirstMove() throws {
        let puzzles = try ContentLoader.puzzles()
        XCTAssertEqual(puzzles.count, 30, "G3 puzzle count")
        var byChart: [String: Int] = [:]
        for puzzle in puzzles {
            byChart[puzzle.chart, default: 0] += 1
            let state = try ContentLoader.puzzleState(puzzle)
            let winners = minerVerified(state: state)
            XCTAssertFalse(winners.isEmpty, "\(puzzle.id): no forced landing")
            let key = puzzleKey(state)
            let unique = winners.filter { actionKey($0) == key }
            XCTAssertEqual(
                unique.count, 1,
                "\(puzzle.id): winning first moves \(winners.map(actionKey))")
        }
        for chart in try ContentLoader.charts() {
            XCTAssertGreaterThan(
                byChart[chart.id, default: 0], 0, "chart \(chart.id) has no puzzles")
        }
    }

    /// Puzzles are unique as positions: no two share chart + island
    /// set + hero cell + mover.
    func testPuzzlesAreDistinct() throws {
        let puzzles = try ContentLoader.puzzles()
        var seen = Set<String>()
        for puzzle in puzzles {
            let state = try ContentLoader.puzzleState(puzzle)
            var hero: Hex?
            for id in CanoeID.allCanoeIDs {
                if case .sea(let at) = state.canoe(id).location,
                    state.canoe(id).owner == state.toMove
                {
                    hero = at
                }
            }
            let key =
                "\(puzzle.chart)|\(state.islands.sorted(by: Hex.rowMajor))|\(hero.map(String.init(describing:)) ?? "?")|\(state.toMove.rawValue)"
            XCTAssertTrue(seen.insert(key).inserted, "duplicate puzzle \(puzzle.id)")
        }
    }

    /// Invalid overlay rows fail loudly (a canoe on a calm cell).
    func testInvalidOverlayThrows() throws {
        var def = try XCTUnwrap(try ContentLoader.puzzleDefs().first)
        def.canoes = [PuzzleCanoeDef(owner: "p1", at: calmCell(def))]
        XCTAssertThrowsError(try ContentLoader.puzzleState(def))
    }

    // MARK: - Helpers

    /// The miner's own verification, restated: minimal landing depth
    /// over the full AND/OR search.
    private func minerVerified(state: GameState) -> [Action] {
        let mover = state.toMove
        for depth in 1...2 {
            let winners = winningMoves(in: state, plies: depth, mover: mover)
            if !winners.isEmpty { return winners }
        }
        return []
    }

    private func winningMoves(in state: GameState, plies: Int, mover: PlayerID) -> [Action] {
        guard plies >= 1, !state.status.isOver else { return [] }
        var winners: [Action] = []
        for action in Reducer.legalActions(in: state) {
            guard let (afterMover, events) = try? Reducer.apply(action, to: state) else {
                continue
            }
            let landedNow = events.contains { event in
                if case .landed = event { return true }
                return false
            }
            if landedNow, afterMover.landed[mover, default: 0] > state.landed[mover, default: 0] {
                winners.append(action)
                continue
            }
            guard plies >= 2, !afterMover.status.isOver else { continue }
            var beaten = true
            var defender = afterMover
            defender.toMove = mover.opponent
            for defense in Reducer.legalActions(in: defender) {
                guard let (afterDef, _) = try? Reducer.apply(defense, to: defender) else {
                    continue
                }
                if afterDef.status.isOver, afterDef.status.winner != mover {
                    beaten = false
                    break
                }
                if winningMoves(in: afterDef, plies: plies - 1, mover: mover).isEmpty {
                    beaten = false
                    break
                }
            }
            if beaten { winners.append(action) }
        }
        return winners
    }

    /// A canonical key for the winning first move (the hero's sail to
    /// the rival atoll in one step, or its full path).
    private func actionKey(_ action: Action) -> String {
        switch action {
        case .sail(let id, let path):
            return "sail(\(id.name),\(path.map { "\($0.q),\($0.r)" }.joined(separator: ">")))"
        case .placeIsland(let cell):
            return "place(\(cell.q),\(cell.r))"
        case .launch(let cell):
            return "launch(\(cell.q),\(cell.r))"
        case .tow(let id, let cell):
            return "tow(\(id.name),\(cell.q),\(cell.r))"
        case .pass:
            return "pass"
        }
    }

    private func puzzleKey(_ state: GameState) -> String {
        for id in CanoeID.allCanoeIDs {
            if case .sea(let at) = state.canoe(id).location,
                state.canoe(id).owner == state.toMove
            {
                // The hero's landing ride is the one-step path [atoll cell].
                if let target = state.chart.atoll(for: state.toMove.opponent).cells
                    .first(where: { at.isAdjacent(to: $0) })
                {
                    return "sail(\(id.name),\(target.q),\(target.r))"
                }
            }
        }
        return "?"
    }

    /// A strength-0 cell on the puzzle's chart for the invalid-overlay
    /// test (a canoe there cannot be launched or sail).
    private func calmCell(_ def: PuzzleDef) -> [Int] {
        let chart = try? ContentLoader.chart(id: def.chart)
        guard let chart else { return [0, 0] }
        let state = Reducer.initial(chart: chart)
        // A cell a canoe cannot enter: calm, or occupied, or an atoll
        // cell — whichever this chart has first.
        let blocked = chart.ocean.allCells.first {
            state.field.strength(at: $0) == 0 && !chart.atollCells.contains($0)
                && !state.isOccupied($0)
        }
        if let blocked { return [blocked.q, blocked.r] }
        let occupied = chart.ocean.allCells.first {
            chart.atollCells.contains($0) || state.isOccupied($0)
        }
        guard let occupied else { return [0, 0] }
        return [occupied.q, occupied.r]
    }
}
