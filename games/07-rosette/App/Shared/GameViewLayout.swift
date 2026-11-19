// MARK: - GameViewLayout

import SwiftUI

/// Pure layout decisions for the left-handed setting (RS-P8.4). Kept free
/// of view-model and view code so unit tests can pin them.
enum GameViewLayout {
    /// The `@AppStorage`/UserDefaults key for the left-handed toggle.
    static let leftHandedKey = "layout.leftHanded"

    /// The SwiftUI layout direction for the handedness setting: mirroring
    /// the HUD containers swaps which side carries the primary controls
    /// (the action row) and each player's info block, so players can pick
    /// the arrangement that suits their grip. The default is the layout
    /// shown in the P5/P6 evidence.
    static func layoutDirection(leftHanded: Bool) -> LayoutDirection {
        leftHanded ? .rightToLeft : .leftToRight
    }
}
