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
}

func mine(chart: Chart, layouts: [Set<Hex>], budget: Int, out: inout [Emitted]) {
    var seen = Set<String>()
    let start = out.count
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

        for layout in layouts {
            let extra = layout.subtracting(chart.preIslands)
            for hero in heroes {
                guard
                    let state = overlayState(
                        chart: chart, extraIslands: extra, heroOwner: owner, heroAt: hero)
                else { continue }
                // ADR-0019: solvable AND unique at 1 ply.
                let landings = landingActions(in: state)
                guard landings.count == 1 else { continue }
                let key =
                    "\(extra.sorted(by: Hex.rowMajor).map { "\($0.q),\($0.r)" })|\(hero.q),\(hero.r)|\(owner.rawValue)"
                guard seen.insert(key).inserted else { continue }
                out.append(
                    Emitted(chartID: chart.id, islands: extra, owner: owner, heroAt: hero))
                if out.count - start >= budget { return }
            }
        }
    }
}

extension PlayerID {
    /// The other player.
    var opponent: PlayerID { self == .p1 ? .p2 : .p1 }
}

// MARK: - Main

let charts = try ContentLoader.charts()
let budgets: [String: Int] = [
    "two_swells_basic": 9,
    "single_swell": 6,
    "crossroads": 8,
    "lagoon_mirror": 7,
]

var emitted: [Emitted] = []
for chart in charts {
    let budget = budgets[chart.id] ?? 7
    // Layouts: sampled from six ply windows across 60 seeded games,
    // three independent seeds per chart (early-game boards mostly).
    var layouts = collectLayouts(
        chart: chart, games: 60, seed: seedFor(chart.id),
        samplePlies: [3, 4, 5, 6, 7, 8, 9, 10])
    layouts += collectLayouts(
        chart: chart, games: 60, seed: seedFor(chart.id) + 17,
        samplePlies: [5, 7, 9, 11, 13, 15])
    layouts += collectLayouts(
        chart: chart, games: 60, seed: seedFor(chart.id) + 41,
        samplePlies: [4, 6, 8, 10, 12, 14, 16])
    mine(chart: chart, layouts: layouts, budget: budget, out: &emitted)
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
    // Final re-verification of the exact emitted overlay.
    guard
        let state = overlayState(
            chart: chart, extraIslands: e.islands, heroOwner: e.owner, heroAt: e.heroAt),
        landingActions(in: state).count == 1
    else {
        print("VERIFY FAIL: \(e.chartID) \(e.owner) \(e.heroAt) — dropped")
        continue
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
            plies: 1))
}

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
print("emitted \(emitted.count), verified \(verified)")
for (chartID, count) in Dictionary(grouping: rows, by: \.chart).mapValues(\.count) {
    print("  \(chartID): \(count)")
}
