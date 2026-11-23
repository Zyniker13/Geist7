// DGCore.swift — module marker.
//
// DGCore is the deterministic rules package: hex lattice, courtyards,
// garden laws, engine, and the replay/hash foundation. It imports
// nothing but the Swift standard library and Foundation (for Codable
// only) — `Tools/check-imports.sh` enforces the boundary.

/// Namespace marker for the DGCore module.
public enum DGCore {
    /// Module version, bumped with meaningful engine changes.
    public static let version = "0.1.0"
}
