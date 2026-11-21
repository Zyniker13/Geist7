// SeaSceneModel.swift — everything the scene draws, precomputed.
//
// The model is a plain value: pure geometry over the engine state
// (ADR-0005: render-only, never read back into Core). Overlay fields
// carry the MT-P2.1 behaviors — the ray toggle, node highlights, and
// the island-placement preview that recomputes the field before the
// player commits. The committed action still goes through the
// reducer; the ghost field is Core's own FieldUpdate output shown
// early, and the G2 test pins preview and committed fields equal.

import CoreGraphics
import MTCore

public struct SeaSceneModel: Sendable {
    public let chart: Chart
    public let state: GameState
    /// The field the scene draws: the state's field, or the preview
    /// field when a ghost island is shown.
    public let field: Field
    public var showRays: Bool
    public var showNodes: Bool
    /// Cells of the selected canoe's legal path (node-chain highlight).
    public var pathHighlight: [Hex]
    /// The hypothetical island cell of the placement preview.
    public var ghostIsland: Hex?
    /// Rays of swells the last action changed, for the AI explain view.
    public var highlightSwells: Set<String>

    public init(
        chart: Chart, state: GameState, showRays: Bool = true,
        showNodes: Bool = true, pathHighlight: [Hex] = [],
        ghostIsland: Hex? = nil, highlightSwells: Set<String> = []
    ) {
        self.chart = chart
        self.state = state
        self.showRays = showRays
        self.showNodes = showNodes
        self.pathHighlight = pathHighlight
        self.ghostIsland = ghostIsland
        self.highlightSwells = highlightSwells
        if let ghost = ghostIsland {
            self.field = FieldUpdate.applyIslandPlacement(
                previous: state.field, ocean: chart.ocean, swells: chart.swells,
                islands: state.islands, atollCells: chart.atollCells, placed: ghost)
        } else {
            self.field = state.field
        }
    }
}

/// The drawn geometry, built once per model: cell paths, ray
/// polylines, and marker positions in scene coordinates.
public struct SeaSceneGeometry: Sendable {
    public let layout: HexLayout
    public let cellFrames: [Hex: CGRect]
    /// One polyline per traced ray, in Field's ray order.
    public let rayPolylines: [[CGPoint]]
    public let raySwells: [String]
    public let nodeRings: [Hex]
    public let islandCells: [Hex]
    public let atollCells: [Hex]
    public let ghostIsland: Hex?
    /// Sea canoes as (cell, owner) in CanoeID order.
    public let canoes: [(cell: Hex, owner: PlayerID)]
    public let pathHighlight: [Hex]

    /// Builds the geometry for `model` inside `available` points.
    public init(model: SeaSceneModel, in available: CGSize) {
        let layout = HexLayout.fitting(radius: model.chart.radius, in: available)
        self.layout = layout
        let ocean = model.chart.ocean

        var frames: [Hex: CGRect] = [:]
        for cell in ocean.allCells {
            let center = layout.point(for: cell)
            let s = layout.hexSize
            frames[cell] = CGRect(
                x: center.x - s, y: center.y - s, width: 2 * s, height: 2 * s)
        }
        self.cellFrames = frames

        var polylines: [[CGPoint]] = []
        var swells: [String] = []
        if model.showRays {
            for ray in model.field.rays {
                polylines.append(ray.cells.map { layout.point(for: $0) })
                swells.append(ray.swell)
            }
        }
        self.rayPolylines = polylines
        self.raySwells = swells

        self.nodeRings = model.showNodes
            ? model.field.nodes.sorted(by: Hex.rowMajor) : []
        self.islandCells = model.state.islands.sorted(by: Hex.rowMajor)
        self.atollCells = model.chart.atollCells.sorted(by: Hex.rowMajor)
        self.ghostIsland = model.ghostIsland

        var canoeMarkers: [(cell: Hex, owner: PlayerID)] = []
        for id in CanoeID.allCanoeIDs {
            let canoe = model.state.canoe(id)
            if case .sea(let cell) = canoe.location {
                canoeMarkers.append((cell, canoe.owner))
            }
        }
        self.canoes = canoeMarkers
        self.pathHighlight = model.pathHighlight
    }
}
