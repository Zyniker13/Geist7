import SwiftUI

#if os(iOS)
    import UIKit

    /// Three-finger double tap recognizer exposed to SwiftUI (S0.7).
    struct ThreeFingerDoubleTap: UIViewRepresentable {
        var onTap: () -> Void

        func makeUIView(context: Context) -> UIView {
            let view = UIView(frame: .zero)
            view.isUserInteractionEnabled = true
            let recognizer = UITapGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.fire)
            )
            recognizer.numberOfTouchesRequired = 3
            recognizer.numberOfTapsRequired = 2
            view.addGestureRecognizer(recognizer)
            return view
        }

        func updateUIView(_ uiView: UIView, context: Context) {
            context.coordinator.onTap = onTap
        }

        func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

        final class Coordinator: NSObject {
            var onTap: () -> Void
            init(onTap: @escaping () -> Void) { self.onTap = onTap }
            @objc func fire() { onTap() }
        }
    }
#endif

/// Invisible Mac shortcut button for the same toggle (⌘⇧D).
struct DebugShortcut: View {
    var onToggle: () -> Void

    var body: some View {
        Button("Toggle Debug Overlay") { onToggle() }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
    }
}
