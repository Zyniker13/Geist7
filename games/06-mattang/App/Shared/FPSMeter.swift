import Combine
import SwiftUI

/// Frame-rate source for the debug overlay (S0.7). Counts real display
/// frames via the platform display link; a one-second window is read on
/// the main run loop and published.
final class FPSMeter: ObservableObject, @unchecked Sendable {
    @Published var fps = 0

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

    /// Read the accumulated window and restart it. Called once a second
    /// from the main run loop.
    func rollWindow() {
        lock.lock()
        let counted = frames
        frames = 0
        lock.unlock()
        fps = counted
    }

    #if os(iOS)
        @objc private func frame(_ link: CADisplayLink) {
            countFrame()
        }
    #endif
}
