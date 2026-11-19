// MARK: - HapticFeedback
//
// RS-P8.4: haptic feedback. Captures fire a short impact; match end fires
// a distinct notification. A persisted preference switch (default on)
// gates the router, and the Settings screen exposes it.

import Foundation
import RSCore

#if canImport(UIKit)
    import UIKit
#endif

/// Haptic-feedback preferences (RS-P8.4): a persisted on/off switch,
/// default on. The key is shared with the Settings screen's `@AppStorage`
/// binding so both layers read one source of truth. Main-actor isolated
/// like the rest of the haptic stack: feedback plays on the UI thread.
@MainActor
public final class HapticPreferences {
    /// The UserDefaults key for the enabled flag.
    public static let enabledKey = "haptics.enabled"

    private let defaults: UserDefaults

    /// Build preferences against a defaults store.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Whether haptic feedback plays for captures and match end
    /// (default: on when the key is unset).
    public var isEnabled: Bool {
        get {
            defaults.object(forKey: Self.enabledKey) == nil
                ? true
                : defaults.bool(forKey: Self.enabledKey)
        }
        set { defaults.set(newValue, forKey: Self.enabledKey) }
    }
}

/// The haptic actions the game plays (RS-P8.4). Implementations translate
/// the abstract moments into platform feedback; tests record instead.
/// Main-actor isolated: haptic hardware feedback is a UI concern.
@MainActor
public protocol HapticPlaying: AnyObject {
    /// A piece was captured: a short, sharp impact.
    func captureOccurred()
    /// The match ended: a distinct success notification.
    func matchEnded()
}

#if canImport(UIKit)
    /// UIKit haptic player (RS-P8.4): a medium impact for captures and a
    /// success notification for match end.
    @MainActor
    public final class UIKitHapticPlayer: HapticPlaying {
        private let captureGenerator = UIImpactFeedbackGenerator(style: .medium)
        private let endGenerator = UINotificationFeedbackGenerator()

        public init() {}

        public func captureOccurred() {
            captureGenerator.impactOccurred()
        }

        public func matchEnded() {
            endGenerator.notificationOccurred(.success)
        }
    }
#endif

/// A no-op player for platforms without a haptic hardware contract (macOS)
/// and for tests.
@MainActor
public final class NoopHapticPlayer: HapticPlaying {
    public init() {}

    public func captureOccurred() {}
    public func matchEnded() {}
}

/// Routes match events to haptic feedback (RS-P8.4). The game view
/// forwards the engine's event stream here, mirroring the audio layer; the
/// router fires the mapped feedback only while the preference is enabled.
/// Main-actor isolated: it runs alongside the view that owns the event
/// stream.
@MainActor
public final class HapticsRouter {
    private let preferences: HapticPreferences
    private let player: HapticPlaying

    /// Build a router with the given preferences and player.
    public init(
        preferences: HapticPreferences = HapticPreferences(),
        player: HapticPlaying
    ) {
        self.preferences = preferences
        self.player = player
    }

    /// The default player for the current platform: UIKit generators on
    /// iOS; a no-op on macOS, which has no haptic hardware contract.
    public static func defaultPlayer() -> HapticPlaying {
        #if canImport(UIKit)
            return UIKitHapticPlayer()
        #else
            return NoopHapticPlayer()
        #endif
    }

    /// Handle a batch of engine events: captures impact, match end
    /// notifies, everything else stays silent.
    public func handle(events: [Event]) {
        guard preferences.isEnabled else { return }
        for event in events {
            switch event {
            case .pieceCaptured:
                player.captureOccurred()
            case .matchWon:
                player.matchEnded()
            default:
                break
            }
        }
    }
}
