import MTCore
import SwiftUI

/// In-app debug overlay (S0.7): FPS, tick, seed, state hash.
/// Toggled by a three-finger double tap on iPad and ⌘⇧D on Mac;
/// `-debugOverlay` forces it on for tests and screenshots.
struct DebugOverlay: View {
    let seed: UInt64
    let tick: Int
    /// A precomputed hash line (the match screen passes the live
    /// state hash); nil keeps the seed+tick hash of the P0 overlay.
    var hashTextOverride: String? = nil

    // @StateObject, not @ObservedObject: the overlay re-renders on
    // every ply (tick/hash text changes), and an @ObservedObject
    // initialized inline is recreated each time — the meter's display
    // link died before its one-second window ever rolled.
    @StateObject private var meter = FPSMeter()
    @State private var hashText = ""

    var body: some View {
        // The one-second cadence comes from TimelineView, not a
        // Combine timer: an `.onReceive(Timer.publish(every: 1))`
        // subscription is rebuilt on every parent re-render, and the
        // match screen re-renders several times a second under
        // auto-pilot — the interval never matured, so the fps read
        // froze at 0 there (the menu, which never re-renders, read
        // 60). TimelineView's own schedule is immune to re-renders;
        // each tick rolls the meter's window and re-reads every line.
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(alignment: .leading, spacing: 2) {
                Text("fps \(meter.currentFPS())")
                Text("tick \(tick)")
                Text("seed \(seed)")
                Text("hash \(hashTextOverride ?? hashText)")
                // The pulse keeps the render loop committing frames
                // while the debug overlay is visible, so the fps meter
                // reports the loop's actual sustained rate instead of
                // reading near zero on a scene that is intentionally
                // static between plies (ADR-0016; the P6 Metal wave
                // field animates for real). Debug builds only — release
                // compiles the whole overlay out.
                TimelineView(.animation) { pulse in
                    Circle()
                        .fill(
                            Color.green.opacity(
                                0.18 + 0.18
                                    * sin(
                                        pulse.date.timeIntervalSinceReferenceDate
                                            * 4)))
                }
                .frame(width: 6, height: 6)
            }
            .font(.caption2.monospaced())
            .padding(6)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
        .task {
            meter.start()
            guard hashTextOverride == nil else { return }
            let state = DebugState(seed: seed, tick: tick)
            let hash = try? StateHashing.stableHash(state)
            hashText = hash.map { String(format: "0x%016llX", $0) } ?? "unavailable"
        }
        .onDisappear { meter.stop() }
        .allowsHitTesting(false)
    }
}

private struct DebugState: Codable {
    var seed: UInt64
    var tick: Int
}
