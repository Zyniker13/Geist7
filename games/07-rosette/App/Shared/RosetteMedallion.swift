// MARK: - RosetteMedallion

import RSRender
import SpriteKit
import SwiftUI

/// Decorative namesake rosette for the main menu: the eight-petal lapis
/// rosette on a shell disc, drawn procedurally from the Ur theme
/// (RS-P6.1, ADR-0013 — geometry only, no assets).
struct RosetteMedallion: View {
    var body: some View {
        SpriteView(scene: Self.scene, options: [.allowsTransparency])
            .frame(width: 260, height: 260)
            .accessibilityHidden(true)
    }

    private static let scene: SKScene = {
        let scene = SKScene(size: CGSize(width: 220, height: 220))
        scene.scaleMode = .aspectFit
        scene.backgroundColor = .clear
        let medallion = BoardArt.rosetteFlower(
            theme: RegionTheme(region: .sumer), radius: 92)
        medallion.position = CGPoint(x: 110, y: 110)
        scene.addChild(medallion)
        return scene
    }()
}
