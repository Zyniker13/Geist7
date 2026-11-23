// Action.swift — the three player actions (R-4, R-5, R-6) and the
// resign action (R-30).

/// One player action. `place(cell, size, facing)` (R-4), `rake(start,
/// direction, length)` (R-5), `pass` (R-6), and `resign` (R-30).
public enum Action: Codable, Hashable, Sendable {
    case place(cell: Hex, size: StoneSize, facing: Int)
    case rake(start: Hex, direction: Int, length: Int)
    case pass
    case resign
}
