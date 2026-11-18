import RSCore

/// The doubling-cube decision policy (§7: Finkel's equity thresholds —
/// double at a win probability of 70% or more, take at 25% or more), with
/// the aggression shift the circuit personalities apply to the double
/// point (ADR-0010).
public enum CubePolicy {

    /// Offer a double at this own win probability (Finkel).
    public static let doubleThreshold: Double = 0.70

    /// Accept a double at this own win probability (Finkel).
    public static let takeThreshold: Double = 0.25

    /// The adjusted double point: every aggression point moves the
    /// threshold one percentage point down, clamped to [0.50, 0.95] so an
    /// aggressive bot never doubles from a losing position and a cautious
    /// one never waits past 95%.
    public static func doublePoint(aggression: Int) -> Double {
        let point = doubleThreshold - Double(aggression) * 0.01
        return min(0.95, max(0.50, point))
    }

    /// Whether a player with `winProbability` own equity should offer a
    /// double this turn.
    public static func shouldOffer(winProbability: Double, aggression: Int = 0) -> Bool {
        winProbability >= doublePoint(aggression: aggression)
    }

    /// Whether the decider with `winProbability` own equity should accept a
    /// pending double (otherwise they concede the match at the current
    /// stake).
    public static func shouldTake(winProbability: Double) -> Bool {
        winProbability >= takeThreshold
    }
}
