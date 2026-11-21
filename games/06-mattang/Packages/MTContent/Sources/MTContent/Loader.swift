// Loader.swift — the G3 content tables, decoded from the bundled JSON.
//
// P2 shipped the slice chart only (SliceGame). P3 opens the whole
// content surface: every chart in charts.json, the voyage campaign,
// the tutorial script, and the puzzle set, all through one loader.
// Chart rows reuse SliceGame.buildChart's construction and validation;
// the puzzle/voyage/tutorial rows are plain decode-plus-check.
//
// Puzzle `start` states are stored compactly as an atoll-pair +
// island/canoe overlay applied over the referenced chart's initial
// state (ADR-0018), instead of the full byte-stable GameState encoding
// (ADR-0009) — the overlay is human-editable, stays stable while
// GameState evolves, and the loader reconstructs the full state from
// the chart through Reducer.initial plus a validated action replay.
//
// Every swell id is resolved against swells.json; an unknown id in any
// chart row fails the load of that row, not the bundle.

import Foundation
import MTCore

/// Errors thrown when bundled content is missing, malformed, or
/// internally inconsistent. Re-exported shape of SliceGameError for
/// the general tables.
public enum ContentError: Error, Equatable {
    case missingResource(String)
    case malformedJSON(String, String)
    case unknownChart(String)
    case unknownSwell(String, String)
    case malformedAtoll(String)
    case invalidChart(String)
    case invalidPuzzle(String, String)
    case invalidVoyage(String, String)
    case invalidLesson(String, String)
}

/// One voyage of the solo campaign (§5 voyages.json sample row:
/// `{ "id": "v01", "chart": "two_swells_basic", "opponent":
/// "navigator", "lesson": "reflection" }`).
public struct VoyageDef: Decodable, Sendable, Hashable {
    public var id: String
    public var chart: String
    public var opponent: String
    public var lesson: String?
    public var title: String?
}

/// One tutorial lesson: the reference to the scripted board it plays
/// on, plus the steps the UI walks through (MT-P3.2, pillar 3).
public struct LessonDef: Decodable, Sendable, Hashable {
    public var id: String
    public var chart: String
    public var title: String
    /// Ordered scripted steps; the tutorial UI executes them in order.
    public var steps: [LessonStepDef]
}

/// One step of a lesson script (pillar 3: "one island, one swell,
/// then more").
public struct LessonStepDef: Decodable, Sendable, Hashable {
    public enum Kind: String, Decodable, Sendable, Hashable {
        case placeIsland = "place_island"
        case highlightNodes = "highlight_nodes"
        case launch
        case sail
        case complete
    }

    public var kind: Kind
    /// For placeIsland: the cell (axial [q, r]).
    public var cell: [Int]?
    /// For launch: the launch cell adjacent to the home atoll.
    public var launchCell: [Int]?
    /// For sail: the ordered cells the canoe enters.
    public var path: [[Int]]?
    /// Narration shown while the step is live.
    public var text: String
}

/// A puzzle definition (§5 sample row: `{ "id": "mt_p001", "start":
/// "<GameState>", "goal": "land_in", "plies": 2 }`). The start is an
/// overlay over a chart (ADR-0018).
public struct PuzzleDef: Decodable, Sendable, Hashable {
    public var id: String
    public var chart: String
    /// Pre-placed islands (axial [q, r] rows).
    public var islands: [[Int]]
    /// A canoe already at sea: `{"owner": "p1", "at": [q, r]}`.
    public var canoes: [PuzzleCanoeDef]
    /// The side to move.
    public var toMove: String
    /// Goal kind; "land_in" requires the mover to land a canoe within
    /// `plies` of their own moves.
    public var goal: String
    /// Moves (plies) allotted to the mover.
    public var plies: Int
}

/// A canoe in a puzzle's start overlay. Decodes both the verbose
/// `{"owner": "p1", "at": [q, r]}` form and the miner's compact
/// `["p1", q, r]` triple.
public struct PuzzleCanoeDef: Decodable, Sendable, Hashable {
    public var owner: String
    public var at: [Int]

    public init(owner: String, at: [Int]) {
        self.owner = owner
        self.at = at
    }

    public init(from decoder: Decoder) throws {
        // A keyed container means the verbose dict form; an unkeyed
        // one means the miner's compact triple.
        if let dict = try? decoder.container(keyedBy: DictKeys.self) {
            owner = try dict.decode(String.self, forKey: .owner)
            at = try dict.decode([Int].self, forKey: .at)
        } else {
            var triple = try decoder.unkeyedContainer()
            owner = try triple.decode(String.self)
            let q = try triple.decode(Int.self)
            let r = try triple.decode(Int.self)
            at = [q, r]
        }
    }

    struct TripleKeys: CodingKey {
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
        var stringValue: String
        init(stringValue: String) { self.stringValue = stringValue }
        static let owner = TripleKeys(stringValue: "0")
        static let q = TripleKeys(stringValue: "1")
        static let r = TripleKeys(stringValue: "2")
    }

    struct DictKeys: CodingKey {
        static let owner = DictKeys(stringValue: "owner")
        static let at = DictKeys(stringValue: "at")
        var stringValue: String
        init(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }
}

struct PuzzlesFile: Decodable {
    var schemaVersion: Int
    var game: String
    var puzzles: [PuzzleDef]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case game, puzzles
    }
}

struct VoyagesFile: Decodable {
    var schemaVersion: Int
    var game: String
    var voyages: [VoyageDef]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case game, voyages
    }
}

struct TutorialFile: Decodable {
    var schemaVersion: Int
    var game: String
    var lessons: [LessonDef]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case game, lessons
    }
}

/// The G3 content surface: every chart, the voyage campaign, the
/// tutorial script, and the puzzle set.
public enum ContentLoader {
    // MARK: - Tables

    public static func swellDefs() throws -> [SwellDef] {
        try decode("swells.json", SwellsFile.self).swells
    }

    public static func chartDefs() throws -> [ChartDef] {
        try decode("charts.json", ChartsFile.self).charts
    }

    public static func puzzleDefs() throws -> [PuzzleDef] {
        try decode("puzzles.json", PuzzlesFile.self).puzzles
    }

    public static func voyageDefs() throws -> [VoyageDef] {
        try decode("voyages.json", VoyagesFile.self).voyages
    }

    public static func lessonDefs() throws -> [LessonDef] {
        try decode("tutorial.json", TutorialFile.self).lessons
    }

    /// Neutral display name for a swell id (SliceGame's table, plus
    /// chart-specific rows); unknown ids fall back to the id itself.
    public static func neutralName(forSwellID id: String) -> String {
        SliceGame.neutralName(forSwellID: id)
    }

    // MARK: - Charts

    /// Builds every chart row against the swell table. One bad row
    /// fails the whole load (the bundle is validated content).
    public static func charts() throws -> [Chart] {
        let swellDefs = try self.swellDefs()
        return try chartDefs().map { def in
            try SliceGame.buildChart(from: def, swellDefs: swellDefs)
        }
    }

    /// The named chart, or nil when charts.json has no such row.
    public static func chart(id: String) throws -> Chart? {
        let swellDefs = try self.swellDefs()
        guard let def = try chartDefs().first(where: { $0.id == id }) else {
            return nil
        }
        return try SliceGame.buildChart(from: def, swellDefs: swellDefs)
    }

    /// The named chart; traps with a descriptive precondition when the
    /// id is unknown (callers reference authored ids only).
    public static func chartOrPrecondition(id: String) throws -> Chart {
        guard let chart = try chart(id: id) else {
            preconditionFailure("no chart '\(id)' in charts.json")
        }
        return chart
    }

    // MARK: - Puzzles

    /// Reconstructs a puzzle's start state: the chart's initial state,
    /// then the overlay applied as validated reducer actions (islands
    /// first, then toMove). Throws when the overlay is illegal on its
    /// chart (an island on an atoll, on a canoe, adjacent to another,
    /// or a canoe on a strength-0 or occupied cell).
    public static func puzzleState(_ def: PuzzleDef) throws -> GameState {
        guard def.goal == "land_in" else {
            throw ContentError.invalidPuzzle(def.id, "unknown goal \(def.goal)")
        }
        guard def.plies >= 1, def.plies <= 4 else {
            throw ContentError.invalidPuzzle(def.id, "plies out of range: \(def.plies)")
        }
        let chart = try chartOrPrecondition(id: def.chart)
        var state = Reducer.initial(chart: chart)
        // Islands first (empty pool: every placement is the first move
        // of a synthetic side), then the canoe overlays, then toMove.
        var synth = state
        synth.toMove = mover(def)
        for row in def.islands {
            let cell = try hexCell(row, puzzle: def.id)
            let (next, _) = try Reducer.apply(.placeIsland(cell), to: synth)
            synth = next
        }
        for canoe in def.canoes {
            let cell = try hexCell(canoe.at, puzzle: def.id)
            let owner = try player(canoe.owner, puzzle: def.id)
            guard
                let id = CanoeID.allCanoeIDs.first(where: {
                    synth.canoe($0).owner == owner && synth.canoe($0).location == .home
                })
            else {
                throw ContentError.invalidPuzzle(def.id, "no home canoe for \(owner.rawValue)")
            }
            guard synth.field.strength(at: cell) >= 1, synth.isOccupied(cell) == false,
                chart.atollCells.contains(cell) == false
            else {
                throw ContentError.invalidPuzzle(def.id, "canoe cell \(cell) not enterable")
            }
            // Launch-equivalent teleport: validated against R-17's
            // strength rule; adjacency to the atoll is NOT required
            // (puzzles may start a canoe mid-board).
            var next = synth
            next.canoes[id] = CanoeState(
                owner: owner, location: .sea(cell), becalmed: false)
            synth = next
        }
        synth.toMove = mover(def)
        return synth
    }

    /// All puzzles decoded AND validated as solvable-in-N is the
    /// miner's job (P4 MT-P4.2); the loader only checks form here.
    public static func puzzles() throws -> [PuzzleDef] {
        let defs = try puzzleDefs()
        for def in defs {
            _ = try puzzleState(def)
        }
        return defs
    }

    // MARK: - Voyages

    /// The six voyage rows, each referencing an authored chart and a
    /// known opponent tier.
    public static func voyages() throws -> [VoyageDef] {
        let defs = try voyageDefs()
        let charts = try chartDefs()
        for def in defs {
            guard charts.contains(where: { $0.id == def.chart }) else {
                throw ContentError.invalidVoyage(def.id, "unknown chart \(def.chart)")
            }
        }
        return defs
    }

    // MARK: - Lessons

    /// The five tutorial lessons, each referencing an authored chart
    /// and internally consistent steps.
    public static func lessons() throws -> [LessonDef] {
        let defs = try lessonDefs()
        let charts = try chartDefs()
        for def in defs {
            guard charts.contains(where: { $0.id == def.chart }) else {
                throw ContentError.invalidLesson(def.id, "unknown chart \(def.chart)")
            }
            guard !def.steps.isEmpty else {
                throw ContentError.invalidLesson(def.id, "lesson has no steps")
            }
            guard def.steps.last?.kind == .complete else {
                throw ContentError.invalidLesson(def.id, "lesson does not complete")
            }
            for step in def.steps {
                switch step.kind {
                case .placeIsland:
                    guard let cell = step.cell, cell.count == 2 else {
                        throw ContentError.invalidLesson(def.id, "placeIsland needs cell")
                    }
                case .launch:
                    guard let cell = step.launchCell, cell.count == 2 else {
                        throw ContentError.invalidLesson(def.id, "launch needs launchCell")
                    }
                case .sail:
                    guard let path = step.path, !path.isEmpty else {
                        throw ContentError.invalidLesson(def.id, "sail needs path")
                    }
                case .highlightNodes, .complete:
                    break
                }
            }
        }
        return defs
    }

    // MARK: - Plumbing

    private static func mover(_ def: PuzzleDef) -> PlayerID {
        def.toMove == "p2" ? .p2 : .p1
    }

    private static func player(
        _ raw: String, puzzle id: String
    ) throws -> PlayerID {
        switch raw {
        case "p1": return .p1
        case "p2": return .p2
        default: throw ContentError.invalidPuzzle(id, "unknown player \(raw)")
        }
    }

    private static func hexCell(_ row: [Int], puzzle id: String) throws -> Hex {
        guard row.count == 2 else {
            throw ContentError.invalidPuzzle(id, "cell needs [q, r]")
        }
        return Hex(row[0], row[1])
    }

    private static func decode<T: Decodable>(_ name: String, _ type: T.Type) throws -> T {
        guard
            let url = Bundle.module.url(
                forResource: (name as NSString).deletingPathExtension,
                withExtension: (name as NSString).pathExtension)
        else { throw ContentError.missingResource(name) }
        do {
            return try JSONDecoder().decode(T.self, from: try Data(contentsOf: url))
        } catch {
            throw ContentError.malformedJSON(name, "\(error)")
        }
    }
}
