// RSPlatform — VoiceOver announcements (RS-P8.1)

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// Cross-platform VoiceOver announcements (RS-P8.1). The message builders
/// are pure so they can be unit-tested; `post` is the platform hook.
public enum AccessibilityAnnouncer {
    /// Post an announcement to the screen reader.
    public static func post(_ message: String) {
        #if canImport(UIKit)
            UIAccessibility.post(notification: .announcement, argument: message)
        #elseif canImport(AppKit)
            NSAccessibility.post(
                element: NSApp as Any,
                notification: .announcementRequested,
                userInfo: [NSAccessibility.NotificationUserInfoKey.announcement: message]
            )
        #endif
    }

    /// The announcement after a roll: the value, the legal moves, and the
    /// win rate (RS-P8.1: "announce roll, legal moves, and win rate").
    public static func rollAnnouncement(value: Int, legalMoves: Int, oddsText: String) -> String {
        let moves: String
        switch legalMoves {
        case 0: moves = "no legal moves"
        case 1: moves = "1 legal move"
        default: moves = "\(legalMoves) legal moves"
        }
        return "Rolled \(value). \(moves). \(oddsText)"
    }
}
