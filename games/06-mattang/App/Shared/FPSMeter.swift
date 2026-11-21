import Combine
import SwiftUI

/// Frame-rate source for the debug overlay (S0.7). Counts real display
/// frames via the platform display link; the overlay's one-second
/// TimelineView tick rolls the window and reads the count in one call.
/// The meter publishes nothing: rolling a @Published value during view
/// updates would re-publish and re-render in a loop (the blank-screen
/// spin this file once caused).
final class FPSMeter: ObservableObject, @unchecked Sendable {
    private let lock = NSLock()
    private var frames = 0

    #if os(iOS)
        private var displayLink: CADisplayLink?
    #else
        private var displayLink: CVDisplayLink?
    #endif

    func start() {
        #if os(iOS)
            let link = CADisplayLink(target: self, selector: #selector(frame(_:)))
            link.add(to: .main, forMode: .common)
            displayLink = link
        #else
            var link: CVDisplayLink?
            CVDisplayLinkCreateWithActiveCGDisplays(&link)
            if let link {
                let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
                CVDisplayLinkSetOutputCallback(
                    link,
                    { _, _, _, _, _, context in
                        guard let context else { return kCVReturnError }
                        let meter = Unmanaged<FPSMeter>.fromOpaque(context).takeUnretainedValue()
                        meter.countFrame()
                        return kCVReturnSuccess
                    }, context)
                CVDisplayLinkStart(link)
                displayLink = link
            }
        #endif
    }

    func stop() {
        #if os(iOS)
            displayLink?.invalidate()
            displayLink = nil
        #else
            if let displayLink {
                CVDisplayLinkStop(displayLink)
            }
            displayLink = nil
        #endif
    }

    private func countFrame() {
        lock.lock()
        frames += 1
        lock.unlock()
    }

    /// Roll the one-second window and return the counted frames. Safe
    /// to call from the overlay's TimelineView content: it touches no
    /// published state, so the read cannot re-trigger the render.
    func currentFPS() -> Int {
        lock.lock()
        let counted = frames
        frames = 0
        lock.unlock()
        return counted
    }

    #if os(iOS)
        @objc private func frame(_ link: CADisplayLink) {
            countFrame()
        }
    #endif
}
