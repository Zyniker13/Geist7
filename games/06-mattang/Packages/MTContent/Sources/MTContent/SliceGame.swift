// SliceGame.swift — the P2 vertical-slice chart, loaded from content JSON.
//
// The slice's one playable chart is `two_swells_basic` (§5 charts.json
// sample row): ocean radius 7 (the §6 default — the sample row omits
// radius, so the default applies), four swells on two opposed axes —
// east_dom (dominant) and west_min (minor) along east–west, north_dom
// (dominant) and south_min (minor) along northwest–southeast — with no
// pre-placed islands, home atolls on the §A.3 radius-7 rim pattern,
// and no declared symmetry: the 2-dominant/2-minor
// weight split is not half-turn symmetric, so `none` is the only
// consistent value and INV-6 does not apply. The JSON mirrors the §5
// schema rows field-for-field; the schema's `homeAtolls:
// [PlayerID: [Hex]]` is carried as `p1Atoll`/`p2Atoll` cell arrays for
// JSON readability, and the loader reassembles the dictionary.
//
// Swell names stay neutral ("East swell") until the Marshallese
// cultural advisor approves glossary terms (§5); `swells.json` marks
// every name `glossary: "pending_advisor"`, which this loader maps to
// no name so the UI falls back to the neutral glossary entries.

import Foundation
import MTCore

/// Errors thrown when bundled content is missing, malformed, or
/// internally inconsistent.
public enum SliceGameError: Error, Equatable {
    case missingResource(String)
    case malformedJSON(String, String)
    case sliceChartMissing(String)
    case unknownSwell(String, String)
    case malformedAtoll(String)
    case invalidChart(String)
}

/// A swell definition decoded from swells.json (§5 SwellDef).
public struct SwellDef: Decodable, Sendable {
    public var id: String
    public var entrySide: Int
    public var direction: Int
    public var weight: Int
    /// The glossary key naming this swell; `"pending_advisor"` marks a
    /// term still awaiting the advisor and decodes to no name.
    public var name: String?

    enum CodingKeys: String, CodingKey {
        case id, entrySide, direction, weight, glossary
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        entrySide = try container.decode(Int.self, forKey: .entrySide)
        direction = try container.decode(Int.self, forKey: .direction)
        weight = try container.decode(Int.self, forKey: .weight)
        let key = try container.decodeIfPresent(String.self, forKey: .glossary)
        name = (key == "pending_advisor" || key == nil) ? nil : key
    }
}

/// A chart definition decoded from charts.json (§5 ChartDef).
public struct ChartDef: Decodable, Sendable {
    public var id: String
    public var radius: Int
    public var swells: [String]
    public var preIslands: [[Int]]
    public var p1Atoll: [[Int]]
    public var p2Atoll: [[Int]]
    public var symmetry: String
    public var cultural: Bool
}

public struct ChartsFile: Decodable {
    public var schemaVersion: Int
    public var game: String
    public var charts: [ChartDef]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case game, charts
    }
}

public struct SwellsFile: Decodable {
    public var schemaVersion: Int
    public var game: String
    public var swells: [SwellDef]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case game, swells
    }
}

/// The P2 vertical-slice chart and its neutral swell names.
public enum SliceGame {
    /// The slice chart's id in charts.json.
    public static let chartID = "two_swells_basic"

    /// Neutral display names for the slice's swells, shown until the
    /// advisor-approved Marshallese terms arrive (§5). Each name
    /// describes the board side its swell enters from.
    public static let neutralNames: [String: String] = [
        "east_dom": "East swell",
        "north_dom": "Northwest swell",
        "west_min": "West swell",
        "south_min": "Southeast swell",
    ]

    /// Neutral display name for a swell id; unknown ids fall back to
    /// the id itself.
    public static func neutralName(forSwellID id: String) -> String {
        neutralNames[id] ?? id
    }

    /// Loads the slice chart from the bundled JSON tables.
    public static func chart() throws -> Chart {
        let chartsData = try resource("charts.json")
        let swellsData = try resource("swells.json")
        let charts: ChartsFile
        let swells: SwellsFile
        do {
            charts = try decoder.decode(ChartsFile.self, from: chartsData)
            swells = try decoder.decode(SwellsFile.self, from: swellsData)
        } catch {
            throw SliceGameError.malformedJSON("content tables", "\(error)")
        }
        guard let def = charts.charts.first(where: { $0.id == chartID }) else {
            throw SliceGameError.sliceChartMissing(chartID)
        }
        return try buildChart(from: def, swellDefs: swells.swells)
    }

    /// Builds a Chart from a decoded row, resolving the swell ids
    /// against the swells table. Internal so the error paths are
    /// testable without bundle access.
    static func buildChart(from def: ChartDef, swellDefs: [SwellDef]) throws -> Chart {
        let byID = Dictionary(uniqueKeysWithValues: swellDefs.map { ($0.id, $0) })
        var swells: [Swell] = []
        for swellID in def.swells {
            guard let swellDef = byID[swellID] else {
                throw SliceGameError.unknownSwell(def.id, swellID)
            }
            swells.append(
                Swell(
                    id: swellDef.id, entrySide: swellDef.entrySide,
                    direction: swellDef.direction, weight: swellDef.weight))
        }
        guard def.p1Atoll.count == 3, def.p2Atoll.count == 3 else {
            throw SliceGameError.malformedAtoll(def.id)
        }
        let preIslands = try hexCells(def.preIslands, chart: def.id)
        let p1Cells = try hexCells(def.p1Atoll, chart: def.id)
        let p2Cells = try hexCells(def.p2Atoll, chart: def.id)
        guard let symmetry = ChartSymmetry(rawValue: def.symmetry) else {
            throw SliceGameError.malformedJSON(def.id, "unknown symmetry \(def.symmetry)")
        }
        let chart = Chart(
            id: def.id, radius: def.radius, swells: swells,
            preIslands: preIslands,
            atolls: [
                Atoll(player: .p1, cells: p1Cells),
                Atoll(player: .p2, cells: p2Cells),
            ],
            symmetry: symmetry)
        let problems = chart.validate()
        guard problems.isEmpty else {
            throw SliceGameError.invalidChart(problems.joined(separator: "; "))
        }
        return chart
    }

    // MARK: - Plumbing

    private static let decoder = JSONDecoder()

    private static func resource(_ name: String) throws -> Data {
        guard
            let url = Bundle.module.url(
                forResource: (name as NSString).deletingPathExtension,
                withExtension: (name as NSString).pathExtension)
        else { throw SliceGameError.missingResource(name) }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw SliceGameError.missingResource(name)
        }
    }

    private static func hexCells(_ rows: [[Int]], chart: String) throws -> Set<Hex> {
        var cells: Set<Hex> = []
        for row in rows {
            guard row.count == 2 else {
                throw SliceGameError.malformedJSON(chart, "cell needs [q, r]")
            }
            cells.insert(Hex(row[0], row[1]))
        }
        return cells
    }
}
