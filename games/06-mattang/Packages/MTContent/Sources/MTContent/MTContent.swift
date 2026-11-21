// Package root for MTContent: static game content for Mattang.
//
// Owns: chart definitions (R-7 island layouts), text strings and
// terms (R-16), curriculum/atoll courses, and the Marshallese
// navigation terms glossary. Content lives in
// Sources/MTContent/Resources/Content/ as JSON, decoded here.
//
// Every cultural asset is listed in cultural_manifest.json with a
// `review_state` of "pending" until the Marshallese cultural advisor
// approves it (SRC10.x); pending assets may be rendered but a
// shipping build needs approval recorded in docs/SOURCING.md.
//
// The general content surface (charts, puzzles, voyages, tutorial)
// lives in Loader.swift; the P2 slice chart loader remains in
// SliceGame.swift and backs the general one.

/// Package identity string, for build sanity checks.
public enum MTContentInfo {
    /// Package identity string, for build sanity checks.
    public static let identifier = "MTContent"
}
