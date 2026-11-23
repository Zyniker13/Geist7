// Stone.swift — a placed stone (R-4's result, R-12's viewer-facing stone).

/// One placed stone. Cells are unique across all stones (placement is
/// onto empty cells only), so `cell` identifies a stone within a state.
public struct Stone: Codable, Hashable, Sendable {
    /// Owning player.
    public var owner: PlayerID
    /// Lattice cell the stone occupies.
    public var cell: Hex
    /// Stone size.
    public var size: StoneSize
    /// Facing direction 0–5 (R-4); consumed by the viewing face rule (R-12).
    public var facing: Int

    public init(owner: PlayerID, cell: Hex, size: StoneSize, facing: Int) {
        self.owner = owner
        self.cell = cell
        self.size = size
        self.facing = facing
    }
}
