// RSRender — P6 (RS-P6.1): procedural board art and tavern backdrops.
//
// All art is generated in code (no third-party assets ship with the game):
// worn-wood frames, bitumen bedding, inlay borders with the region motif,
// rosette flowers on the rosette squares, and tavern backdrops with walls,
// beams, shelf silhouettes, and a lantern glow. Everything is
// deterministic — no randomness — so the art is identical on every run.

import CoreGraphics
import SpriteKit

// MARK: - BoardArt

/// Builders for the region-themed board art (RS-P6.1).
public enum BoardArt {

    /// Build the board background for a theme: worn-wood frame, bitumen
    /// bedding, and the inlay border with the region motif. The node is
    /// centered at the origin and sized to `boardRect` (in points, centered
    /// on 0,0). Rosette flowers are added separately by the scene so they
    /// sit above the square fills.
    public static func boardBackground(
        theme: RegionTheme,
        boardRect: CGRect
    ) -> SKNode {
        let root = SKNode()
        root.name = "boardBackground"

        let frameWidth: CGFloat = 14
        let frameRect = boardRect.insetBy(dx: -frameWidth, dy: -frameWidth)

        // Worn-wood frame.
        let frame = SKShapeNode(
            rectOf: frameRect.size, cornerRadius: 10)
        frame.fillColor = theme.frame
        frame.strokeColor = theme.bedding.withAlpha(0.9)
        frame.lineWidth = 2
        frame.position = .zero
        frame.name = "boardFrame"
        root.addChild(frame)

        // Bitumen bedding.
        let bedding = SKShapeNode(
            rectOf: boardRect.size, cornerRadius: 6)
        bedding.fillColor = theme.bedding
        bedding.strokeColor = theme.frame.withAlpha(0.7)
        bedding.lineWidth = 1
        bedding.position = .zero
        bedding.name = "boardBedding"
        root.addChild(bedding)

        // Inlay border with the region motif.
        let border = motifBorder(theme: theme, boardRect: boardRect)
        border.name = "boardMotifBorder"
        root.addChild(border)
        return root
    }

    /// A rosette flower (the Ur board's rosette motif): a shell disc with a
    /// lapis rim, pointed red-limestone petals radiating from the center,
    /// and a gold center dot — echoing the original board's red rosettes.
    public static func rosetteFlower(theme: RegionTheme, radius: CGFloat) -> SKNode {
        let root = SKNode()

        // Shell backing disc with a lapis rim.
        let disc = SKShapeNode(circleOfRadius: radius)
        disc.fillColor = theme.squareShell
        disc.strokeColor = theme.lapis
        disc.lineWidth = max(1.5, radius * 0.07)
        root.addChild(disc)

        // Petals: leaf shapes, pointed at the center, rounded at the tip.
        let petalCount = 8
        let petalLength = radius * 0.78
        let petalWidth = radius * 0.38
        for i in 0..<petalCount {
            let angle = CGFloat(i) / CGFloat(petalCount) * 2 * .pi
            let petal = SKShapeNode(
                path: Self.petalPath(
                    length: petalLength, width: petalWidth))
            petal.fillColor = theme.accent
            petal.strokeColor = theme.bedding
            petal.lineWidth = max(1, radius * 0.02)
            petal.zRotation = angle - .pi / 2
            root.addChild(petal)
        }

        let center = SKShapeNode(circleOfRadius: radius * 0.22)
        center.fillColor = theme.gold
        center.strokeColor = theme.bedding
        center.lineWidth = max(1, radius * 0.02)
        root.addChild(center)
        return root
    }

    /// A leaf path: pointed at the origin, rounded at (0, length).
    private static func petalPath(length: CGFloat, width: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let half = width / 2
        let shoulder = length * 0.72
        path.move(to: CGPoint(x: 0, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: half, y: shoulder),
            control: CGPoint(x: half * 0.75, y: length * 0.28))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: length),
            control: CGPoint(x: half * 0.35, y: length))
        path.addQuadCurve(
            to: CGPoint(x: -half, y: shoulder),
            control: CGPoint(x: -half * 0.35, y: length))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: 0),
            control: CGPoint(x: -half * 0.75, y: length * 0.28))
        path.closeSubpath()
        return path
    }

    /// The inlay border: a row of small motif chips along the four edges.
    private static func motifBorder(theme: RegionTheme, boardRect: CGRect) -> SKNode {
        let root = SKNode()
        let chip: CGFloat = 5
        let inset: CGFloat = 8
        let w = boardRect.width - inset * 2
        let h = boardRect.height - inset * 2
        let spacing: CGFloat = 18

        func chipNode(at point: CGPoint, color: SKColor) {
            let node: SKShapeNode
            switch theme.motif {
            case .diamondChips, .diamondLattice:
                let path = CGMutablePath()
                path.move(to: CGPoint(x: 0, y: chip))
                path.addLine(to: CGPoint(x: chip, y: 0))
                path.addLine(to: CGPoint(x: 0, y: -chip))
                path.addLine(to: CGPoint(x: -chip, y: 0))
                path.closeSubpath()
                node = SKShapeNode(path: path)
            case .stepFret:
                node = SKShapeNode(
                    rectOf: CGSize(width: chip * 1.6, height: chip * 0.7))
            }
            node.fillColor = color
            node.strokeColor = .clear
            node.position = point
            root.addChild(node)
        }

        // Top and bottom rows.
        var x = -w / 2
        while x <= w / 2 {
            let color = motifColor(theme, x: x)
            chipNode(at: CGPoint(x: x, y: h / 2), color: color)
            chipNode(at: CGPoint(x: x, y: -h / 2), color: color)
            x += spacing
        }
        // Left and right columns.
        var y = -h / 2 + spacing
        while y <= h / 2 - spacing {
            let color = motifColor(theme, x: y)
            chipNode(at: CGPoint(x: -w / 2, y: y), color: color)
            chipNode(at: CGPoint(x: w / 2, y: y), color: color)
            y += spacing
        }
        return root
    }

    /// Lattice rows alternate lapis and gold; other motifs are solid gold.
    private static func motifColor(
        _ theme: RegionTheme, x: CGFloat
    ) -> SKColor {
        guard theme.motif == .diamondLattice else { return theme.gold }
        return Int(x.rounded()) % 2 == 0 ? theme.lapis : theme.gold
    }

    /// Build a tavern backdrop for a theme: wall, floor, side beams, a
    /// shelf with bottle silhouettes, and a lantern glow. Sized to `size`
    /// and centered at the origin.
    public static func tavernBackdrop(theme: RegionTheme, size: CGSize) -> SKNode {
        let root = SKNode()
        root.name = "tavernBackdrop"

        // Wall.
        let wall = SKShapeNode(
            rectOf: CGSize(width: size.width, height: size.height))
        wall.fillColor = theme.tavernWall
        wall.strokeColor = .clear
        wall.position = .zero
        wall.name = "tavernWall"
        root.addChild(wall)

        // Floor.
        let floorHeight = size.height * 0.18
        let floor = SKShapeNode(
            rectOf: CGSize(width: size.width, height: floorHeight))
        floor.fillColor = theme.bedding.withAlpha(0.85)
        floor.strokeColor = .clear
        floor.position = CGPoint(x: 0, y: -size.height / 2 + floorHeight / 2)
        floor.name = "tavernFloor"
        root.addChild(floor)

        // Side beams.
        let beamWidth = size.width * 0.05
        for side in [-1.0, 1.0] {
            let beam = SKShapeNode(
                rectOf: CGSize(width: beamWidth, height: size.height))
            beam.fillColor = theme.tavernBeam
            beam.strokeColor = .clear
            beam.position = CGPoint(
                x: side * (size.width / 2 - beamWidth / 2),
                y: 0)
            beam.name = "tavernBeam_\(side > 0 ? "right" : "left")"
            root.addChild(beam)
        }

        // Shelf with bottle silhouettes (lower-left margin, below the board).
        let shelfY = -size.height * 0.30
        let shelf = SKShapeNode(
            rectOf: CGSize(width: size.width * 0.4, height: 6))
        shelf.fillColor = theme.tavernBeam
        shelf.strokeColor = .clear
        shelf.position = CGPoint(x: -size.width * 0.28, y: shelfY)
        shelf.name = "tavernShelf"
        root.addChild(shelf)
        for i in 0..<3 {
            let bottle = SKShapeNode(
                rectOf: CGSize(width: 14, height: 34 + CGFloat(i) * 6),
                cornerRadius: 6)
            bottle.fillColor = theme.tavernBeam.withAlpha(0.85)
            bottle.strokeColor = theme.tavernGlow.withAlpha(0.5)
            bottle.lineWidth = 1.5
            bottle.position = CGPoint(
                x: -size.width * 0.28 - 40 + CGFloat(i) * 34,
                y: shelfY + 20 + CGFloat(i) * 3)
            bottle.name = "tavernBottle_\(i)"
            root.addChild(bottle)
        }

        // Lantern glow: concentric fading circles (lower-right margin).
        let glowCenter = CGPoint(x: size.width * 0.30, y: -size.height * 0.32)
        for (i, radius) in [CGFloat(70), 45, 24].enumerated() {
            let glow = SKShapeNode(circleOfRadius: radius)
            glow.fillColor = theme.tavernGlow.withAlpha(CGFloat(0.16) - CGFloat(i) * 0.04)
            glow.strokeColor = .clear
            glow.position = glowCenter
            glow.name = "tavernGlow_\(i)"
            root.addChild(glow)
        }
        let lantern = SKShapeNode(rectOf: CGSize(width: 18, height: 26), cornerRadius: 4)
        lantern.fillColor = theme.tavernGlow
        lantern.strokeColor = theme.tavernBeam
        lantern.lineWidth = 2
        lantern.position = glowCenter
        lantern.name = "tavernLantern"
        root.addChild(lantern)
        return root
    }
}
