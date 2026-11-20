// MTPlatform — screen abstractions for Mattang.
//
// Owns: the platform abstraction for screens so the UI layer compiles
// and behaves identically on iOS/iPadOS and macOS (S0.4: one app
// target per platform, shared screens).

/// Module root. Screen services arrive with P2; P0 keeps the package
/// compiling with this placeholder.
public enum MTPlatformInfo {
    /// Package identity string, for build sanity checks.
    public static let identifier = "MTPlatform"
}
