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

## ADR-0003: Per-Owner Path Index Space
- **Date:** 2026-11-16
- **Status:** Accepted
- **Summary:** Piece positions are path indices (0-based 0..<trackLength) in the owning player's own path. Both players share one 14-slot layout (4 private start squares, 8 shared squares, 2 private exit squares); private slots can only ever hold their owner's pieces, so encounters between players happen only on shared slots 4-11. Rendering (P2) maps path index + owner to physical board squares.
- **Rationale:** R-1 gives each player a 14-step path with one shared middle run. A single index space per player keeps move generation, blocking, and capture logic uniform for both players and defers physical board geometry to the renderer.
- **Consequences:** Entry lands on path step 0 and consumes any non-zero roll (the roadmap does not pin entry semantics; this follows the standard Finkel/RoyalUr reconstruction). Square labels are startPrivate/shared/exitPrivate rather than per-player.

## ADR-0005: Wager and Omen Flow Details
- **Date:** 2026-11-16
- **Status:** Accepted
- **Summary:** (1) A cube offer is a proposal only: the stake and cube change when the offer is accepted (stake x2, cube passes to the accepter, R-10). (2) Declining by conceding loses the current stake without the gammon multiplier — R-11's gammon applies to completed matches. (3) A double may be offered or accepted only once per turn (R-21), tracked by `hasDoubledThisTurn`; omens must be played before doubling in the same turn. (4) Omens: one per player per match (R-12), played before the roll; re-roll replacement draws come from the separate omen RNG stream (INV-7); a split roll divides into floor(v/2) + remainder and excludes entry moves (entering spends the whole roll); the safety omen makes safe rosettes capturable for the rest of the turn. (5) `RuleSet` is a superset of the roadmap §5 `RuleSetDef`: it adds a display `label: String` alongside `historyLabel`, names the dice reference `diceModel`, and adds `moveGenerator` for variant support (RS-P1.3).
- **Rationale:** These details follow the roadmap's rule text where it is explicit and choose the standard backgammon-consistent reading where it is silent.
- **Consequences:** The reducer's cube/omen behavior is fixed for the UI (P2/P3) and AI (P4); changes require updating the tagged tests.

## ADR-0006: Lint Toolchain Reconciliation (swift-format 604)

- **Date:** 2026-11-16
- **Status:** Accepted
- **Summary:** Apple swift-format 604.0.0 (what current Homebrew installs and what CI gets) makes trailing commas in multiline collection literals canonical: its `format` adds them and its `lint` warns for their absence regardless of the `trailingCommas` setting. This conflicts with SwiftLint's `trailing_comma` rule, which forbids them. Resolution: adopt swift-format 604 style (trailing commas present) and disable SwiftLint's `trailing_comma` rule in `.swiftlint.yml`. All swift-format invocations in the Makefile and CI workflow pass `--configuration .swift-format` explicitly, because recursive mode does not auto-discover the config file.
- **Rationale:** The two tools cannot be satisfied simultaneously on this rule with the current toolchain; swift-format's style is the one CI inherits automatically from Homebrew, so aligning on it and relaxing the SwiftLint rule keeps `make lint` and CI reproducible.
- **Consequences:** Package manifests and collection literals carry trailing commas; the earlier working note "trailing commas forbidden" no longer applies. Package manifests also declare `platforms: [.iOS(.v26), .macOS(.v26)]` with `swift-tools-version: 6.2` so package deployment targets match the app (26.0) on every toolchain (CI runs Xcode 26.6, which otherwise defaults packages below iOS 13 and fails on SwiftUI availability).
