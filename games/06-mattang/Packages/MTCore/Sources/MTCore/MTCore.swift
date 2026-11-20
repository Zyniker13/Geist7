// MTCore — the deterministic engine core for Mattang.
//
// Owns: Foundation (Fixed Q32.32, SeededRNG), Grid (axial hex,
// directions, face normals, reflection), Swell (swell field model),
// Pieces (game pieces), Engine (turn state machine).
//
// Determinism ban: no system RNG, no randomness APIs, no wall-clock
// time, and no UUIDs in this package (enforced by Tools/check-imports.sh
// and the swiftlint banned_api rule). All randomness flows through
// SeededRNG; all math runs on Fixed.

/// Module root. Types live in topic files; this file holds shared
/// module-level helpers only.

/// Floored modulo: result always in `0..<m` even for negative operands.
/// Swift's `%` is truncated, which is wrong for wrap-around indexing.
@inlinable
public func flooredMod(_ value: Int, _ m: Int) -> Int {
    precondition(m > 0, "modulus must be positive")
    let r = value % m
    return r < 0 ? r + m : r
}
