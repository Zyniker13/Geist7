// main.swift — the headless Mattang simulator (S1.3).
//
// Plays random-legal-move games from a seed and prints a per-game
// summary and a total hash. Two runs with the same arguments print
// byte-identical output (the G1 determinism check). With --golden it
// writes the first K games' full action lists as JSON fixtures for
// the golden-replay tests (S1.4).
//
// Every game is also the vehicle for the G1 invariant sweep: each ply
// checks INV-3 (canoe count conservation) and INV-2/INV-5 (the state's
// incrementally maintained field equals a full retrace whose rays all
// terminate within the step and reflection caps); every 6th ply and
// the final state additionally check INV-1 (a retrace with the swells
// in reverse order produces the same field); and every game is
// replayed from its recorded actions and must reproduce the final
// state (INV-4). Any violation exits 1.
//
// Usage:
//   sim [--count N] [--seed S] [--chart east|diagonal|mirror|rotate]
//       [--max-plies P] [--golden K --out DIR]
//
// Exit status: 0 when every game applied only legal actions and every
// invariant check passed; 1 on the first illegal state, replay
// divergence, or crash.

import Foundation
import MTCore

// MARK: - Charts (mirrors the test builders; golden JSONs carry the
// full chart parameters so tests rebuild charts from data, not code)

struct SimChart {
    var id: String
    var radius: Int
    var swells: [Swell]
    var preIslands: Set<Hex>
    var atolls: [Atoll]
    var symmetry: ChartSymmetry

    var chart: Chart {
        Chart(
            id: id, radius: radius, swells: swells, preIslands: preIslands,
            atolls: atolls, symmetry: symmetry)
    }

    static func atolls(radius: Int) -> [Atoll] {
        let r = radius
        return [
            Atoll(player: .p1, cells: [Hex(-r, 1), Hex(-r, 2), Hex(-r + 1, 2)]),
            Atoll(player: .p2, cells: [Hex(r, -1), Hex(r, -2), Hex(r - 1, -2)]),
        ]
    }

    static func east(radius: Int = 5) -> SimChart {
        SimChart(
            id: "test_east_only", radius: radius,
            swells: [Swell.major(id: "east_dom", entrySide: 0, direction: 3)],
            preIslands: [], atolls: atolls(radius: radius), symmetry: .rotate180)
    }

    static func diagonal(radius: Int = 5) -> SimChart {
        SimChart(
            id: "test_east_diagonal", radius: radius,
            swells: [
                Swell.major(id: "east_dom", entrySide: 0, direction: 3),
                Swell.minor(id: "sw_ne", entrySide: 2, direction: 5),
            ],
            preIslands: [], atolls: atolls(radius: radius), symmetry: .rotate180)
    }

    static func mirror(radius: Int = 5) -> SimChart {
        SimChart(
            id: "test_mirror", radius: radius,
            swells: [
                Swell.major(id: "east_dom", entrySide: 0, direction: 3),
                Swell.minor(id: "west_min", entrySide: 3, direction: 0),
            ],
            preIslands: [Hex(0, 0), Hex(1, 0), Hex(-1, 0)],
            atolls: [
                Atoll(player: .p1, cells: [Hex(-5, -1), Hex(-5, 0), Hex(-5, 1)]),
                Atoll(player: .p2, cells: [Hex(5, -1), Hex(5, 0), Hex(5, 1)]),
            ],
            symmetry: .mirror)
    }

    static func rotate(radius: Int = 5) -> SimChart {
        SimChart(
            id: "test_rotate", radius: radius,
            swells: [
                Swell.major(id: "east_dom", entrySide: 0, direction: 3),
                Swell.minor(id: "sw_ne", entrySide: 2, direction: 5),
                Swell.minor(id: "sw_sw", entrySide: 5, direction: 2),
            ],
            preIslands: [Hex(0, 0), Hex(2, 1), Hex(-2, -1)],
            atolls: atolls(radius: radius), symmetry: .rotate180)
    }

    static func named(_ name: String) -> SimChart {
        switch name {
        case "east": return .east()
        case "diagonal": return .diagonal()
        case "mirror": return .mirror()
        case "rotate": return .rotate()
        default: fatalError("unknown chart: \(name)")
        }
    }
}

// MARK: - Action strings (the golden-replay fixture format)

func encodeCell(_ h: Hex) -> String { "\(h.q),\(h.r)" }

func encode(_ action: Action) -> String {
    func path(_ cells: [Hex]) -> String { cells.map(encodeCell).joined(separator: ";") }
    func canoe(_ id: CanoeID) -> String { "\(id.player.rawValue)-\(id.index)" }
    switch action {
    case .placeIsland(let h): return "place \(encodeCell(h))"
    case .launch(let h): return "launch \(encodeCell(h))"
    case .sail(let id, let cells): return "sail \(canoe(id)) \(path(cells))"
    case .tow(let id, let h): return "tow \(canoe(id)) \(encodeCell(h))"
    case .pass: return "pass"
    }
}

func decode(_ string: String) -> Action? {
    let parts = string.split(separator: " ").map(String.init)
    func hex(_ token: String) -> Hex? {
        let coords = token.split(separator: ",").map(String.init)
        guard coords.count == 2, let q = Int(coords[0]), let r = Int(coords[1]) else { return nil }
        return Hex(q, r)
    }
    func canoe(_ token: String) -> CanoeID? {
        let halves = token.split(separator: "-").map(String.init)
        guard halves.count == 2, let index = Int(halves[1]) else { return nil }
        return PlayerID(rawValue: halves[0]).map { CanoeID(player: $0, index: index) }
    }
    func pathCells(_ token: String) -> [Hex]? {
        guard !token.isEmpty else { return [] }
        var cells: [Hex] = []
        for piece in token.split(separator: ";") {
            guard let h = hex(String(piece)) else { return nil }
            cells.append(h)
        }
        return cells
    }
    guard !parts.isEmpty else { return nil }
    switch parts[0] {
    case "place": return parts.count == 2 ? hex(parts[1]).map { Action.placeIsland($0) } : nil
    case "launch": return parts.count == 2 ? hex(parts[1]).map { Action.launch($0) } : nil
    case "tow":
        guard parts.count == 3, let id = canoe(parts[1]), let h = hex(parts[2]) else { return nil }
        return .tow(id, h)
    case "sail":
        guard parts.count == 3, let id = canoe(parts[1]), let cells = pathCells(parts[2]) else { return nil }
        return .sail(id, cells)
    case "pass": return parts.count == 1 ? .pass : nil
    default: return nil
    }
}

// MARK: - Invariant verification (G1: INV-1…INV-5 over every seed)

struct InvariantStats {
    var plies = 0
    var fieldChecks = 0
    var orderChecks = 0
    var replays = 0
}

func fail(_ why: String) -> Never {
    FileHandle.standardError.write(Data("INVARIANT: \(why)\n".utf8))
    exit(1)
}

/// INV-3: the canoe registry holds exactly two players' worth, and
/// home + sea + landed is constant per player.
func verifyCounts(_ state: GameState) {
    guard state.canoes.count == 2 * Balance.canoesPerPlayer else {
        fail("INV-3: canoe registry holds \(state.canoes.count) canoes")
    }
    for player in PlayerID.allCases {
        let home = state.homeCanoeIDs(owner: player).count
        let sea = state.seaCanoeIDs(owner: player).count
        let landed = state.landed[player, default: 0]
        guard home + sea + landed == Balance.canoesPerPlayer else {
            fail("INV-3: \(player) has home=\(home) sea=\(sea) landed=\(landed)")
        }
    }
}

/// INV-2: the state's incrementally maintained field equals a full
/// retrace. INV-5: every ray of that retrace terminates within the
/// step and reflection caps. With `checkOrder`, INV-1: a retrace with
/// the swells in reverse order produces the same field.
func verifyField(
    _ state: GameState, simChart: SimChart, checkOrder: Bool,
    stats: inout InvariantStats
) {
    stats.fieldChecks += 1
    let chart = simChart.chart
    let full = Field.compute(
        ocean: chart.ocean, swells: chart.swells, islands: state.islands,
        atollCells: chart.atollCells)
    guard full == state.field else {
        fail("INV-2: incremental field differs from the full retrace")
    }
    for ray in full.rays {
        guard ray.cells.count - 1 <= 40 else {
            fail("INV-5: swell \(ray.swell) ray ran \(ray.cells.count - 1) steps")
        }
        guard ray.reflections <= Balance.maxReflections else {
            fail("INV-5: swell \(ray.swell) ray reflected \(ray.reflections) times")
        }
    }
    guard checkOrder else { return }
    stats.orderChecks += 1
    let reversed = SimChart(
        id: simChart.id, radius: simChart.radius,
        swells: Array(simChart.swells.reversed()),
        preIslands: simChart.preIslands, atolls: simChart.atolls,
        symmetry: simChart.symmetry)
    let other = reversed.chart
    let mirrored = Field.compute(
        ocean: other.ocean, swells: other.swells, islands: state.islands,
        atollCells: other.atollCells)
    for cell in chart.ocean.allCells {
        guard full.swells(at: cell) == mirrored.swells(at: cell),
            full.strength(at: cell) == mirrored.strength(at: cell)
        else {
            fail("INV-1: reversed-swell retrace differs at q=\(cell.q) r=\(cell.r)")
        }
    }
    guard full.nodes == mirrored.nodes else {
        fail("INV-1: reversed-swell retrace differs on nodes")
    }
    guard Set(full.rays) == Set(mirrored.rays) else {
        fail("INV-1: reversed-swell retrace differs on rays")
    }
}

// MARK: - Seeded random-legal playout

struct SimRecord {
    var seed: UInt64
    var actions: [String]
    var plays: [Action]
    var final: GameState
}

func chooseAction(in state: GameState, rng: inout SeededRNG) -> Action {
    let candidates = state.placeableCandidates()
    if state.poolRemaining > 0, !candidates.isEmpty {
        for _ in 0..<6 {
            let cell = candidates[rng.nextInt(below: candidates.count)]
            if Reducer.isLegal(.placeIsland(cell), in: state) { return .placeIsland(cell) }
        }
    }
    let mover = state.toMove
    for _ in state.homeCanoeIDs(owner: mover) {
        for atollCell in state.atoll(of: mover).cells.sorted(by: Hex.rowMajor) {
            for d in 0..<6 {
                let cell = atollCell.neighbor(d)
                if Reducer.isLegal(.launch(cell), in: state) { return .launch(cell) }
            }
        }
    }
    let sea = state.seaCanoeIDs(owner: mover)
    if !sea.isEmpty {
        let id = sea[rng.nextInt(below: sea.count)]
        let paths = Movement.paths(for: id, in: state)
        if !paths.isEmpty {
            let path = paths[rng.nextInt(below: paths.count)]
            if Reducer.isLegal(.sail(id, path), in: state) { return .sail(id, path) }
        }
    }
    for id in CanoeID.allCanoeIDs where state.canoe(id).owner == mover {
        guard case .sea(let at) = state.canoe(id).location, state.canoe(id).becalmed else {
            continue
        }
        for d in 0..<6 {
            let cell = at.neighbor(d)
            if Reducer.isLegal(.tow(id, cell), in: state) { return .tow(id, cell) }
        }
    }
    let all = Reducer.legalActions(in: state)
    return all.first ?? .pass
}

func run(
    seed: UInt64, simChart: SimChart, maxPlies: Int, stats: inout InvariantStats
) -> SimRecord? {
    let chart = simChart.chart
    var rng = SeededRNG(seed: seed)
    var state = Reducer.initial(chart: chart)
    var actions: [String] = []
    var plays: [Action] = []
    var ply = 0
    for _ in 0..<maxPlies {
        guard !state.status.isOver else { break }
        let action = chooseAction(in: state, rng: &rng)
        do {
            let (next, _) = try Reducer.apply(action, to: state)
            actions.append(encode(action))
            plays.append(action)
            state = next
            ply += 1
            verifyCounts(state)
            stats.plies += 1
            verifyField(
                state, simChart: simChart, checkOrder: ply % 6 == 0, stats: &stats)
        } catch let error as ReducerError {
            FileHandle.standardError.write(Data("ILLEGAL: \(action) — \(error.reason)\n".utf8))
            return nil
        } catch {
            FileHandle.standardError.write(Data("ERROR: \(error)\n".utf8))
            return nil
        }
    }
    verifyCounts(state)
    verifyField(state, simChart: simChart, checkOrder: true, stats: &stats)
    return SimRecord(seed: seed, actions: actions, plays: plays, final: state)
}

// MARK: - Golden JSON

struct SwellRowJSON: Codable {
    var id: String
    var entrySide: Int
    var direction: Int
    var weight: Int
}

struct GoldenChartJSON: Codable {
    var id: String
    var radius: Int
    var swells: [SwellRowJSON]
    var preIslands: [[Int]]
    var atolls: [String: [[Int]]]
    var symmetry: String
}

struct GoldenJSON: Codable {
    var seed: UInt64
    var chart: GoldenChartJSON
    var actions: [String]
    var plies: Int
    var result: String
    var finalHash: String
    var eventsHash: String
}

func resultDescription(_ status: GameStatus) -> String {
    switch status {
    case .ongoing: return "ongoing"
    case .won(let p): return "won/\(p.rawValue)"
    case .tiebreak(let p): return "tiebreak/\(p.rawValue)"
    }
}

func goldenChartJSON(_ simChart: SimChart) -> GoldenChartJSON {
    var atolls: [String: [[Int]]] = [:]
    for atoll in simChart.atolls {
        atolls[atoll.player.rawValue] = atoll.cells.sorted(by: Hex.rowMajor).map { [$0.q, $0.r] }
    }
    return GoldenChartJSON(
        id: simChart.id, radius: simChart.radius,
        swells: simChart.swells.map {
            SwellRowJSON(
                id: $0.id, entrySide: $0.entrySide,
                direction: $0.direction, weight: $0.weight)
        },
        preIslands: simChart.preIslands.sorted(by: Hex.rowMajor).map { [$0.q, $0.r] },
        atolls: atolls, symmetry: simChart.symmetry.rawValue)
}

func combine(_ a: UInt64, _ b: UInt64) -> UInt64 {
    var input: [UInt8] = []
    input.append(contentsOf: withUnsafeBytes(of: a.bigEndian) { Array($0) })
    input.append(contentsOf: withUnsafeBytes(of: b.bigEndian) { Array($0) })
    return FNV1a64.hash(input)
}

// MARK: - Entry point

let arguments = Array(CommandLine.arguments.dropFirst())
func argument(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}

let count = Int(argument("--count") ?? "200") ?? 200
let baseSeed = UInt64(argument("--seed") ?? "1") ?? 1
let maxPlies = Int(argument("--max-plies") ?? "240") ?? 240
let chartName = argument("--chart") ?? "diagonal"
let goldenCount = argument("--golden").flatMap { Int($0) } ?? 0
let outDir = argument("--out") ?? "goldens"

var stats = InvariantStats()

let simChart = SimChart.named(chartName)
precondition(simChart.chart.validate().isEmpty, "sim chart must validate")

var tally = (p1: 0, p2: 0, ongoing: 0)
var plySum = 0
var plyCounts: [Int] = []
var actionMix = ["place": 0, "launch": 0, "sail": 0, "tow": 0, "pass": 0]
var runningHash = FNV1a64.offsetBasis

print("sim: chart=\(simChart.id) games=\(count) seed0=\(baseSeed) maxPlies=\(maxPlies)")
for game in 0..<count {
    let seed = baseSeed &+ UInt64(game)
    guard let record = run(seed: seed, simChart: simChart, maxPlies: maxPlies, stats: &stats)
    else {
        FileHandle.standardError.write(Data("sim: aborting\n".utf8))
        exit(1)
    }
    // INV-4: replaying the recorded actions from the same initial
    // state must reproduce the final state exactly.
    var replay = Reducer.initial(chart: simChart.chart)
    do {
        for action in record.plays {
            let (next, _) = try Reducer.apply(action, to: replay)
            replay = next
        }
    } catch {
        FileHandle.standardError.write(Data("sim: replay failed: \(error)\n".utf8))
        exit(1)
    }
    guard replay == record.final else {
        fail("INV-4: replay diverged from the recorded final state")
    }
    stats.replays += 1
    let hash: UInt64
    do {
        hash = try StateHashing.stableHash(record.final)
    } catch {
        FileHandle.standardError.write(Data("sim: hashing failed: \(error)\n".utf8))
        exit(1)
    }
    let eventsHash = FNV1a64.hash(record.actions.joined(separator: "|"))
    runningHash = combine(runningHash, hash)
    switch record.final.status {
    case .won(.p1), .tiebreak(.p1): tally.p1 += 1
    case .won(.p2), .tiebreak(.p2): tally.p2 += 1
    case .ongoing: tally.ongoing += 1
    }
    let plies = record.actions.count
    plySum += plies
    plyCounts.append(plies)
    for action in record.actions {
        let verb = action.split(separator: " ").first.map(String.init) ?? "?"
        actionMix[verb, default: 0] += 1
    }
    print(
        "game \(game + 1) seed=\(seed) plies=\(plies) result=\(resultDescription(record.final.status)) hash=\(hash)")
    if game < goldenCount {
        let golden = GoldenJSON(
            seed: seed, chart: goldenChartJSON(simChart), actions: record.actions,
            plies: plies, result: resultDescription(record.final.status),
            finalHash: String(format: "%016llx", hash),
            eventsHash: String(format: "%016llx", eventsHash))
        do {
            let data = try JSONEncoder().encode(golden)
            let path = "\(outDir)/mt_golden_\(String(format: "%02d", game + 1)).json"
            try data.write(to: URL(fileURLWithPath: path))
            print("golden written: \(path)")
        } catch {
            FileHandle.standardError.write(Data("sim: golden write failed: \(error)\n".utf8))
            exit(1)
        }
    }
}

plyCounts.sort()
let median = plyCounts.isEmpty ? 0 : plyCounts[plyCounts.count / 2]
let mean = plyCounts.isEmpty ? 0.0 : Double(plySum) / Double(plyCounts.count)
print(
    """
    summary games=\(count) p1_wins=\(tally.p1) p2_wins=\(tally.p2) ongoing=\(tally.ongoing) \
    median_plies=\(median) mean_plies=\(String(format: "%.2f", mean)) \
    islands=\(actionMix["place"] ?? 0) launches=\(actionMix["launch"] ?? 0) \
    sails=\(actionMix["sail"] ?? 0) tows=\(actionMix["tow"] ?? 0) passes=\(actionMix["pass"] ?? 0)
    """)
print("total_hash=\(runningHash)")
print(
    "invariants plies=\(stats.plies) field_checks=\(stats.fieldChecks) "
        + "order_checks=\(stats.orderChecks) replays=\(stats.replays)")
