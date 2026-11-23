import DGCore
import SwiftUI

/// In-app debug overlay (S0.7): FPS, tick, seed, state hash.
/// Toggled by a three-finger double tap on iPad and ⌘⇧D on Mac;
/// `-debugOverlay` forces it on for tests and screenshots.
struct DebugOverlay: View {
    let seed: UInt64
    let tick: Int

    // @StateObject, not @ObservedObject: an @ObservedObject initialized
    // inline is recreated on each parent re-render, which kills the
    // display link before its one-second window ever rolls (the Mattang
    // precedent; same failure mode here).
    @StateObject private var meter = FPSMeter()
    @State private var hashText = ""

    var body: some View {
        // One-second cadence from TimelineView, not a Combine timer: a
        // timer subscription is rebuilt on every parent re-render and
        // the interval never matures (Mattang precedent).
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(alignment: .leading, spacing: 2) {
                Text("fps \(meter.currentFPS())")
                Text("tick \(tick)")
                Text("seed \(seed)")
                Text("hash \(hashText)")
                // The pulse keeps the render loop committing frames
                // while the overlay is visible, so the fps meter
                // reports the loop's actual sustained rate. Debug
                // builds only — release compiles the overlay out.
                #if DEBUG
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
                #endif
            }
            .font(.caption2.monospaced())
            .padding(6)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
        .task {
            meter.start()
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
