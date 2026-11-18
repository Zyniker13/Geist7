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

## ADR-0007: Content Has a Single Home in RSContent, with Named Def Extras

- **Date:** 2026-11-17
- **Status:** Accepted
- **Summary:** All content JSON lives in `Packages/RSContent/Sources/RSContent/Resources/Content/` (SwiftPM bundle resources) and is loaded only through `ContentLoader`; the game-root `Resources/Content/` duplicate was removed. The Codable Def types (`RulesetDef`, `TavernDef`, `OpponentDef`, `OmenDef`, `DiceModelDef`, `FortuneSquareDef`, `CircuitDef`/`RegionDef`, `TutorialLessonDef`, `BalanceDef`) live in RSCore (`Circuit/ContentTypes.swift`) and mirror the roadmap §5 / Appendix A.3 fields field-for-field. Justified extras beyond the roadmap schemas, each needed by a concrete consumer: `RulesetDef.name` and `OmenDef.name` (the shop and history UI need display names), `TavernDef.name`, `TavernDef.gammonRule` (R-11's per-tavern toggle, §6), `TavernDef.historyNote`/`OpponentDef.historyNote`/`OmenDef.historyNote` (HIST3.1 in-game notes), and `RulesetDef.moveGenerator` (routes "ur"/"senet-like"/"patolli-like" to the P1 generators).
- **Rationale:** One copy of content prevents the divergence found during P3 (two copies had already drifted; the game-root copy carried malformed data). SwiftPM bundle resources load identically on iOS, iPadOS, and macOS. The extras are all referenced by the P3 UI or by existing rules; none is speculative.
- **Consequences:** Content edits happen in one place; `content-lint` and `RSContentTests.validateAll` validate that copy. Engine types are built from Defs, never parsed directly from JSON.

## ADR-0008: Fortune Squares Are Deterministic Square-Triggered Omen Draws

- **Date:** 2026-11-17
- **Status:** Accepted
- **Summary:** R-16's Tablet fortunes are implemented as `FortuneSquare(rulesetId, square, deck)` where deck ∈ {good, bad}. When a piece lands on a fortune square of the match's ruleset, the reducer appends a `omenPlayed` event for the square's deck and applies the deck's fixed effect — good: the landing player takes another roll; bad: the landing piece is sent home (any rosette extra roll from the same landing is cancelled). No RNG draw is consumed (INV-7 untouched), and a pending played omen takes precedence (the fortune does not overwrite it).
- **Rationale:** The tablet attests that squares carry fortunes, not what they do, so the effects are Invented (HIST3.1); a square-keyed deterministic effect keeps replays bit-identical (INV-4) and avoids adding a third RNG stream.
- **Consequences:** Fortune content lives in `fortunes.json`; `FortuneTests` pins the good/bad behavior, the ruleset scoping, and stream-neutrality. The odds panel need not model fortunes (they are event effects, not probability changes — R-23).

## ADR-0009: R-13 "Cheapest Available Buy-in" Means Entry Cost = Buy-in + Minimum Stake; a Loss Re-challenges

- **Date:** 2026-11-17
- **Status:** Accepted
- **Summary:** `CircuitState.isRunEnded` fires when the purse is below `min(remaining taverns' buyIn + minStake)`. A loss at a tavern leaves the player there; advancing to the next tavern requires winning ("Sit Down" pays the buy-in again for a re-challenge). A win followed by `advanceTavern()` walks the ladder in content order.
- **Rationale:** Taken literally, "purse below the cheapest available buy-in" could seat a player whose remaining purse is between buy-in and buy-in + minimum stake; R-9 then allows no legal stake and the run softlocks. Reading "available" as "usable for one legal match" preserves both R-9 and R-13's intent (the run ends when the circuit can no longer be played). Re-challenge-on-loss gives the purse drain its meaning: a hard tavern costs money until beaten.
- **Consequences:** Recorded here because the roadmap's wording admits the softlock reading. `CircuitSimulationTests` pins: run ends exactly when re-entry is unaffordable, a loss does not advance, a win advances. The G4 balance task still tunes purse/buy-ins so the 55–70% optimal-bot completion target is reachable (OQ-004).

## ADR-0010: MatchBot AI Architecture — Budgeted Expectiminimax with Table Equity Fallback

- **Date:** 2026-11-18
- **Status:** Accepted
- **Summary:** All match-playing bots conform to `MatchBot` (P3's `RosetteBot` extended; cube methods default). Tier-3 `OptimalBot` runs depth-limited expectiminimax over the exact rules (move and omen nodes, star1 chance pruning, fail-soft alpha-beta, move ordering by leaf heuristic) with three guards: a `NodeBudget` of `256 * (depth + 2)` total nodes per search, a path-based cycle detector for the 0-outcome auto-pass loop that `tetra4` dice produce, and an exact-only transposition table keyed by `stateHash ^ (remaining << 56)` shared across root children. Equity falls back through: solved-table lookup (`TableBridge` → `UrTable.covers`/`index`) when the position is covered, else EMM; uncovered leaves score with an antisymmetric material+safety heuristic (`pipsOpp − pipsMe + 6·rosettes + 4·safe + 5·exposed`), negated across players so `complementaryValues` holds. Tier-2 `VariantBot` is the same search with rollout-based cube and omen policies; the G4 naive tier is `RosetteBot(.gambler, strength: 1)`.
- **Rationale:** A raw EMM search on `tetra4` dice recurses without progress through 0-outcome passes (SIGBUS in early testing), so unbounded recursion is unsound; the budget plus cycle detection bounds every search. The transposition table cut pre-roll decision cost from ~1,020 ms to ~37 ms at depth 2. The solved table shipped with P1 is a two-piece fixture: `covers` demands both hands equal the table's piece count and no private/shared pieces, so in 7-piece matches it never answers and every decision runs EMM — the table path exists for the P7 on-demand 7-piece table and is exercised by SolveTests. The naive tier is intentionally the P3 heuristic bot at its weakest strength rather than a new implementation, matching the roadmap's tiering.
- **Consequences:** `RSAITests` pins determinism (equal states → equal decisions under differing RNG streams), antisymmetry, budget/cycle bounds, cube policy behavior, replay equality (INV-4), and the G4 completion-rate bands. `UrTable.covers` must convert the packed shared field to the ranking's base-3 pattern before indexing (`testTable_CoversHandlesPackedSharedMasks` pins this; raw-mask indexing crashed on any occupied square past the fourth). Decision latency is guarded loosely in tests (2 s) and measured against the G4 budgets in `docs/STATUS.md`.

## ADR-0011: Circuit Calibration Harness for the G4 Completion Bands

- **Date:** 2026-11-18
- **Status:** Accepted
- **Summary:** The G4 "completes circuit 55–70% / 5–15%" bands are measured on the real content circuit (`ContentLoader().newCircuitState()`) with the player as bot0 at every tavern and each tavern's content opponent as bot1; settlement is `stake × outcome.cubeValue` with R-11 gammon doubling where the tavern enables it. Each re-challenge mixes its attempt index into the match seed, because deterministic bots replay an identical match otherwise. Opponent strengths follow a region tier map: Sumer 3, Egypt 4, Mexica 4. The starting purse is calibrated to **80** (`circuit.json startPurse`, within the roadmap's tunable 20–80 range): at the authored default 40 the optimal bot completed 0.375–0.458 and the naive benchmark 0.0, both below their bands; at 80 with this map the optimal bot completes 0.583 (28/48) and the naive benchmark 0.083 (2/24). The naive benchmark is the careful heuristic bot at strength 2 (an untrained player, not the weakest bot). Bots play omenless matches (omen purchases are the human player's meta-choice under R-12/R-14, not bot decisions). The regression tests (`optimalCircuitCompletion`, `naiveCircuitCompletion`) assert wide plausibility bands (optimal ≥ 0.40, naive ≤ 0.30 over 24 concurrent runs) so binomial noise cannot flake CI; the measured gate values against the roadmap's exact bands are recorded in `docs/STATUS.md`. Manual sweeps live in the disabled scratch tests (`ScratchCircuitRun`, re-enable to re-calibrate).
- **Rationale:** The bands calibrate the purse economy (A.6 "starting purse 40", tunable 20–80), so the measurement must be full circuit runs, not single-match win rates; single-match rates are separately covered by `winRateIsPlausible`. The content files carry opponents but not strengths, so the region tier map is this harness's definition and is recorded here (and in BALANCE.md) as the calibration baseline until P5/P6 wire the real progression. The identical-replay discovery showed a loss at a tavern would end every run at the first unlucky match; the attempt-indexed seed restores the intended re-challenge economics.
- **Consequences:** A change to content stakes, buy-ins, or the circuit economy can shift the measured rate; the regression band catches collapses while the gate evidence documents the calibrated value. Cube turning in the harness exercises the R-9/R-10/R-11 settlement path with real money. Circuit opponents use the `MatchBot` cube defaults (always take, never offer), so doubles in circuit play are offered by the player-side bots only.
