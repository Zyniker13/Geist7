// SeededRNG.swift — deterministic SplitMix64 random source.
//
// _CONVENTIONS S0.2: Core/Content/AI take randomness only from
// SeededRNG. SplitMix64 (Steele, Lea & Douce 2014) is a small, fully
// invertible, exactly reproducible stream; the seed is recorded in
// Replay for verification.

public struct SeededRNG: Sendable {
    /// 0x9E3779B97F4A7C15 — golden gamma for SplitMix64.
    private static let gamma: UInt64 = 0x9E37_79B9_7F4A_7C15

    public private(set) var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func nextUInt64() -> UInt64 {
        state = state &+ Self.gamma
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in 0..<bound. Modulo bias is below 2^-33 for any
    /// bound < 2^31 (SplitMix64's low bits are well mixed), which is
    /// far below game-visible probabilities.
    public mutating func nextInt(below bound: Int) -> Int {
        precondition(bound > 0, "bound must be positive")
        return Int(nextUInt64() % UInt64(bound))
    }

    /// Uniform in [0, 1) as Fixed: top 32 bits of the u64 over 2^32.
    public mutating func nextFixed01() -> Fixed {
        Fixed(raw: Int64(bitPattern: nextUInt64() >> 32))
    }

    /// Uniform in [0, 1) as Double (UI-layer convenience only).
    public mutating func nextDouble01() -> Double {
        Double(nextUInt64() >> 11) / Double(1 << 53)
    }
}
