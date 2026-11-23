// Ownership.swift — per-cell owner queries over an incremental tally
// store (R-11, INV-2's incremental path).
//
// The engine keeps per-cell tallies incrementally as stones and rakes
// land; the from-scratch engine recomputes everything. INV-2 requires
// the two to agree, which the property tests hammer over thousands of
// games.

/// Incremental influence store: applies the DELTA of each action to
/// the per-cell tallies, never recomputing from scratch (INV-2's
/// incremental path; A.6 DG-P1.5's "< 0.2 ms incremental update").
public struct Ownership: Sendable {
    /// Per-cell tallies.
    public private(set) var tallies: [Hex: InfluenceTally] = [:]
    /// The balance's curves (curve changes rebuild nothing; the store
    /// is rebuilt per game).
    private let balance: Balance
    private let courtyard: Courtyard

    public init(courtyard: Courtyard, balance: Balance = .standard()) {
        self.courtyard = courtyard
        self.balance = balance
    }

    /// R-11: the owner of a cell from the current tallies.
    public func owner(of cell: Hex) -> PlayerID? {
        tallies[cell]?.owner
    }

    /// R-11: the influence margin at a cell.
    public func margin(at cell: Hex) -> Int {
        tallies[cell]?.margin ?? 0
    }

    /// The tally at a cell (0–0 when the cell has no influence).
    public func tally(at cell: Hex) -> InfluenceTally {
        tallies[cell] ?? InfluenceTally()
    }

    /// Owned-cell counts per player (R-14's first term).
    public func ownedCellCounts() -> [PlayerID: Int] {
        var counts: [PlayerID: Int] = [.one: 0, .two: 0]
        for cell in courtyard.cells {
            guard let tally = tallies[cell], let owner = tally.owner else {
                continue
            }
            counts[owner, default: 0] += 1
        }
        return counts
    }

    /// Applies one placed stone's influence delta.
    public mutating func applyStonePlacement(
        _ stone: Stone, context: [Stone], balance: Balance
    ) {
        InfluenceEngine.applyStone(
            stone, cells: courtyard.cells,
            curve: balance.curve(for: stone.size),
            bonus: InfluenceEngine.viewingBonus(
                for: stone, stones: context, balance: balance),
            into: &tallies)
    }

    /// Applies one rake line's influence delta (R-10).
    public mutating func applyRake(_ rake: RakeLine, anchorSize: StoneSize) {
        InfluenceEngine.applyRake(
            rake, anchorValue: balance.curve(for: anchorSize)[1],
            courtyard: courtyard, into: &tallies)
    }

    /// Full rebuild from a state (used after load and by the INV-2
    /// cross-check).
    public mutating func rebuild(state: GameState, balance: Balance) {
        tallies = InfluenceEngine.computeAll(
            courtyard: courtyard, stones: state.stones, rakes: state.rakes,
            balance: balance)
    }
}
