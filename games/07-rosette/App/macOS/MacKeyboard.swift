import AppKit
import SwiftUI

/// Installs a local key monitor so keys 1-7 pick a piece on macOS
/// (RS-P7.2b). The handler is injected so the view model's
/// `handleNumberKey` can be exercised in tests without a live monitor.
///
/// The monitor swallows the number keys 1-7 (so they don't also reach text
/// fields) and forwards them to `onKey` on the main actor. All other keys
/// pass through.
struct MacKeyboardHandler: ViewModifier {
    let onKey: @MainActor (Int) -> Void
    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear {
                installMonitor()
            }
            .onDisappear {
                removeMonitor()
            }
    }

    private func installMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let char = event.charactersIgnoringModifiers?.first,
                let digit = char.wholeNumberValue,
                (1...7).contains(digit)
            else {
                return event
            }
            // The local monitor handler runs on the main thread.
            MainActor.assumeIsolated {
                onKey(digit)
            }
            return nil // swallow: the number key is consumed by the board
        }
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}

extension View {
    /// Enable the Mac keyboard 1-7 piece picker (RS-P7.2b).
    func macKeyboard(_ onKey: @escaping @MainActor (Int) -> Void) -> some View {
        modifier(MacKeyboardHandler(onKey: onKey))
    }
}
