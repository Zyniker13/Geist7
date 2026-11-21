// SeaSceneView.swift — the SwiftUI Canvas sea scene (MT-P2.1).
//
// Draws the board from SeaSceneGeometry: deep-sea cells shaded by
// strength, ray polylines in the swell-crest color, cowrie node
// rings, pandanus islands and atolls, coconut-rib canoes, the ghost
// island outline of the placement preview, and the highlighted path
// of the selected canoe. The Metal wave field of MT-P6.1 replaces
// nothing here yet — P2 keeps the vector scene (ADR-0016).

import MTCore
import SwiftUI

public struct SeaSceneView: View {
    public let model: SeaSceneModel
    public let palette: SeaPalette

    public init(model: SeaSceneModel, palette: SeaPalette) {
        self.model = model
        self.palette = palette
    }

    public var body: some View {
        Canvas { context, size in
            let geometry = SeaSceneGeometry(model: model, in: size)
            draw(in: &context, geometry: geometry)
        }
    }

    private func draw(in context: inout GraphicsContext, geometry: SeaSceneGeometry) {
        drawSea(in: &context, geometry: geometry)
        if model.showRays { drawRays(in: &context, geometry: geometry) }
        if model.showNodes { drawNodes(in: &context, geometry: geometry) }
        drawAtolls(in: &context, geometry: geometry)
        drawIslands(in: &context, geometry: geometry)
        drawGhost(in: &context, geometry: geometry)
        drawPathHighlight(in: &context, geometry: geometry)
        drawCanoes(in: &context, geometry: geometry)
    }

    // MARK: Layers

    private func drawSea(in context: inout GraphicsContext, geometry: SeaSceneGeometry) {
        for (cell, _) in geometry.cellFrames {
            let strength = model.field.strength(at: cell)
            // Strength shading: deeper calm cells, crest-tinted strong
            // ones. Alpha only — strength never reads as hue alone
            // (P8 will add pattern and numbers).
            let path = Path(geometry.layout.corners(of: cell))
            context.fill(path, with: .color(palette.deepSea))
            if strength > 0 {
                let alpha = min(0.38, 0.10 * CGFloat(strength))
                context.fill(path, with: .color(palette.swellCrest.opacity(alpha)))
            }
        }
    }

    private func drawRays(in context: inout GraphicsContext, geometry: SeaSceneGeometry) {
        for (index, polyline) in geometry.rayPolylines.enumerated() {
            guard polyline.count >= 2 else { continue }
            let swellID = geometry.raySwells[index]
            let highlighted = model.highlightSwells.contains(swellID)
            var path = Path()
            path.move(to: polyline[0])
            for point in polyline.dropFirst() {
                path.addLine(to: point)
            }
            context.stroke(
                path,
                with: .color(palette.swellCrest.opacity(highlighted ? 0.95 : 0.45)),
                style: StrokeStyle(
                    lineWidth: highlighted ? 2.4 : 1.4,
                    lineCap: .round, lineJoin: .round))
        }
    }

    private func drawNodes(in context: inout GraphicsContext, geometry: SeaSceneGeometry) {
        for cell in geometry.nodeRings {
            let center = geometry.layout.point(for: cell)
            let radius = geometry.layout.hexSize * 0.30
            let ring = Path(
                ellipseIn: CGRect(
                    x: center.x - radius, y: center.y - radius,
                    width: 2 * radius, height: 2 * radius))
            context.stroke(ring, with: .color(palette.cowrie), lineWidth: 1.6)
        }
    }

    private func drawAtolls(in context: inout GraphicsContext, geometry: SeaSceneGeometry) {
        for cell in geometry.atollCells {
            let path = Path(geometry.layout.corners(of: cell))
            context.fill(path, with: .color(palette.pandanus))
            context.stroke(path, with: .color(palette.coconutRib), lineWidth: 1.2)
        }
    }

    private func drawIslands(in context: inout GraphicsContext, geometry: SeaSceneGeometry) {
        for cell in geometry.islandCells {
            let path = Path(geometry.layout.corners(of: cell))
            context.fill(path, with: .color(palette.pandanus))
            context.stroke(path, with: .color(palette.coconutRib), lineWidth: 1.6)
        }
    }

    private func drawGhost(in context: inout GraphicsContext, geometry: SeaSceneGeometry) {
        guard let ghost = geometry.ghostIsland,
            geometry.cellFrames[ghost] != nil
        else { return }
        let path = Path(geometry.layout.corners(of: ghost))
        context.fill(path, with: .color(palette.cowrie.opacity(0.28)))
        context.stroke(
            path, with: .color(palette.cowrie),
            style: StrokeStyle(lineWidth: 2.0, dash: [4, 3]))
    }

    private func drawPathHighlight(in context: inout GraphicsContext, geometry: SeaSceneGeometry) {
        guard geometry.pathHighlight.count >= 1 else { return }
        // A cowrie line through the path's cell centres, ending on an
        // arrowhead-less cap (the canoe marker marks the destination).
        var points: [CGPoint] = []
        for cell in geometry.pathHighlight where geometry.cellFrames[cell] != nil {
            points.append(geometry.layout.point(for: cell))
        }
        guard points.count >= 1 else { return }
        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        context.stroke(
            path, with: .color(palette.cowrie),
            style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
        for point in points {
            let dot = Path(
                ellipseIn: CGRect(
                    x: point.x - 3, y: point.y - 3, width: 6, height: 6))
            context.fill(dot, with: .color(palette.cowrie))
        }
    }

    private func drawCanoes(in context: inout GraphicsContext, geometry: SeaSceneGeometry) {
        for marker in geometry.canoes {
            let center = geometry.layout.point(for: marker.cell)
            let radius = geometry.layout.hexSize * 0.34
            let body = Path(
                ellipseIn: CGRect(
                    x: center.x - radius, y: center.y - radius,
                    width: 2 * radius, height: 2 * radius))
            // p1 coconut-rib, p2 cowrie; both outlined in the other's
            // tone so the two sides stay readable (P8 revisits for
            // color-blind patterns).
            let fill = marker.owner == .p1 ? palette.coconutRib : palette.cowrie
            let stroke = marker.owner == .p1 ? palette.cowrie : palette.pandanus
            context.fill(body, with: .color(fill))
            context.stroke(body, with: .color(stroke), lineWidth: 1.4)
        }
    }
}

extension Path {
    /// A closed polygon through the corner points.
    init(_ corners: [CGPoint]) {
        self.init()
        guard let first = corners.first else { return }
        self.move(to: first)
        for point in corners.dropFirst() {
            self.addLine(to: point)
        }
        self.closeSubpath()
    }
}
