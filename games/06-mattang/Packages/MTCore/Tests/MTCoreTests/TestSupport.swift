// TestSupport.swift — charts, builders, and the seeded playout harness
// shared by the P1 rule, fixture, and invariant tests.
//
// Charts here are built in code from the roadmap's geometry (R-1: a
// hex ocean, one 3-cell home atoll per player on opposite edges,
// swells entering from an entry side and travelling straight in).
// Every builder is deterministic; no test constructs a chart with
// SystemRandomness.

import XCTest

@testable import MTCore

/// Unwraps an optional or fails loudly with `why` — the test-suite
/// replacement for force unwraps (no `!` anywhere in tests).
func require<T>(_ value: T?, _ why: @autoclosure () -> String = "unexpected nil") -> T {
    guard let value else { preconditionFailure(why()) }
    return value
}

/// Deterministic test charts.
enum TestCharts {
    /// Atolls off row 0 so straight swell rows stay clear for fixtures.
    /// P1 sits on the west rim, P2 on the east rim, rotate180 images.
    static func atolls(radius: Int) -> [Atoll] {
        let r = radius
        let p1 = Atoll(
            player: .p1,
            cells: [
                Hex(-r, 1), Hex(-r, 2), Hex(-r + 1, 2),
            ])
        let p2 = Atoll(
            player: .p2,
            cells: [
                Hex(r, -1), Hex(r, -2), Hex(r - 1, -2),
            ])
        return [p1, p2]
    }

    /// One dominant swell entering from the east edge travelling west
    /// (the swells.json sample shape: entrySide 0, direction 3).
    static func eastOnly(radius: Int = 5) -> Chart {
        Chart(
            id: "test_east_only", radius: radius,
            swells: [Swell.major(id: "east_dom", entrySide: 0, direction: 3)],
            preIslands: [], atolls: atolls(radius: radius), symmetry: .rotate180)
    }

    /// East major + a minor diagonal swell from the southwest edge
    /// travelling northeast: the two cross on specific diagonal cells,
    /// producing hand-computable nodes (≥ 2 distinct swells).
    static func eastAndDiagonal(radius: Int = 5) -> Chart {
        Chart(
            id: "test_east_diagonal", radius: radius,
            swells: [
                Swell.major(id: "east_dom", entrySide: 0, direction: 3),
                Swell.minor(id: "sw_ne", entrySide: 2, direction: 5),
            ],
            preIslands: [], atolls: atolls(radius: radius), symmetry: .rotate180)
    }

    /// A mirror-symmetric chart for INV-6: swells and preIslands sit on
    /// or pair across the mirror (q, r) -> (q + r, -r), and each atoll
    /// is its own mirror image straddling the east-west axis.
    static func mirrorPair(radius: Int = 5) -> Chart {
        let r = radius
        return Chart(
            id: "test_mirror", radius: radius,
            swells: [
                Swell.major(id: "east_dom", entrySide: 0, direction: 3),
                Swell.minor(id: "west_min", entrySide: 3, direction: 0),
            ],
            preIslands: [Hex(0, 0), Hex(1, 0), Hex(-1, 0)],
            atolls: [
                Atoll(player: .p1, cells: [Hex(-r, 0), Hex(-r, 1), Hex(-r + 1, -1)]),
                Atoll(player: .p2, cells: [Hex(r, 0), Hex(r, -1), Hex(r - 1, 1)]),
            ],
            symmetry: .mirror)
    }

    /// A rotate180-symmetric chart: swells and preIslands in pairs
    /// under (q, r) -> (-q, -r), with paired swells carrying equal
    /// weights so the traced field is symmetric too. Kept tie-free:
    /// R-14's row-major tie-break is not rotation-covariant, so a
    /// refraction tie would break the field symmetry (see ADR-0014).
    static func rotatePair(radius: Int = 5) -> Chart {
        Chart(
            id: "test_rotate", radius: radius,
            swells: [
                Swell.major(id: "east_dom", entrySide: 0, direction: 3),
                Swell.major(id: "west_dom", entrySide: 3, direction: 0),
            ],
            preIslands: [Hex(0, 0), Hex(2, 1), Hex(-2, -1)],
            atolls: atolls(radius: radius), symmetry: .rotate180)
    }

    /// Asserts a chart passes its own validation and the reducer can
    /// start a game on it.
    static func validated(_ chart: Chart, file: StaticString = #filePath, line: UInt = #line)
        -> Chart
    {
        XCTAssertEqual(
            chart.validate(), [], "chart \(chart.id) must validate", file: file, line: line)
        return chart
    }
}

/// The shared fixture battery: fixed island/flow configurations
/// (deterministic from SeededRNG seeds) that exercise reflection and
/// refraction together across two charts.
func fixtureBattery() -> [(seed: UInt64, chart: Chart, islands: Set<Hex>)] {
    var configs: [(UInt64, Chart, Set<Hex>)] = []
    for seed in UInt64(1)...24 {
        var rng = SeededRNG(seed: seed)
        let chart =
            seed % 2 == 0
            ? TestCharts.eastOnly()
            : TestCharts.eastAndDiagonal()
        let cells = chart.ocean.allCells
            .filter { !chart.atollCells.contains($0) }
        var islands: Set<Hex> = []
        let count = 3 + rng.nextInt(below: 4)
        for _ in 0..<count {
            islands.insert(cells[rng.nextInt(below: cells.count)])
        }
        configs.append((seed, chart, islands))
    }
    return configs
}

/// Golden-replay fixture support (S1.4): the JSON schema `Tools/sim`
/// writes, chart reconstruction, and the action-string codec both
/// sides share. A format drift fails the golden tests loudly.
enum GoldenSupport {
    struct SwellRow: Codable {
        let id: String
        let entrySide: Int
        let direction: Int
        let weight: Int
    }

    struct ChartJSON: Codable {
        let id: String
        let radius: Int
        let swells: [SwellRow]
        let preIslands: [[Int]]
        let atolls: [String: [[Int]]]
        let symmetry: String
    }

    struct Golden: Codable {
        let seed: UInt64
        let chart: ChartJSON
        let actions: [String]
        let plies: Int
        let result: String
        let finalHash: String
        let eventsHash: String
    }

    static func chart(from json: ChartJSON) -> Chart {
        let atolls: [Atoll] = ["p1", "p2"].map { key in
            let cells = Set((json.atolls[key] ?? []).map { Hex($0[0], $0[1]) })
            guard let player = PlayerID(rawValue: key) else {
                preconditionFailure("unknown chart key \(key)")
            }
            return Atoll(player: player, cells: cells)
        }
        return Chart(
            id: json.id, radius: json.radius,
            swells: json.swells.map {
                Swell(
                    id: $0.id, entrySide: $0.entrySide, direction: $0.direction, weight: $0.weight)
            },
            preIslands: Set(json.preIslands.map { Hex($0[0], $0[1]) }),
            atolls: atolls,
            symmetry: ChartSymmetry(rawValue: json.symmetry) ?? .none)
    }

    static func encode(_ action: Action) -> String {
        func cell(_ h: Hex) -> String { "\(h.q),\(h.r)" }
        func path(_ cells: [Hex]) -> String { cells.map(cell).joined(separator: ";") }
        func canoe(_ id: CanoeID) -> String { "\(id.player.rawValue)-\(id.index)" }
        switch action {
        case .placeIsland(let h): return "place \(cell(h))"
        case .launch(let h): return "launch \(cell(h))"
        case .sail(let id, let cells): return "sail \(canoe(id)) \(path(cells))"
        case .tow(let id, let h): return "tow \(canoe(id)) \(cell(h))"
        case .pass: return "pass"
        }
    }

    static func decode(_ string: String) -> Action? {
        let parts = string.split(separator: " ").map(String.init)
        func hex(_ token: String) -> Hex? {
            let coords = token.split(separator: ",").map(String.init)
            guard coords.count == 2, let q = Int(coords[0]), let r = Int(coords[1]) else {
                return nil
            }
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
            guard parts.count == 3, let id = canoe(parts[1]), let h = hex(parts[2]) else {
                return nil
            }
            return .tow(id, h)
        case "sail":
            guard parts.count == 3, let id = canoe(parts[1]), let cells = pathCells(parts[2]) else {
                return nil
            }
            return .sail(id, cells)
        case "pass": return parts.count == 1 ? .pass : nil
        default: return nil
        }
    }

    static func resultDescription(_ status: GameStatus) -> String {
        switch status {
        case .ongoing: return "ongoing"
        case .won(let p): return "won/\(p.rawValue)"
        case .tiebreak(let p): return "tiebreak/\(p.rawValue)"
        }
    }
}

/// A small extension bundle used by the rule tests.
enum TestStates {
    /// The reducer's initial state for a chart.
    static func initial(_ chart: Chart) -> GameState {
        Reducer.initial(chart: chart)
    }

    /// A state built directly for unit tests: `islands` placed, the
    /// given canoes (unlisted ones at home), a computed field.
    static func state(
        _ chart: Chart, islands: Set<Hex>, canoes: [CanoeID: CanoeState],
        pool: Int = Balance.islandPool, toMove: PlayerID = .p1, stuck: Int = 0
    ) -> GameState {
        var landed: [PlayerID: Int] = [.p1: 0, .p2: 0]
        for canoe in canoes.values {
            if case .landed = canoe.location { landed[canoe.owner, default: 0] += 1 }
        }
        let field = Field.compute(
            ocean: chart.ocean, swells: chart.swells, islands: islands,
            atollCells: chart.atollCells)
        return GameState(
            chart: chart, islands: islands, poolRemaining: pool, canoes: canoes,
            landed: landed, toMove: toMove, stuckTurns: stuck, field: field,
            status: .ongoing)
    }

    /// Canoe states: sea entries as (player, index, cell); unlisted
    /// canoes sit at home. `becalmed` flags the given ids.
    static func canoes(
        sea: [(PlayerID, Int, Hex)] = [],
        landed: [(PlayerID, Int)] = [],
        becalmed: Set<CanoeID> = []
    ) -> [CanoeID: CanoeState] {
        var states: [CanoeID: CanoeState] = [:]
        for id in CanoeID.allCanoeIDs {
            states[id] = CanoeState(owner: id.player, location: .home, becalmed: false)
        }
        for (player, index, cell) in sea {
            let id = CanoeID(player: player, index: index)
            states[id] = CanoeState(
                owner: player, location: .sea(cell), becalmed: becalmed.contains(id))
        }
        for (player, index) in landed {
            states[CanoeID(player: player, index: index)] = CanoeState(
                owner: player, location: .landed, becalmed: false)
        }
        return states
    }

    /// Applies actions, failing the test on the first illegal one.
    static func apply(
        _ action: Action, to state: GameState,
        file: StaticString = #filePath, line: UInt = #line
    ) -> (state: GameState, events: [Event]) {
        do {
            return try Reducer.apply(action, to: state)
        } catch let error as ReducerError {
            XCTFail("action \(action) illegal: \(error.reason)", file: file, line: line)
            return (state, [])
        } catch {
            XCTFail("unexpected error \(error)", file: file, line: line)
            return (state, [])
        }
    }

    /// The first legal path for a canoe, or nil.
    static func firstPath(for id: CanoeID, in state: GameState) -> [Hex]? {
        Movement.paths(for: id, in: state).first
    }

    /// A sea cell adjacent to the given atoll with strength ≥ 1.
    static func launchCell(for player: PlayerID, in state: GameState) -> Hex? {
        let atoll = state.atoll(of: player)
        for atollCell in atoll.cells.sorted(by: Hex.rowMajor) {
            for d in 0..<6 {
                let cell = atollCell.neighbor(d)
                guard state.chart.ocean.contains(cell),
                    !state.chart.atollCells.contains(cell),
                    !state.islands.contains(cell),
                    state.canoe(at: cell) == nil,
                    state.field.strength(at: cell) > Balance.becalmedStrength
                else { continue }
                return cell
            }
        }
        return nil
    }
}

/// The seeded random-legal playout harness (S1.3's engine half).
///
/// Each ply samples candidate actions deterministically from
/// `SeededRNG`, checks them with `Reducer.isLegal`, and applies the
/// first legal one through `Reducer.apply` (full validation). When
/// sampling finds nothing it falls back to the complete
/// `Reducer.legalActions` list, so a forced pass is still found and
/// "pass only when forced" (R-11) holds in the harness too.
enum Playout {
    struct Record {
        var seed: UInt64
        var chart: Chart
        var actions: [Action]
        var events: [[Event]]
        var final: GameState
    }

    /// Plays one game. Never throws: an illegal application fails the
    /// test via `XCTFail` (0 illegal states is a G1 requirement).
    static func run(
        seed: UInt64, chart: Chart, maxPlies: Int = 240,
        file: StaticString = #filePath, line: UInt = #line
    ) -> Record {
        var rng = SeededRNG(seed: seed)
        var state = Reducer.initial(chart: chart)
        var actions: [Action] = []
        var events: [[Event]] = []

        for _ in 0..<maxPlies {
            guard !state.status.isOver else { break }
            let action = chooseAction(in: state, rng: &rng)
            let (next, turn) = TestStates.apply(action, to: state, file: file, line: line)
            actions.append(action)
            events.append(turn)
            state = next
        }
        return Record(seed: seed, chart: chart, actions: actions, events: events, final: state)
    }

    /// Deterministically picks a legal action, sampling first and
    /// falling back to the full legal list.
    static func chooseAction(in state: GameState, rng: inout SeededRNG) -> Action {
        // Islands: sample a few placeable candidates.
        let candidates = state.placeableCandidates()
        if state.poolRemaining > 0, !candidates.isEmpty {
            for _ in 0..<6 {
                let cell = candidates[rng.nextInt(below: candidates.count)]
                if Reducer.isLegal(.placeIsland(cell), in: state) { return .placeIsland(cell) }
            }
        }
        // Launches: every home canoe × every atoll-neighbour cell.
        let mover = state.toMove
        for _ in state.homeCanoeIDs(owner: mover) {
            for atollCell in state.atoll(of: mover).cells.sorted(by: Hex.rowMajor) {
                for d in 0..<6 {
                    let cell = atollCell.neighbor(d)
                    if Reducer.isLegal(.launch(cell), in: state) { return .launch(cell) }
                }
            }
        }
        // Sails: a random sea canoe, a random path from the full
        // enumeration (small test charts keep this bounded).
        let sea = state.seaCanoeIDs(owner: mover)
        if !sea.isEmpty {
            let id = sea[rng.nextInt(below: sea.count)]
            let paths = Movement.paths(for: id, in: state)
            if !paths.isEmpty {
                let path = paths[rng.nextInt(below: paths.count)]
                if Reducer.isLegal(.sail(id, path), in: state) { return .sail(id, path) }
            }
        }
        // Tows: every becalmed canoe × every neighbour cell.
        for id in CanoeID.allCanoeIDs where state.canoe(id).owner == mover {
            guard case .sea(let at) = state.canoe(id).location, state.canoe(id).becalmed else {
                continue
            }
            for d in 0..<6 {
                let cell = at.neighbor(d)
                if Reducer.isLegal(.tow(id, cell), in: state) { return .tow(id, cell) }
            }
        }
        // Fall back to the complete list (a forced pass lives here).
        let all = Reducer.legalActions(in: state)
        if let picked = all.first(where: { Reducer.isLegal($0, in: state) }) {
            return picked
        }
        return .pass
    }

    /// INV-3: home + sea + landed must equal `Balance.canoesPerPlayer`
    /// for both players in every state.
    static func assertCanoeCounts(
        _ state: GameState, file: StaticString = #filePath, line: UInt = #line
    ) {
        for player in PlayerID.allCases {
            let home = state.homeCanoeIDs(owner: player).count
            let sea = state.seaCanoeIDs(owner: player).count
            let landed = state.landed[player, default: 0]
            XCTAssertEqual(
                home + sea + landed, Balance.canoesPerPlayer,
                "\(player) canoe count conservation (INV-3)",
                file: file, line: line)
        }
    }
}
