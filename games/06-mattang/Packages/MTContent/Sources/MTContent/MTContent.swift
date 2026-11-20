// MTContent — static game content for Mattang.
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

/// Module root. Content types arrive with P3; P0 keeps the package
/// compiling with this placeholder and the JSON resources in place.
public enum MTContentInfo {
    /// Package identity string, for build sanity checks.
    public static let identifier = "MTContent"
}
