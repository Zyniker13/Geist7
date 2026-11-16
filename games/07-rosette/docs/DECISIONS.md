# Rosette — docs/DECISIONS.md

## ADR-0001: Deterministic RNG
- **Date:** 2026-11-16
- **Status:** Accepted
- **Summary:** All pseudo-random number generation in Core, Content, and AI modules uses `SeededRNG` (SplitMix64) instead of `SystemRandomNumberGenerator` or `Int.random(in:)`.
- **Rationale:** Replay and save/load require bit-identical game states across runs and platforms. `SystemRandomNumberGenerator` is not deterministic.
- **Consequences:** All RNG must flow through `SeededRNG`. Tests must seed deterministically.

## ADR-0002: Fixed-Point for Game State
- **Date:** 2026-11-16
- **Status:** Accepted
- **Summary:** All game-state fields that must survive save/load and replay verbatim use `Fixed` (fixed-point) instead of `Double`.
- **Rationale:** IEEE-754 floating-point may produce platform-specific rounding differences. Fixed-point ensures byte-identical state.
- **Consequences:** Display conversion (`doubleValue`) is lossy; only use for UI, never for state.
