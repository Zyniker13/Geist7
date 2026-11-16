// DebugOverlay — in-game debug information display

import SwiftUI

/// A debug overlay that shows game state information.
/// Visible when the debug toggle is enabled (e.g., shake device).
public struct DebugOverlay: View {
  public let seed: UInt64
  public let turn: Int
  public let player: Int
  public let score: [Int: Int]
  public let fps: Double

  public init(
    seed: UInt64,
    turn: Int,
    player: Int,
    score: [Int: Int],
    fps: Double
  ) {
    self.seed = seed
    self.turn = turn
    self.player = player
    self.score = score
    self.fps = fps
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("seed: \(seed)")
        .font(.system(.caption, design: .monospaced))
      Text("turn: \(turn)")
        .font(.system(.caption, design: .monospaced))
      Text("player: \(player)")
        .font(.system(.caption, design: .monospaced))
      Text("fps: \(String(format: "%.1f", fps))")
        .font(.system(.caption, design: .monospaced))
      ForEach(Array(score.sorted(by: { $0.key < $1.key })), id: \.key) { entry in
        Text("P\(entry.key): \(entry.value)")
          .font(.system(.caption, design: .monospaced))
      }
    }
    .padding(4)
    .background(.ultraThinMaterial.opacity(0.8))
    .cornerRadius(4)
    .padding(8)
  }
}

#Preview {
  DebugOverlay(
    seed: 42,
    turn: 5,
    player: 1,
    score: [0: 10, 1: 15],
    fps: 60.0
  )
}
