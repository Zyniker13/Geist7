// RSPlatform — Reduce Motion policy (RS-P8.1)

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// Reduce Motion handling for the dice animation (RS-P8.1). The dice pop
/// is skipped when the system setting is on; the board itself is static.
public enum MotionPolicy {
    /// Whether the dice pop should run for a given Reduce Motion setting.
    public static func diceTumbleEnabled(reduceMotion: Bool) -> Bool {
        !reduceMotion
    }

    /// The system Reduce Motion setting on this platform.
    public static var systemReduceMotion: Bool {
        #if canImport(UIKit)
            return UIAccessibility.isReduceMotionEnabled
        #elseif canImport(AppKit)
            return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #else
            return false
        #endif
    }
}
