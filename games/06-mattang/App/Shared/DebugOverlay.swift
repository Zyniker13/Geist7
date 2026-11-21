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

    @ObservedObject private var meter = FPSMeter()
    @State private var hashText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("fps \(meter.fps)")
            Text("tick \(tick)")
            Text("seed \(seed)")
            Text("hash \(hashTextOverride ?? hashText)")
        }
        .font(.caption2.monospaced())
        .padding(6)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            meter.rollWindow()
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
