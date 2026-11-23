// mine-puzzles — the G3 puzzle miner (§7), 1-ply spotting tier
// (ADR-0019).
//
// A puzzle is a chart + island overlay + ONE canoe at sea (the hero)
// for the side to move; every other canoe is at home. A row ships
// only when the reconstructed overlay position satisfies BOTH:
//
//   solvable — some legal action of the side to move lands a canoe
//              (a landing ends the game; there is no defense at this
//              depth), and
//   unique   — exactly ONE legal action lands (the solver must spot
//              the one ride; a second landing action would make the
//              puzzle ambiguous).
//
// Phase 1 collects island layouts from seeded random-legal playouts.
// Phase 2 pairs each layout with hero cells near the rival atoll and
// verifies the reconstructed position by enumerating ALL legal
// actions of the mover (not just sails — an island placement or a
// second hero would also land) and counting the landing actions.
//
// Islands are emitted MINUS the chart's preIslands (the loader
// re-adds them via Reducer.initial). Every emitted row is
// re-verified before the file is written, and MTContent's loader
// tests re-verify the shipped file independently.

import Foundation
import MTContent
import MTAI
import MTCore

// MARK: - Overlay reconstruction (mirrors MTContent.Loader.puzzleState)

func overlayState(
    chart: Chart, extraIslands: Set<Hex>, heroOwner: PlayerID, heroAt: Hex
) -> GameState? {
    var state = Reducer.initial(chart: chart)
    for cell in extraIslands.sorted(by: Hex.rowMajor) {
        guard let (next, _) = try? Reducer.apply(.placeIsland(cell), to: state) else {
            return nil
        }
        state = next
    }
    guard state.field.strength(at: heroAt) >= 1,
        !state.isOccupied(heroAt), !chart.atollCells.contains(heroAt)
    else { return nil }
    guard
        let id = CanoeID.allCanoeIDs.first(where: {
            state.canoe($0).owner == heroOwner && state.canoe($0).location == .home
        })
    else { return nil }
    state.canoes[id] = CanoeState(owner: heroOwner, location: .sea(heroAt), becalmed: false)
    return state
}

// MARK: - 1-ply verification (ADR-0019)

/// The landing actions available to the side to move.
func landingActions(in state: GameState) -> [Action] {
    Reducer.legalActions(in: state).filter { action in
        guard let (after, events) = try? Reducer.apply(action, to: state) else {
            return false
        }
        let landed = events.contains { event in
            if case .landed = event { return true }
            return false
        }
        return landed
            && after.landed[state.toMove, default: 0] > state.landed[state.toMove, default: 0]
    }
}

// MARK: - Phase 1: layout collection

/// Island layouts sampled from seeded random-legal playouts. A layout
/// is the full island set at the sampling ply (including preIslands —
/// the caller subtracts them).
func collectLayouts(chart: Chart, games: Int, seed: UInt64, samplePlies: Set<Int>) -> [Set<Hex>] {
    var rng = SeededRNG(seed: seed)
    var layouts: [Set<Hex>] = []
    for _ in 0..<games {
        var state = Reducer.initial(chart: chart)
        var ply = 0
        while ply < 40, !state.status.isOver {
            if samplePlies.contains(ply) {
                layouts.append(state.islands)
            }
            let actions = Reducer.legalActions(in: state)
            let nonPass = actions.filter { !$0.isPass }
            guard let pick = (nonPass.isEmpty ? actions.first : nonPass.randomElement(&rng)) else {
                break
            }
            guard let (next, _) = try? Reducer.apply(pick, to: state) else { break }
            state = next
            ply += 1
        }
    }
    return layouts
}

extension Array {
    /// Deterministic element pick from an rng stream (banned_api: no
    /// SystemRandomNumberGenerator.randomElement()).
    func randomElement(_ rng: inout SeededRNG) -> Element? {
        guard !isEmpty else { return nil }
        return self[rng.nextInt(below: count)]
    }
}

// MARK: - Phase 2: hero pairing + verification

struct Emitted {
    var chartID: String
    var islands: Set<Hex>  // extra islands only (preIslands excluded)
    var owner: PlayerID
    var heroAt: Hex
    var twoPly: Bool
}

/// The deterministic two-ply upgrade budget: per chart, at most this
/// many plies-2 uniqueness sweeps are run (hardest candidates first).
let upgradeAttempts = 8

/// One qualifying pair: the reconstructed state, its identity key,
/// and the overlay it ships with.
struct Candidate {
    var key: String
    var state: GameState
    var owner: PlayerID
    var heroAt: Hex
    var islands: Set<Hex>
}

/// A cheap plies-2 difficulty score: the smallest defender-reply
/// count after the row's unique landing action. Fewer replies to
/// refute means a cheaper uniqueness sweep, so the miner upgrades
/// the cheapest-to-verify candidates first.
func difficulty(_ state: GameState) -> Int {
    guard let landing = landingActions(in: state).first,
        let (after, _) = try? Reducer.apply(landing, to: state)
    else { return Int.max }
    return Reducer.legalActions(in: after).count
}

func mine(chart: Chart, layouts: [Set<Hex>], budget: Int, out: inout [Emitted]) {
    var seen = Set<String>()
    let start = out.count
    var candidates: [Candidate] = []
    for owner in [PlayerID.p1, .p2] {
        let target = chart.atoll(for: owner.opponent).cells
        // Hero candidates: empty strength cells adjacent to a rival
        // atoll cell (a 1-step landing ride exists only from there).
        var heroes: [Hex] = []
        for cell in chart.ocean.allCells {
            guard !chart.atollCells.contains(cell) else { continue }
            let near = target.contains { cell.isAdjacent(to: $0) }
            if near { heroes.append(cell) }
        }
        heroes.sort(by: Hex.rowMajor)

        for (layoutIndex, layout) in layouts.enumerated() {
            let extra = layout.subtracting(chart.preIslands)
            for hero in heroes {
                guard
                    let state = overlayState(
                        chart: chart, extraIslands: extra, heroOwner: owner, heroAt: hero)
                else { continue }
                // ADR-0019: solvable AND unique at 1 ply. The plies-2
                // upgrade decision is deferred to the bounded phase
                // below (the per-pair AND/OR sweep is too expensive to
                // run inline for every qualifying pair).
                guard landingActions(in: state).count == 1 else { continue }
                let islandText = extra.sorted(by: Hex.rowMajor)
                    .map { "\($0.q),\($0.r)" }
                    .joined(separator: ";")
                let key = "\(islandText)|\(hero.q),\(hero.r)|\(owner.rawValue)"
                guard seen.insert(key).inserted else { continue }
                let candidate = Candidate(
                    key: key, state: state, owner: owner, heroAt: hero, islands: extra)
                candidates.append(candidate)
            }
            FileHandle.standardError.write(
                Data("  \(chart.id): layout \(layoutIndex + 1)/\(layouts.count) done\n".utf8))
        }
    }

    // Phase B: order the candidates — cheapest uniqueness sweep first
    // (fewest defender replies), then row-major key; no rng. Difficulty
    // is memoized before the sort: recomputing it inside the comparator
    // made the sort O(n log n) full reducer sweeps and wedged Phase C
    // for hours (2026-11-23 sample, main.swift:188).
    let difficulties = candidates.map { difficulty($0.state) }
    let order = Array(candidates.indices).sorted {
        (difficulties[$0], candidates[$0].key)
            < (difficulties[$1], candidates[$1].key)
    }
    candidates = order.map { candidates[$0] }

    // Phase C: bounded plies-2 upgrades — the top candidates get the
    // full forced-line + uniqueness sweep; the first fully-verified
    // row ships as plies 2 (one per chart keeps the run bounded and
    // the mix ply-1-dominant), the rest ship as plies 1.
    let generator = PuzzleGenerator()
    var upgrades = 0
    var attempts = 0
    FileHandle.standardError.write(
        Data(
            "  \(chart.id): \(candidates.count) candidates, plies-2 upgrade cap \(upgradeAttempts)\n"
                .utf8))
    for candidate in candidates {
        guard attempts < upgradeAttempts, upgrades == 0 else { break }
        attempts += 1
        FileHandle.standardError.write(
            Data(
                "  \(chart.id): upgrade attempt \(attempts)/\(upgradeAttempts): \(candidate.key)\n"
                    .utf8))
        let sharedMemo = PuzzleGenerator.Memo()
        let forced = generator.forcedLanding(
            in: candidate.state, owner: candidate.owner, plies: 2, memo: sharedMemo)
        let unique = forced
            && generator.winningFirstActions(
                in: candidate.state, owner: candidate.owner, plies: 2).count == 1
        FileHandle.standardError.write(
            Data(
                "  \(chart.id): plies-2 candidate \(candidate.key): forced=\(forced) unique=\(unique)\n"
                    .utf8))
        guard unique else { continue }
        out.append(
            Emitted(
                chartID: chart.id, islands: candidate.islands, owner: candidate.owner,
                heroAt: candidate.heroAt, twoPly: true))
        upgrades += 1
    }
    // Phase D: every remaining candidate ships as a ply-1 row.
    for candidate in candidates {
        if out.count - start >= budget {
            FileHandle.standardError.write(
                Data("  \(chart.id): budget reached at ply-1 emission\n".utf8))
            return
        }
        out.append(
            Emitted(
                chartID: chart.id, islands: candidate.islands, owner: candidate.owner,
                heroAt: candidate.heroAt, twoPly: false))
    }
    FileHandle.standardError.write(
        Data(
            "  \(chart.id): \(out.count - start) rows (\(upgrades) upgraded to plies 2)\n"
                .utf8))
}

extension PlayerID {
    /// The other player.
    var opponent: PlayerID { self == .p1 ? .p2 : .p1 }
}

// MARK: - Main
//
// P4 (MT-P4.2): the shipped pool is the §5 G5 count — 120 verified
// rows. Budgets per chart keep the campaign mix close to the chart
// sizes; verification is the ADR-0019 ply-1 spot check PLUS the
// PuzzleGenerator plies-2 AND/OR verifier. Rows that verify only at
// ply 1 ship as plies: 1 — but the upgrade to plies 2 is DETERMINISTIC
// and bounded (ADR-0002): per chart, the miner evaluates the plies-2
// forced-line and uniqueness conditions over at most 8 candidate rows
// (ordered by a plies-2 difficulty score, then the row-major overlay
// key, no rng), and ships a plies-2 row only after the winner's full
// uniqueness sweep; further candidates keep shipping as plies-1 rows.
// Without the cap the uniqueness sweep (~150 first actions × ~150
// replies each) runs for every qualifying pair and the G4 run cannot
// finish.

let charts = try ContentLoader.charts()
FileHandle.standardError.write(
    Data("CHART IDS: \(charts.map { $0.id })\n".utf8))
let only: String? = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : nil
let chartsToMine = only.map { id in
    guard let chart = charts.first(where: { $0.id == id }) else {
        FileHandle.standardError.write(Data("no chart named \(id)\n".utf8))
        exit(2)
    }
    return [chart]
} ?? charts
let budgets: [String: Int] = [
    "two_swells_basic": 40,
    "single_swell": 25,
    "crossroads": 30,
    "lagoon_mirror": 25,
]
let totalBudget = budgets.values.reduce(0, +)
precondition(totalBudget >= 120, "the G5 pool is 120 rows")

var emitted: [Emitted] = []
for chart in chartsToMine {
    let budget = budgets[chart.id] ?? 30
    // Layouts: sampled across ply windows of many seeded games. The
    // larger budget needs more layouts; the count scales with it.
    let games = 200
    var layouts = collectLayouts(
        chart: chart, games: games, seed: seedFor(chart.id),
        samplePlies: [3, 4, 5, 6, 7, 8, 9, 10])
    layouts += collectLayouts(
        chart: chart, games: games, seed: seedFor(chart.id) + 17,
        samplePlies: [5, 7, 9, 11, 13, 15])
    layouts += collectLayouts(
        chart: chart, games: games, seed: seedFor(chart.id) + 41,
        samplePlies: [4, 6, 8, 10, 12, 14, 16])
    mine(chart: chart, layouts: layouts, budget: budget, out: &emitted)
    FileHandle.standardError.write(Data("mined \(chart.id): \(emitted.count) total so far\n".utf8))
}

func seedFor(_ id: String) -> UInt64 {
    switch id {
    case "two_swells_basic": return 4001
    case "single_swell": return 4002
    case "crossroads": return 4003
    case "lagoon_mirror": return 4004
    default: return 4099
    }
}

// Emit rows.
struct Row: Encodable {
    var id: String
    var chart: String
    var islands: [[Int]]
    var canoes: [[String]]
    var toMove: String
    var goal: String
    var plies: Int
}

var rows: [Row] = []
var verified = 0
for (index, e) in emitted.enumerated() {
    let chart = charts.first(where: { $0.id == e.chartID })!
    // Final re-verification of the exact emitted overlay: the ply-1
    // spot check (always), and for twoPly rows the plies-2 AND/OR
    // verifier again on the final overlay.
    guard
        let state = overlayState(
            chart: chart, extraIslands: e.islands, heroOwner: e.owner, heroAt: e.heroAt),
        landingActions(in: state).count == 1
    else {
        print("VERIFY FAIL: \(e.chartID) \(e.owner) \(e.heroAt) — dropped")
        continue
    }
    if e.twoPly {
        let generator = PuzzleGenerator()
        guard
            generator.forcedLanding(in: state, owner: e.owner, plies: 2, memo: PuzzleGenerator.Memo()),
            generator.winningFirstActions(in: state, owner: e.owner, plies: 2).count == 1
        else {
            print("VERIFY FAIL (plies 2): \(e.chartID) \(e.owner) \(e.heroAt) — ships as plies 1")
            continue
        }
    }
    verified += 1
    rows.append(
        Row(
            id: String(format: "mt_p%03d", index + 1),
            chart: e.chartID,
            islands: e.islands.map { [$0.q, $0.r] }
                .sorted { ($0[1], $0[0]) < ($1[1], $1[0]) },
            canoes: [[e.owner.rawValue, "\(e.heroAt.q)", "\(e.heroAt.r)"]],
            toMove: e.owner.rawValue,
            goal: "land_in",
            plies: e.twoPly ? 2 : 1))
}

let twoPlyCount = rows.filter { $0.plies == 2 }.count
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let rowsJSON = String(data: try encoder.encode(rows), encoding: .utf8)!
let file = """
    {
      "schema_version": 1,
      "game": "06-mattang",
      "puzzles": \(rowsJSON)
    }
    """
try file.write(
    to: URL(fileURLWithPath: "puzzles_mined.json"), atomically: true, encoding: .utf8)
print("emitted \(emitted.count), verified \(verified) (plies-2 rows: \(twoPlyCount))")
for (chartID, count) in Dictionary(grouping: rows, by: \.chart).mapValues(\.count) {
    print("  \(chartID): \(count)")
}
