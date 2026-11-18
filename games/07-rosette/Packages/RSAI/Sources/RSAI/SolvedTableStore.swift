import Foundation
import RSCore

/// Loads and holds the solved win-probability table for the Finkel ruleset
/// (RS-P4.1). The table ships inside RSAI's resource bundle as
/// `ur_finkel.bin` (26 KB, delta-varint compressed; ADR-0010); when it is
/// absent the store degrades to nil and the AI falls back to expectiminimax
/// — the same fallback P7 uses when the table moves to on-demand resources.
public final class SolvedTableStore: Sendable {

    /// The loaded table, or nil when the resource is missing or unreadable.
    public let table: UrTable?

    /// Load from the package resource bundle.
    public convenience init() {
        self.init(
            url: Bundle.module.url(forResource: "ur_finkel", withExtension: "bin"))
    }

    /// Load from an explicit URL (tests and tooling).
    public init(url: URL?) {
        guard let url, let data = try? Data(contentsOf: url),
            let table = try? UrTable.deserialize(data)
        else {
            self.table = nil
            return
        }
        self.table = table
    }

    /// Wrap an already-loaded table (tests).
    public init(table: UrTable?) {
        self.table = table
    }

    /// The win probability of the player about to roll in `position`.
    /// Returns nil when no table is loaded or the position is outside the
    /// table's coverage (never an out-of-range index).
    public func winProbability(forRoller position: UrPosition) -> Double? {
        guard let table, table.covers(position) else { return nil }
        return table.winProbability(at: position)
    }

    /// Whether a table is loaded and usable.
    public var isAvailable: Bool { table != nil }
}
