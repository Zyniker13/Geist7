// SliceGameTests.swift — the P2 slice chart's content tables, loader
// API, and error paths.

import XCTest

@testable import MTContent
@testable import MTCore

final class SliceGameTests: XCTestCase {
    // MARK: - Loading the bundled slice chart

    /// The slice chart loads from charts.json/swells.json and passes
    /// the engine's structural validation (§5 ChartDef guard).
    func testSliceChartLoadsAndValidates() throws {
        let chart = try SliceGame.chart()
        XCTAssertEqual(chart.id, "two_swells_basic")
        // §6 default radius (the §5 sample row omits the field, so the
        // default applies).
        XCTAssertEqual(chart.radius, 7)
        // §5 sample row: four swells, two dominant and two minor.
        XCTAssertEqual(
            chart.swells.map(\.id), ["east_dom", "north_dom", "west_min", "south_min"])
        // A.1/A.4 weights: dominants weigh 2, minors weigh 1.
        XCTAssertEqual(chart.swells.map(\.weight), [2, 2, 1, 1])
        XCTAssertTrue(chart.validate().isEmpty, "\(chart.validate())")
    }

    /// Slice geometry: no pre-placed islands (§5 sample row), two
    /// three-cell home atolls on opposite rims, all inside the ocean.
    func testSliceChartGeometry() throws {
        let chart = try SliceGame.chart()
        XCTAssertTrue(chart.preIslands.isEmpty)
        XCTAssertEqual(chart.atolls.count, 2)
        for atoll in chart.atolls {
            XCTAssertEqual(atoll.cells.count, 3, "\(atoll.player.rawValue)")
            for cell in atoll.cells {
                XCTAssertTrue(chart.ocean.contains(cell), "\(atoll.player.rawValue) \(cell)")
            }
        }
        // The cells are the §A.3 radius-7 rim pattern (the
        // lagoon_mirror row's home atolls): p1 on the west rim, p2 on
        // the east rim.
        let p1 = try XCTUnwrap(chart.atolls.first { $0.player == .p1 })
        let p2 = try XCTUnwrap(chart.atolls.first { $0.player == .p2 })
        XCTAssertEqual(p1.cells, Set([Hex(-7, 3), Hex(-7, 4), Hex(-6, 3)]))
        XCTAssertEqual(p2.cells, Set([Hex(7, -3), Hex(7, -4), Hex(6, -3)]))
    }

    /// The slice composition follows A.1: four swells, two dominant
    /// and two minor, entering from four distinct sides that pair into
    /// two opposed axes, each travelling straight in (direction =
    /// opposite side). The 2/1 weight split is not half-turn
    /// symmetric, so the chart declares no symmetry (INV-6 n/a).
    func testSliceChartComposition() throws {
        let chart = try SliceGame.chart()
        XCTAssertEqual(chart.symmetry, .none)
        let byID = Dictionary(uniqueKeysWithValues: chart.swells.map { ($0.id, $0) })
        let expected: [String: (side: Int, direction: Int, weight: Int)] = [
            "east_dom": (0, 3, 2),
            "north_dom": (4, 1, 2),
            "west_min": (3, 0, 1),
            "south_min": (1, 4, 1),
        ]
        XCTAssertEqual(byID.count, 4)
        for (id, want) in expected {
            let swell = try XCTUnwrap(byID[id], "missing swell \(id)")
            XCTAssertEqual(swell.entrySide, want.side, id)
            XCTAssertEqual(swell.direction, want.direction, id)
            XCTAssertEqual(swell.weight, want.weight, id)
            XCTAssertEqual(
                swell.direction, (swell.entrySide + 3) % 6, "\(id) travels straight in")
        }
        // The four sides pair into two opposed axes.
        let sides = Set(chart.swells.map(\.entrySide))
        XCTAssertEqual(sides.count, 4)
        for side in sides {
            XCTAssertTrue(sides.contains((side + 3) % 6), "side \(side) has no opposed swell")
        }
    }

    /// Neutral swell names come from the loader table until the
    /// advisor-approved Marshallese terms arrive (§5).
    func testNeutralNames() {
        XCTAssertEqual(SliceGame.neutralName(forSwellID: "east_dom"), "East swell")
        XCTAssertEqual(SliceGame.neutralName(forSwellID: "north_dom"), "Northwest swell")
        XCTAssertEqual(SliceGame.neutralName(forSwellID: "west_min"), "West swell")
        XCTAssertEqual(SliceGame.neutralName(forSwellID: "south_min"), "Southeast swell")
        XCTAssertEqual(SliceGame.neutralName(forSwellID: "unknown"), "unknown")
    }

    // MARK: - Error paths (buildChart from decoded rows)

    /// Decoding the bundle's swell table yields the four slice rows,
    /// each marked pending-advisor so the loader maps it to no name.
    func testSwellTableDecodesPendingAdvisorNames() throws {
        let defs = try SliceGameTests.swellDefs()
        XCTAssertEqual(defs.map(\.id), ["east_dom", "north_dom", "west_min", "south_min"])
        XCTAssertTrue(defs.allSatisfy { $0.name == nil }, "all names are pending_advisor")
    }

    /// An unknown swell id in a chart row throws `unknownSwell`.
    func testBuildChartUnknownSwellThrows() throws {
        var def = try SliceGameTests.sliceDef()
        def.swells = ["east_dom", "ghost"]
        XCTAssertThrowsErrorEqual(
            try SliceGame.buildChart(from: def, swellDefs: SliceGameTests.swellDefs()),
            .unknownSwell("two_swells_basic", "ghost"))
    }

    /// A home atoll row with the wrong cell count throws
    /// `malformedAtoll` before any geometry is built.
    func testBuildChartMalformedAtollThrows() throws {
        var def = try SliceGameTests.sliceDef()
        def.p2Atoll = [[3, 0], [3, -1]]
        XCTAssertThrowsErrorEqual(
            try SliceGame.buildChart(from: def, swellDefs: SliceGameTests.swellDefs()),
            .malformedAtoll("two_swells_basic"))
    }

    /// An unknown symmetry string throws `malformedJSON`.
    func testBuildChartUnknownSymmetryThrows() throws {
        var def = try SliceGameTests.sliceDef()
        def.symmetry = "rotate90"
        XCTAssertThrowsErrorEqual(
            try SliceGame.buildChart(from: def, swellDefs: SliceGameTests.swellDefs()),
            .malformedJSON("two_swells_basic", "unknown symmetry rotate90"))
    }

    /// Atoll cells outside the ocean fail the chart's own validation
    /// and surface as `invalidChart` (the joined problem list names
    /// the offending player).
    func testBuildChartInvalidGeometryThrows() throws {
        var def = try SliceGameTests.sliceDef()
        def.p1Atoll = [[9, 9], [9, 10], [9, 11]]
        XCTAssertThrowsError(
            try SliceGame.buildChart(from: def, swellDefs: SliceGameTests.swellDefs())
        ) { error in
            guard case let .invalidChart(message) = error as? SliceGameError else {
                XCTFail("wrong error: \(error)")
                return
            }
            XCTAssertTrue(message.contains("atoll for p1"), message)
        }
    }

    /// A malformed cell row throws `malformedJSON` naming the chart.
    func testBuildChartMalformedCellThrows() throws {
        var def = try SliceGameTests.sliceDef()
        def.preIslands = [[0]]
        XCTAssertThrowsErrorEqual(
            try SliceGame.buildChart(from: def, swellDefs: SliceGameTests.swellDefs()),
            .malformedJSON("two_swells_basic", "cell needs [q, r]"))
    }

    // MARK: - Glossary

    /// The four neutral swell entries ship pending advisor approval
    /// alongside the P0 glossary rows.
    func testGlossaryIncludesNeutralSwellEntries() throws {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "glossary", withExtension: "json"))
        let doc = try JSONDecoder().decode(GlossaryDoc.self, from: Data(contentsOf: url))
        let pendingKeys = [
            "gl_east_swell", "gl_nw_swell", "gl_west_swell", "gl_se_swell",
        ]
        let keys = Set(doc.entries.map(\.key))
        for key in pendingKeys {
            XCTAssertTrue(keys.contains(key), "missing \(key)")
        }
        for entry in doc.entries where pendingKeys.contains(entry.key) {
            XCTAssertEqual(entry.status, "pending", entry.key)
        }
    }

    // MARK: - Helpers

    /// The slice row as decoded from the bundle.
    private static func sliceDef() throws -> ChartDef {
        let chartsURL = try XCTUnwrap(
            Bundle.module.url(forResource: "charts", withExtension: "json"))
        let file = try JSONDecoder().decode(
            ChartsFile.self, from: Data(contentsOf: chartsURL))
        guard let def = file.charts.first(where: { $0.id == SliceGame.chartID }) else {
            preconditionFailure("slice chart missing from charts.json")
        }
        return def
    }

    /// The swell rows as decoded from the bundle.
    private static func swellDefs() throws -> [SwellDef] {
        let swellsURL = try XCTUnwrap(
            Bundle.module.url(forResource: "swells", withExtension: "json"))
        let file = try JSONDecoder().decode(
            SwellsFile.self, from: Data(contentsOf: swellsURL))
        return file.swells
    }
}

/// Asserts the closure throws exactly `expected` (SliceGameError is
/// Equatable, so the case and payload must both match).
private func XCTAssertThrowsErrorEqual(
    _ expression: @autoclosure () throws -> some Any,
    _ expected: SliceGameError,
    file: StaticString = #filePath, line: UInt = #line
) {
    do {
        _ = try expression()
        XCTFail("expected error \(expected)", file: file, line: line)
    } catch let error as SliceGameError {
        XCTAssertEqual(error, expected, file: file, line: line)
    } catch {
        XCTFail("wrong error type: \(error)", file: file, line: line)
    }
}
