/// A fixed, caller-supplied dice stream (P5 daily match).
///
/// The k-th roll of the match is the k-th value of the sequence, no matter
/// how the players move: every player facing the same date draws the same
/// dice. When the sequence is exhausted the engine falls back to the seeded
/// RNG so a short sequence can never stall a match (INV-1).
///
/// This is a replay input, not gameplay state: it is deliberately excluded
/// from `MatchState.stateHash` (INV-4) and from `MatchState` itself.
///
/// A reference type so `Reducer.apply` can take it with a default of `nil`
/// (Swift forbids defaults on `inout` parameters) and the driver's cursor
/// advances across calls. The match driver is single-threaded; the class is
/// not safe for concurrent use.
public final class DiceSource: @unchecked Sendable {
    private let values: [Int]
    public private(set) var index: Int

    public init(values: [Int]) {
        self.values = values
        self.index = 0
    }

    /// The next fixed roll, or `nil` once the sequence is exhausted.
    public func next() -> Int? {
        guard index < values.count else { return nil }
        defer { index += 1 }
        return values[index]
    }
}
