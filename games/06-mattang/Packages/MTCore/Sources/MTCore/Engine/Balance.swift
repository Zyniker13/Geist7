// Balance.swift — the tunable constants of the rules engine.
//
// These mirror `Resources/Content/balance.json` (§6 of the roadmap),
// which is the source of truth for the tunable values; MTContent (P3)
// loads that file for the UI. Every field holds to those values in
// every phase, so the engine carries them as constants here.

public enum Balance {
    /// R-8: a canoe may sail up to this many steps in one action.
    public static let sailRange = 3
    /// §5: ten blank island tokens start the pool.
    public static let islandPool = 10
    /// §5: four canoes per player, launched from the home atoll.
    public static let canoesPerPlayer = 4
    /// R-11: landing three canoes wins outright.
    public static let canoesToWin = 3
    /// R-9: a canoe becalms when it sits on a cell of this strength.
    public static let becalmedStrength = 0
    /// Tow destination must be within one step of the towed canoe (R-19).
    public static let towRange = 1
    /// Safety bound for sail path search: sailRange non-node steps plus
    /// generous room for free node hops (ADR-0007).
    public static let maxPathCells = sailRange + 24
    /// R-5/A.4: a ray ends after this many reflections (§6 tunable).
    public static let maxReflections = 3
    /// R-23: the third occurrence of a position ends the game by the
    /// R-11 tie-break (ADR-0013).
    public static let repetitionLimit = 3
}
