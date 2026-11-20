// MTAI — seeded computer opponents for Mattang.
//
// Owns: the three difficulty tiers' ray-reading logic, pure functions
// over the public engine state. Every stochastic choice flows from the
// caller-provided SeededRNG (S0.2); opponents are fully reproducible
// under a recorded seed.

/// Module root. Opponent tiers arrive with P5; P0 keeps the package
/// compiling with this placeholder.
public enum MTAIInfo {
    /// Package identity string, for build sanity checks.
    public static let identifier = "MTAI"
}
