// Atoll.swift — a player's home atoll.
//
// R-5: a home atoll is a short chain of cells along one board edge.
// Atoll cells are never entered by rays (rays stop at the atoll
// boundary exactly as they stop at islands) and have strength 0;
// canoes launch from their own atoll and land on the rival atoll
// (R-10).

public struct Atoll: Hashable, Codable, Sendable {
    public let player: PlayerID
    public let cells: Set<Hex>

    public init(player: PlayerID, cells: Set<Hex>) {
        self.player = player
        self.cells = cells
    }
}
