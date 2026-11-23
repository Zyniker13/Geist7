// Group.swift — R-13/R-26 group analytics on top of Score.groups.
//
// The scoring math lives in `Score`; this file carries the group
// queries the AI and UI need (sizes, parity, membership).

public enum Group {

    /// Group sizes for one player's stones, in discovery order.
    public static func sizes(of stones: [Stone]) -> [Int] {
        Score.groups(of: stones).map(\.count)
    }

    /// R-13: whether the group containing `stone` is odd-sized.
    public static func isOddGroup(
        containing stone: Stone, in stones: [Stone]
    ) -> Bool {
        for group in Score.groups(of: stones)
        where group.contains(where: { $0.cell == stone.cell }) {
            return group.count % 2 == 1
        }
        return false
    }

    /// Groups that would MERGE if a new stone of `player` landed at
    /// `cell` (the parity-potential signal A.5's evaluation uses).
    public static func affectedGroupParity(
        placingStoneAt cell: Hex, owner: PlayerID, in stones: [Stone]
    ) -> Int {
        let nearby = stones.filter {
            $0.owner == owner && cell.distance(to: $0.cell) <= 2
        }
        if nearby.isEmpty { return 1 }  // a fresh singleton group is odd
        return sizes(of: nearby).reduce(0, +) + 1
    }
}
