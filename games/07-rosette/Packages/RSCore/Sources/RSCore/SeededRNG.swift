import Foundation

/// A deterministic pseudo-random number generator based on SplitMix64.
///
/// Replaces the system RNG in all
/// Core, Content, and AI modules so that every game is reproducible from
/// a single seed.
public struct SeededRNG: Sendable {
    private var state: UInt64

    /// Initialise with the given 64-bit seed.
    public init(seed: UInt64) {
        self.state = seed
    }

    /// Return the next 64-bit pseudo-random value.
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var zState: UInt64 = state
        zState &+= (zState &<< 30) & 0xFFFF_FFFF_FFFF_FFFF
        zState &*= 0xBF58_476D_1CE4_E5B9
        zState &+= (zState &<< 27) & 0xFFFF_FFFF_FFFF_FFFF
        zState &*= 0x94D0_49BB_1331_11EB
        zState &+= (zState &<< 31) & 0xFFFF_FFFF_FFFF_FFFF
        return zState
    }

    /// Return a value in `[0, limit)`.
    public mutating func next(_ limit: UInt64) -> UInt64 {
        precondition(limit > 0, "limit must be positive")
        var result = next()
        let threshold = (UInt64.max - limit + 1) / limit * limit
        while result >= threshold {
            result = next()
        }
        return result % limit
    }

    /// Return a value in `[0, count)` as an `Int`.
    public mutating func next(_ count: Int) -> Int {
        precondition(count > 0, "count must be positive")
        return Int(next(UInt64(count)))
    }
}
