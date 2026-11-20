// MTRender — presentation for Mattang (R-9 visual rules).
//
// Owns: the visual field (all rendering), the stylized chart view,
// ocean and swell shaders, and screen-safe light/shadow logic. Reads
// engine state through the visual-field abstraction; never mutates
// engine state. The decoupling is formalized in ADR-0005: the visual
// field is a separate computed layer so presentation never affects
// the deterministic engine core.
//
// P2 brings the Metal swell shaders; P0 keeps the package compiling
// with this placeholder.

/// Module root.
public enum MTRenderInfo {
    /// Package identity string, for build sanity checks.
    public static let identifier = "MTRender"
}
