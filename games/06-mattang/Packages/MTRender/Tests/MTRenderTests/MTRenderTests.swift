// MTRenderTests.swift — layout geometry, palette data, and the
// preview-field property, all without a renderer.
//
// The preview test (MT-P2.2, G2's "preview and committed fields
// match") runs here at unit scale: the ghost field must equal the
// field the reducer produces when the same placement is committed,
// for every placement candidate of a real traced game.

import XCTest
@testable import MTRender
import MTCore

final class MTRenderTests: XCTestCase {
    func testPackageCompiles() {
        XCTAssertEqual(MTRenderInfo.identifier, "MTRender")
    }

    // MARK: Layout geometry

    func testAxialPointMapping() {
        let layout = HexLayout(hexSize: 10, center: CGPoint(x: 100, y: 100))
        let root3 = CGFloat(3).squareRoot()
        // Origin cell at the centre.
        XCTAssertEqual(layout.point(for: Hex(0, 0)), CGPoint(x: 100, y: 100))
        // East neighbor: +√3·size in x.
        XCTAssertEqual(
            layout.point(for: Hex(1, 0)), CGPoint(x: 100 + 10 * root3, y: 100))
        // Southeast neighbor: +√3·size/2 in x, +3/2·size in y (r grows
        // screen-down).
        XCTAssertEqual(
            layout.point(for: Hex(0, 1)),
            CGPoint(x: 100 + 5 * root3, y: 100 + 15))
    }

    func testCornersSitAtHexSizeFromTheCenter() {
        let layout = HexLayout(hexSize: 12, center: .zero)
        let cell = Hex(2, -1)
        let center = layout.point(for: cell)
        let corners = layout.corners(of: cell)
        XCTAssertEqual(corners.count, 6)
        for corner in corners {
            let distance = hypot(corner.x - center.x, corner.y - center.y)
            XCTAssertEqual(distance, 12, accuracy: 0.0001)
        }
    }

    func testFittingKeepsTheBoardInsideTheViewport() {
        let available = CGSize(width: 400, height: 400)
        let layout = HexLayout.fitting(radius: 3, in: available)
        let box = layout.boundingBox(over: Ocean(radius: 3).allCells)
        XCTAssertGreaterThanOrEqual(box.minX, 11.9, "west edge inside the margin")
        XCTAssertLessThanOrEqual(box.maxX, 388.1, "east edge inside the margin")
        XCTAssertGreaterThanOrEqual(box.minY, 11.9, "north edge inside the margin")
        XCTAssertLessThanOrEqual(box.maxY, 388.1, "south edge inside the margin")
    }

    func testFittingASmallViewportStillProducesPositiveHexSize() {
        let layout = HexLayout.fitting(radius: 7, in: CGSize(width: 40, height: 40))
        XCTAssertGreaterThan(layout.hexSize, 0)
    }

    func testCellNearRoundTripsThroughThePointMapping() {
        let available = CGSize(width: 400, height: 400)
        let layout = HexLayout.fitting(radius: 3, in: available)
        for cell in Ocean(radius: 3).allCells {
            let point = layout.point(for: cell)
            let relative = CGPoint(
                x: point.x - layout.center.x, y: point.y - layout.center.y)
            XCTAssertEqual(layout.cell(near: relative), cell, "round trip for \(cell)")
        }
    }

    func testCellNearFarOutsideTheBoardStillMapsDeterministically() {
        let layout = HexLayout(hexSize: 10, center: .zero)
        let point = CGPoint(x: 1000, y: 1000)
        XCTAssertEqual(layout.cell(near: point), layout.cell(near: point))
        // The nearest centre to (1000, 1000) sits one circumradius
        // away at most; the app layer bounds hits by the ocean.
        let cell = layout.cell(near: point)
        let centre = layout.point(for: cell)
        let distance = hypot(centre.x - 1000, centre.y - 1000)
        XCTAssertLessThanOrEqual(distance, 10.0001)
    }

    // MARK: Palette

    func testPaletteSchemesExposeTheFiveMaterialColors() {
        for scheme in [SeaPalette.light, SeaPalette.dark] {
            XCTAssertNotNil(scheme.deepSea)
            XCTAssertNotNil(scheme.swellCrest)
            XCTAssertNotNil(scheme.pandanus)
            XCTAssertNotNil(scheme.coconutRib)
            XCTAssertNotNil(scheme.cowrie)
        }
        XCTAssertEqual(SeaPalette.scheme(true), SeaPalette.dark)
        XCTAssertEqual(SeaPalette.scheme(false), SeaPalette.light)
    }

    // MARK: Scene model and the preview property

    /// A real traced game on a radius-3 chart: an east-dominant swell
    /// and a minor northern swell, so the field has crossing nodes.
    private func tracedState() -> (Chart, GameState) {
        let chart = Chart(
            id: "render-test",
            radius: 3,
            swells: [
                Swell.major(id: "east_dom", entrySide: 0, direction: 3),
                Swell.minor(id: "north_min", entrySide: 4, direction: 1),
            ],
            preIslands: [],
            atolls: [
                Atoll(player: .p1, cells: [Hex(-3, 1), Hex(-3, 2), Hex(-2, 2)]),
                Atoll(player: .p2, cells: [Hex(3, -1), Hex(3, -2), Hex(2, -2)]),
            ],
            symmetry: .none)
        return (chart, Reducer.initial(chart: chart))
    }

    func testModelWithoutGhostDrawsTheCommittedField() {
        let (chart, state) = tracedState()
        let model = SeaSceneModel(chart: chart, state: state)
        XCTAssertEqual(model.field, state.field)
        XCTAssertNil(model.ghostIsland)
    }

    func testPreviewFieldMatchesCommittedFieldForEveryPlacement() throws {
        let (chart, state) = tracedState()
        var checked = 0
        for cell in state.placeableCandidates() {
            let reason = Reducer.reason(.placeIsland(cell), in: state)
            guard reason == nil else { continue }
            let model = SeaSceneModel(chart: chart, state: state, ghostIsland: cell)
            let committed = try Reducer.apply(.placeIsland(cell), to: state).state
            XCTAssertEqual(
                model.field, committed.field,
                "ghost field at \(cell) differs from the committed field")
            checked += 1
        }
        // Radius-3 geometry: 31 sea cells minus those adjacent to an
        // atoll leaves 17 legal placements (derived from R-7).
        XCTAssertGreaterThanOrEqual(checked, 17, "the fixture offers placements to check")
    }

    // MARK: G2 randomized preview property

    /// A random chart drawn from `rng`: radius 3–6, one to three swells,
    /// the two home atolls on opposite edges, and a random symmetry.
    /// Mirrors the sim's chart templates so the geometry is always
    /// launchable (R-17) and well-formed.
    private func randomChart(_ rng: inout SeededRNG) -> Chart {
        let radius = 3 + rng.nextInt(below: 4) // 3...6
        let atolls = [
            Atoll(player: .p1, cells: [Hex(-radius, 1), Hex(-radius, 2), Hex(-radius + 1, 2)]),
            Atoll(player: .p2, cells: [Hex(radius, -1), Hex(radius, -2), Hex(radius - 1, -2)]),
        ]
        var swells = [Swell.major(id: "east_dom", entrySide: 0, direction: 3)]
        let minorCount = rng.nextInt(below: 3) // 0...2
        for i in 0..<minorCount {
            swells.append(Swell.minor(
                id: "sw_\(i)", entrySide: rng.nextInt(below: 6),
                direction: rng.nextInt(below: 6)))
        }
        let symmetry: ChartSymmetry = [ChartSymmetry.none, .mirror, .rotate180][rng.nextInt(below: 3)]
        return Chart(
            id: "rand-\(radius)-\(swells.count)", radius: radius, swells: swells,
            preIslands: [], atolls: atolls, symmetry: symmetry)
    }

    /// G2 check 2: the preview field (the ghost the scene draws) must
    /// equal the field the reducer produces when the same placement is
    /// committed, for 500 random placements across random charts.
    func testPreviewMatchesCommittedAcrossFiveHundredRandomPlacements() throws {
        var rng = SeededRNG(seed: 0x5EED_2026)
        var checked = 0
        var attempts = 0
        while checked < 500 {
            attempts += 1
            if attempts > 5000 {
                XCTFail("could not draw 500 legal placements in 5000 chart attempts")
                break
            }
            let chart = randomChart(&rng)
            guard chart.validate().isEmpty else { continue }
            let state = Reducer.initial(chart: chart)
            let candidates = state.placeableCandidates()
            guard !candidates.isEmpty else { continue }
            let cell = candidates[rng.nextInt(below: candidates.count)]
            guard Reducer.reason(.placeIsland(cell), in: state) == nil else { continue }
            let model = SeaSceneModel(chart: chart, state: state, ghostIsland: cell)
            let committed = try Reducer.apply(.placeIsland(cell), to: state).state
            XCTAssertEqual(
                model.field, committed.field,
                "ghost field at \(cell) on chart \(chart.id) differs from the committed field")
            checked += 1
        }
        XCTAssertEqual(checked, 500, "500 randomized placements verified")
    }

    func testOverlayFlagsSuppressTheirLayers() {
        let (chart, state) = tracedState()
        let geometryAll = SeaSceneGeometry(
            model: SeaSceneModel(chart: chart, state: state), in: CGSize(width: 400, height: 400))
        XCTAssertFalse(geometryAll.rayPolylines.isEmpty, "rays present by default")
        XCTAssertFalse(geometryAll.nodeRings.isEmpty, "the traced field has nodes")

        let geometryNoRays = SeaSceneGeometry(
            model: SeaSceneModel(chart: chart, state: state, showRays: false),
            in: CGSize(width: 400, height: 400))
        XCTAssertTrue(geometryNoRays.rayPolylines.isEmpty, "the ray toggle empties the layer")

        let geometryNoNodes = SeaSceneGeometry(
            model: SeaSceneModel(chart: chart, state: state, showNodes: false),
            in: CGSize(width: 400, height: 400))
        XCTAssertTrue(geometryNoNodes.nodeRings.isEmpty, "the node toggle empties the layer")
    }

    func testGeometryCarriesMarkersAndHighlights() {
        let (chart, state) = tracedState()
        let id = CanoeID(player: .p1, index: 0)
        var marked = state
        marked.canoes[id] = CanoeState(owner: .p1, location: .sea(Hex(-2, 0)), becalmed: false)
        let path = [Hex(-2, 0), Hex(-1, 0)]
        let model = SeaSceneModel(
            chart: chart, state: marked, pathHighlight: path,
            ghostIsland: Hex(0, 1), highlightSwells: ["east_dom"])
        let geometry = SeaSceneGeometry(model: model, in: CGSize(width: 400, height: 400))
        XCTAssertEqual(geometry.canoes.count, 1)
        XCTAssertEqual(geometry.canoes.first?.cell, Hex(-2, 0))
        XCTAssertEqual(geometry.canoes.first?.owner, .p1)
        XCTAssertEqual(geometry.pathHighlight, path)
        XCTAssertEqual(geometry.ghostIsland, Hex(0, 1))
        XCTAssertEqual(
            Set(geometry.raySwells), ["east_dom", "north_min"],
            "both traced swells appear in the ray layer")
    }
}
