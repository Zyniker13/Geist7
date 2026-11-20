// MTMeta — meta layer for Mattang.
//
// Owns: settings, progression, stats, the tutorial mode, and screen
// services shared by iOS and macOS. Depends on MTCore, MTContent,
// and MTAI; App targets depend on MTMeta.

/// Module root. Settings and progression arrive with P4/P6; P0 keeps
/// the package compiling with this placeholder.
public enum MTMetaInfo {
    /// Package identity string, for build sanity checks.
    public static let identifier = "MTMeta"
}
