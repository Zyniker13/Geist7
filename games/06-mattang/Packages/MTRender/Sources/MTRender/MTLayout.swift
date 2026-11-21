// MTLayout.swift — axial hex layout for the sea scene.
//
// Pointy-top hexes on the axial grid (MTCore Hex: directions 0–5
// clockwise from east, r increasing screen-down). The layout is pure
// geometry: it maps Hex cells and the scene's rectangles to Core
// Graphics points and never touches engine state, so the whole visual
// layer can be unit-tested without a renderer.

import CoreGraphics
import MTCore

/// Maps axial cells to points for one board size and viewport.
public struct HexLayout: Sendable {
    /// Hex circumradius in points (centre to corner).
    public let hexSize: CGFloat
    /// Board centre in the drawn space.
    public let center: CGPoint

    public init(hexSize: CGFloat, center: CGPoint) {
        self.hexSize = hexSize
        self.center = center
    }

    /// The pixel point of a cell's centre (pointy-top axial).
    /// x = √3·size·(q + r/2), y = (3/2)·size·r; r grows downward.
    public func point(for cell: Hex) -> CGPoint {
        let q = CGFloat(cell.q)
        let r = CGFloat(cell.r)
        let x = hexSize * (CGFloat(3).squareRoot() * (q + r / 2.0))
        let y = hexSize * (3.0 / 2.0 * r)
        return CGPoint(x: center.x + x, y: center.y + y)
    }

    /// The six corner points of a cell's hexagon, corner k at
    /// 60·k − 30 degrees (corner 0 points down-right for pointy-top).
    public func corners(of cell: Hex) -> [CGPoint] {
        let c = point(for: cell)
        return (0..<6).map { k in
            let angle = CGFloat(k) * 60.0 - 30.0
            let radians = angle * CGFloat.pi / 180.0
            return CGPoint(
                x: c.x + hexSize * cos(radians),
                y: c.y + hexSize * sin(radians))
        }
    }

    /// The board's bounding box: the extremes over every given cell's
    /// corners, insetting/outsetting by the hex size so rays and
    /// markers never touch the frame edge.
    public func boundingBox(over cells: [Hex]) -> CGRect {
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        for cell in cells {
            for corner in corners(of: cell) {
                minX = min(minX, corner.x)
                minY = min(minY, corner.y)
                maxX = max(maxX, corner.x)
                maxY = max(maxY, corner.y)
            }
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// The largest hex size at which the radius-`radius` board fits
    /// inside `available` with `margin` points to spare on every side.
    public static func fitting(
        radius: Int, in available: CGSize, margin: CGFloat = 12
    ) -> HexLayout {
        // Unit-size probe layout centred at the origin measures the
        // board's aspect; the final size scales it into the viewport.
        let probe = HexLayout(hexSize: 1, center: .zero)
        let board = Ocean(radius: radius)
        let box = probe.boundingBox(over: board.allCells)
        let usableW = max(1, available.width - 2 * margin)
        let usableH = max(1, available.height - 2 * margin)
        let scale = min(usableW / box.width, usableH / box.height)
        return HexLayout(
            hexSize: scale,
            center: CGPoint(x: available.width / 2.0, y: available.height / 2.0))
    }

    /// The lattice cell whose centre is nearest to `point` (a
    /// board-relative coordinate, as returned by `point(for:)` minus
    /// the centre), via cube rounding. Hex lattices tile the plane, so
    /// every point maps to a cell; callers bound hits by the ocean.
    public func cell(near point: CGPoint) -> Hex {
        let x = point.x
        let y = point.y
        let fractionalQ = (CGFloat(3).squareRoot() / 3.0 * x - y / 3.0) / hexSize
        let fractionalR = (2.0 / 3.0 * y) / hexSize
        return Self.roundAxial(q: fractionalQ, r: fractionalR)
    }

    /// Cube rounding of axial coordinates (the standard hex-grid
    /// nearest-cell conversion).
    private static func roundAxial(q: CGFloat, r: CGFloat) -> Hex {
        var x = q
        var z = r
        var y = -x - z
        var rx = x.rounded()
        var ry = y.rounded()
        var rz = z.rounded()
        let dx = abs(rx - x)
        let dy = abs(ry - y)
        let dz = abs(rz - z)
        if dx > dy && dx > dz {
            rx = -ry - rz
        } else if dy > dz {
            ry = -rx - rz
        } else {
            rz = -rx - ry
        }
        return Hex(q: Int(rx), r: Int(rz))
    }
}
