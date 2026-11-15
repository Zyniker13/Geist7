# 03 — Seedfall Roadmap

> A roguelite built on a mancala board, where sowing seeds around carved pits fires the enchantments you have inlaid in them.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 in full before starting. Depth pass (15 Nov 2026): Appendix A extends §4–§13 and wins where they differ. This roadmap adds only what is specific to Seedfall.

Research: [`RESEARCH.md`](RESEARCH.md) (art direction, design lineage, cultural context, advisor institutions, verified glossary, and audio direction).

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 03 · `seedfall` |
| Code prefix | `SF` (packages `SFCore`, `SFContent`, `SFAI`, `SFRender`, `SFAudio`, `SFPlatform`, `SFMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Mancala engine roguelite |
| Difficulty tier | Intermediate |
| Scope | Solo-indie |
| Session length | 20–40 minute runs; 1–3 minute encounters |
| Renderer | SpriteKit (2D, top-down board with baked lighting); seed physics are cosmetic and driven by Core events |
| Players | Solo only (runs, daily board); no multiplayer in v1.0 |
| Simulation | Turn-based; deterministic sowing |
| Sourcing tier | `FULL` (East African mancala, especially Bao la Kiswahili; Swahili-coast carving and music) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** see above.
- **Summary:** A run is a journey along a coast of 3 acts × 5 nodes, ending in a boss board each act. Each node is a sowing contest against a rival board (an AI player following a named regional rule set) or an event, a carver's shop, or a seed market. In a contest, both players share one mancala board (2 × 6 to 4 × 8). On your turn, pick one of your pits, lift its seeds, and sow them one per pit counterclockwise. Each pit a seed lands in may carry an inlay, which triggers. Captures follow the rule set. The contest ends after a turn limit or when a side is empty; your score must beat the encounter target. Harvest (currency) buys new inlays, seed species, and board upgrades. The engine grows until a single sow chains a dozen triggers.
- **Pillars:**
  1. **Real mancala underneath.** With no inlays and standard seeds, each rule set plays exactly like its traditional game (verified against published rules).
  2. **See the whole sow.** Every move previews its full trail, triggers, and captures before commit.
  3. **Engines you can read.** Every trigger is logged and animated in order; a player can explain why they scored.
  4. **Tactile.** Seeds clack, pits fill visibly, and counts are always readable.
- **Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Board hardwood `#6B4226`, carved highlight `#A9774A`, pit shadow `#2E1C10`, brass stud `#C8A24A`, sea teal `#2F7F7A` (UI accents), lime-wash wall `#EFE6D2` (menus), seed palette: molucca grey `#8C8C7A`, cowrie ivory `#F0E6CF`, thorn red `#9E2F25`, tamarind brown `#5A3A22`, dormant green `#5E7D3A`. |
| Shapes | Carved borders with Swahili door motifs (lotus, chain, and fish scale) as placeholders until P6; pits as soft-shadowed bowls; seeds as distinct silhouettes per species. |
| Typography | Rounded humanist sans for counts (default: SF Pro Rounded), display serif for titles. |
| Motion | Sowing: 90 ms per seed at 1× (2× and 4× available), each landing with a small bounce; triggers flash the inlay and print a floating glyph. |
| Music | Taarab-inspired strings and qanun over a slow beat; intensity rises with trigger chains. |
| SFX | Seed clack (pitch by species), pit settle, capture sweep, coins for harvest. |
| Haptics | Tick per seed (throttled to 30 Hz), stronger pulse on capture. |

- **Inspirations:** Bao and Oware rules (Penn Museum, Wikipedia), Balatro's escalating score chase, Slay the Spire's run map.

## 2. Tech Stack Decision

Per `_CONVENTIONS.md` §2, plus:
- **Rule sets as data plus code.** Each traditional rule set (Oware, Kalah, Bao-lite, Bao la Kiswahili simplified, Pallanguzhi, Congkak) is a `RuleSet` value selecting sowing direction, relay sowing, capture conditions, and end conditions from a small enum vocabulary; exotic behaviors are implemented as named strategy types.
- **Trigger engine.** Inlays and seed species attach `Trigger` definitions (event → condition → effect) from JSON. Resolution uses a queue with a hard cap of 256 effects per sow to prevent infinite loops (logged as a fizzle).
- **Scores** are `Int` with saturating arithmetic to 2⁶²; multipliers are integer numerators/denominators.
- ADRs: ADR-0003 rule-set vocabulary; ADR-0004 trigger queue and loop cap; ADR-0005 score arithmetic; ADR-0006 rule-set verification against published rules.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/SFCore/Sources/SFCore/
  Board/     Pit.swift, Board.swift, BoardShape.swift, Side.swift, SowPath.swift
  Seeds/     SeedSpecies.swift, SeedBag.swift
  Rules/     RuleSet.swift, Sowing.swift, RelaySowing.swift, Capture.swift, EndCondition.swift, Variants/ (Oware.swift, Kalah.swift, BaoLite.swift, Bao.swift, Pallanguzhi.swift, Congkak.swift)
  Triggers/  Trigger.swift, TriggerQueue.swift, Effect.swift, Condition.swift
  Run/       RunState.swift, RunMap.swift, Node.swift, Shop.swift, Harvest.swift, Ascension.swift
  Engine/    EncounterState.swift, Action.swift, Event.swift, Reducer.swift, Score.swift
Packages/SFContent/  InlayDef.swift, SeedDef.swift, RivalDef.swift, EventDef.swift, BoardDef.swift, Loader.swift, Validation.swift
Packages/SFAI/       RivalPlayer.swift (minimax per rule set), MoveEvaluator.swift, RunBot.swift (for sims), DailyBoardGenerator.swift
Packages/SFRender/   BoardScene.swift, PitNode.swift, SeedNode.swift, SowTrail.swift, TriggerFX.swift, RunMapScene.swift, ShopScene.swift
Packages/SFMeta/     Unlocks.swift, DailyBoard.swift, Stats.swift, Codex.swift
Resources/Content/   inlays.json, seeds.json, rivals.json, events.json, boards.json, rulesets.json, ascensions.json, balance.json, tutorial.json, achievements.json, cultural_manifest.json
```

## 4. Core Rules Specification

**Board and sowing (traditional core)**
- R-1 A board has `rows` (2 or 4) × `cols` (6 to 8) pits. In 2-row boards each player owns one row; in 4-row boards each owns two rows (inner and outer). Optional stores (Kalah, Congkak) sit at the ends.
- R-2 Setup seeds per pit come from the rule set (Oware 4 per pit; Kalah 4; Bao-lite 2 per pit; Pallanguzhi 5).
- R-3 A move picks one of the mover's pits with at least `minSeeds` (rule set; usually 1, Bao 2). All seeds are lifted and sown one per pit in the rule set's direction around the mover's sowing loop (2-row: all 12 pits; 4-row: the mover's 16 pits only).
- R-4 Oware skip: if a sow passes the origin pit (12+ seeds), the origin is skipped.
- R-5 Relay sowing (Bao, Pallanguzhi): if the last seed lands in an occupied pit, lift all seeds there and continue sowing, until the last seed lands in an empty pit or a capture triggers.
- R-6 Capture conditions by rule set: Oware captures 2 or 3 in the opponent's pit where the last seed lands, plus consecutive preceding opponent pits with 2 or 3; Kalah captures the opposite pit when the last seed lands in an empty own pit; Bao captures the opponent's facing inner pit when the last seed lands in an occupied own inner pit and the facing pit is occupied, and the captured seeds are re-sown from a kichwa (end pit) of the mover's choice.
- R-7 Grand slam rule (Oware): a move that would capture all of the opponent's seeds captures nothing.
- R-8 Feeding rule (Oware): if the opponent has no seeds, the mover must make a move that gives them seeds if possible.
- R-9 End conditions: rule set specific (a side empty, a store majority, or a repetition) plus the roguelite turn limit `encounterTurns` (default 12 per player).

**Roguelite layer (applies only in runs)**
- R-10 Inlays: up to one inlay per pit on the player's side. When a seed lands in an inlaid pit, the inlay's trigger fires (see §5). Rival boards may carry hostile inlays on their side.
- R-11 Seed species: each seed has a species; sowing order within a lifted handful is the pit's stack order (bottom first). Species effects: cowrie counts double for scoring; thorn captures the pit it lands in if that pit holds exactly 1 rival seed; tamarind adds +1 harvest when captured; dormant sprouts into 2 seeds after it has been lifted 3 times.
- R-12 Encounter score = seeds captured × seed value × multipliers + flat bonuses, computed at encounter end. Win if score ≥ target (rival or node defines target) **and** the traditional result is not a loss (rival boss nodes require a traditional win).
- R-13 Trigger resolution: effects enqueue in landing order; each effect may enqueue further effects; cap 256 per move (R-14).
- R-14 If the cap is hit, remaining effects fizzle and an event logs it.
- R-15 Run structure: 3 acts × (4 standard nodes + 1 boss); node types contest, event, shop, rest (remove a hostile inlay or upgrade a pit), and elite. Losing any contest ends the run.
- R-16 Harvest: earned per contest (`target surplus / 10`, minimum 3) and spent in shops (inlays 4–12, seeds 2–6 per handful of 4, board upgrades 15).

**Invariants**
- INV-1 Seed conservation: seeds on board + stores + captured = initial + created (dormant sprouts) − destroyed (effects), tracked per encounter.
- INV-2 With an empty inlay set and standard seeds, each rule set's move results equal the reference implementation in `Tests/Reference/` for 10,000 random positions.
- INV-3 Every move terminates (relay loops bounded by 1,000 laps; trigger cap 256).
- INV-4 Replay determinism.
- INV-5 Preview equals commit for 2,000 random moves with random inlays.

## 5. Data Schemas and Content Tables

```swift
struct Pit: Codable, Hashable, Sendable { var seeds: [SeedSpeciesID]; var inlay: InlayID?; var owner: Side }
struct Board: Codable, Hashable, Sendable { var shape: BoardShape; var pits: [Pit]; var stores: [Side: [SeedSpeciesID]] }
struct Trigger: Codable, Hashable { var on: TriggerEvent; var condition: Condition?; var effects: [Effect] }
enum TriggerEvent: String, Codable { case seedLands, lastSeedLands, pitLifted, capture, sowStart, sowEnd, encounterEnd }
enum Effect: Codable, Hashable { case addMultiplier(num: Int, den: Int), addFlat(Int), extraSow, plantRival(SeedSpeciesID), captureHere, duplicateSeed, convertSeed(SeedSpeciesID), harvest(Int) }
struct EncounterState: Codable, Hashable, Sendable { var board: Board; var ruleSet: RuleSetID; var toMove: Side; var turn: Int; var scoreLedger: ScoreLedger; var rng: SeededRNG }
```

| Table | G3 | G5 | Sample row |
| --- | --- | --- | --- |
| `inlays.json` | 50 | 120 | `{ "id": "brass_chain", "rarity": "common", "trigger": {"on":"seedLands","effects":[{"addFlat":3}]}, "cost": 4, "cultural": false }` |
| `seeds.json` | 12 | 30 | `{ "id": "cowrie", "value": 2, "trigger": null, "cultural": true }` |
| `rulesets.json` | 4 | 6 | `{ "id": "oware", "rows": 2, "cols": 6, "setup": 4, "direction": "ccw", "relay": false, "capture": "oware_2_3", "grandSlam": "no_capture", "feed": true }` |
| `rivals.json` | 15 | 40 | `{ "id": "lamu_elder", "ruleSet": "bao_lite", "aiDepth": 4, "hostileInlays": ["sour_knot"], "target": 40, "act": 1 }` |
| `events.json` | 15 | 40 | `{ "id": "dhow_trader", "choices": [ {"textKey": "ev.dhow.a", "effects": [{"harvest": -5}, {"gainSeed": "cowrie", "count": 4}]} ] }` |
| `boards.json` | 3 | 6 | `{ "id": "bao_4x8", "rows": 4, "cols": 8 }` |
| `ascensions.json` | 5 | 15 | `{ "level": 3, "modifier": "targets_plus_15pct" }` |

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| `encounterTurns` | 12 | 8–16 | `balance.json` |
| `targetCurve` (act 1/2/3 base) | 40 / 160 / 600 | ±50% | `balance.json` |
| `triggerCap` | 256 | 64–512 | `balance.json` |
| `shopPrices` | see R-16 | ±50% | `balance.json` |
| `startingInlays` | 2 | 0–3 | `balance.json` |
| `rivalDepth` (act 1/2/3) | 2 / 4 / 6 | 1–8 | `rivals.json` |

Targets (RunBot "Competent" policy, 5,000 runs): ascension 0 win rate 30–45%; median run 28 minutes estimated (moves × 6 s); no single inlay present in more than 40% of winning runs; at least 25 distinct inlays appear in 5% or more of winning runs.

## 7. AI Approach

- **Rivals:** alpha-beta minimax per rule set with seed-count evaluation (store difference, mobility, vulnerable pits) and hostile-inlay awareness, depth by act (§6). Deterministic.
- **RunBot (sims only):** greedy move choice by previewed score plus a shop policy (buy the highest scoring inlay per harvest by a learned value table refreshed from sims; no machine learning at runtime).
- **Daily board:** seed selects starting inlays, seeds, and a fixed sequence of 8 encounters; score attack.

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7, SRC0.1, SRC0.2, and HIST0.1.
- SF-P0.1 Reference implementations of Oware and Kalah in `Tests/Reference/` written independently from Core (simple, slow) for INV-2.

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; SRC0.1, SRC0.2, and HIST0.1 complete
  [ ] Reference implementations pass their own published-example tests (≥ 10 each)
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- SF-P1.1 Sowing, skip, relay, and four rule sets (Oware, Kalah, Bao-lite, Pallanguzhi) with INV-2.
- SF-P1.2 Trigger engine, queue, cap, and 20 sample inlays covering every effect type.
- SF-P1.3 Seed species (4) and scoring ledger.

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-14 tagged tests pass; INV-1…INV-4 over 5,000 seeds
  [ ] INV-2 equivalence on 10,000 positions for Oware and Kalah
  [ ] SFCore coverage ≥ 90%; make sim N=2000 deterministic
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5, SRC2.1, and SRC2.2.
- SF-P2.1 Board scene: tap a pit to show the ghost trail with trigger icons and projected score; tap again to commit; drag inlays onto pits in shops. Mac: click and hover preview.
- SF-P2.2 A mini-run: 5 nodes (3 contests, 1 shop, 1 boss) with 20 inlays.
- SF-P2.3 Trigger log panel; speed control 1×/2×/4×.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test completes the mini-run (with a debug seed known to be winnable) on iPad and Mac
  [ ] INV-5 preview/commit parity over 2,000 moves
  [ ] A 12-trigger chain animates at ≥ 60 fps in the simulator overlay
  [ ] Manifest and deny-list checks pass
  [ ] `docs/SLICE_ASSESSMENT.md` written: self-assessment against the pillars, with every weakness turned into a P3 task (`_CONVENTIONS.md` §8.1)
Sign-off: GLM-SELF
```

### P3 Content and Systems
- SF-P3.1 Full run map (3 acts), node types, shops, rests, and elites.
- SF-P3.2 G3 content counts (§5).
- SF-P3.3 Tutorial: four contests teaching sowing, captures, inlays, and relay.
- SF-P3.4 Codex of every inlay, seed, and rule set; About the Tradition (SRC3.1); HIST3.1 labels.
- SF-P3.5 Traditional Play mode: any rule set vs AI with no roguelite layer.

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts met; content-lint 0 errors
  [ ] 2,000 RunBot runs: 0 crashes, 0 trigger-cap infinite loops reported as hangs
  [ ] Tutorial UI test passes
Sign-off: GLM-SELF
```

### P4 AI Opponents
- SF-P4.1 Rival alpha-beta for all rule sets; act-based depth; hostile inlay handling.
- SF-P4.2 RunBot and inlay value table generator; `docs/BALANCE.md`.

```
GATE G4 — AI
Checks:
  [ ] Rival depth 6 p95 ≤ 1.0 s on 4×8 boards (Mac measured)
  [ ] Ascension 0 RunBot win rate within 25–50% (tuned to 30–45% in P5)
  [ ] 0 illegal moves in 500-game soaks per rule set
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- SF-P5.1 G5 counts; 15 ascension levels; Bao la Kiswahili (simplified, documented in HISTORY.md) and Congkak rule sets.
- SF-P5.2 Unlocks (inlays and seeds enter the pool after milestones), daily board, stats, and 30 achievements.
- SF-P5.3 SRC5.1 packet.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Balance targets in §6 met (or ADR)
  [ ] Daily board identical for 30 dates across devices
  [ ] Coverage thresholds met; SOURCING_REVIEW_PACKET and HANDOFF complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- SF-P6.1 Commission board carvings from an East African artist (a maintainer item filed as an issue; placeholders until then); seed art; pit lighting.
- SF-P6.2 Taarab-inspired score (licensed or commissioned); SFX.
- SF-P6.3 SRC6.1 and SRC6.2 advisor review (Bao player or Swahili cultural historian).

```
GATE G6 — Aesthetics
Checks:
  [ ] Snapshot set approved; 120 fps on iPad Pro during 4× sowing
  [ ] Advisor review filed as a `needs-maintainer` issue (SUBSTITUTED, `_SET2_ADDENDUM.md` §4); every entry still pending advisor review listed in that issue
Sign-off: GLM-SELF
```

### P7 Platform Features
- SF-P7.1 Game Center: daily leaderboard, highest ascension, 30 achievements, challenges.
- SF-P7.2 iCloud run save (mid-encounter); Mac keyboard play (1–8 select pits, Enter commit).
- SF-P7.3 Pencil hover previews the sow trail.

```
GATE G7 — Platform
Checks:
  [ ] iCloud round-trip mid-run; Game Center sandbox submissions verified
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- SF-P8.1 Seed counts always shown as numerals (toggle); species distinguished by silhouette and pattern.
- SF-P8.2 VoiceOver: "Your pit 3, 7 seeds, inlay Brass Chain"; preview announced as "Sow ends in rival pit 2, captures 3".
- SF-P8.3 Reduce Motion: instant sow with a trail summary.

```
GATE G8 — Polish
Checks:
  [ ] VoiceOver run UI test; performance budgets met
Sign-off: GLM-SELF
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard tasks; SRC9.1; SRC10.1. SF-P9.1 rebalance inlay rarities from opt-in exports.

```
GATE G9 — Beta
Checks:
  [ ] Crash-free ≥ 99.5%; no S1/S2; A0 win rate 30–45% among beta players
Sign-off: GLM-SELF
GATE G10 — Release
Checks:
  [ ] Store assets approved; SRC10.1 credits draft filed as a `needs-maintainer` issue (SUBSTITUTED); final CI green
Sign-off: GLM-SELF
```

## 9. Fragile Areas and Priorities

- **Fragile areas:** relay sowing combined with triggers; Bao kichwa choice UX; trigger cap edge cases; saturating score math.
- **Priorities for P6–P10:** animation batching for long chains; VoiceOver previews; inlay pool curation, target curve, and ascension modifiers.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Degenerate infinite combos | Medium | High | Trigger cap, sims flag runs over 10⁹ score | GLM |
| Bao too complex for players | High | Medium | Bao-lite first; full Bao late and optional | GLM |
| Traditional rules misrepresented | Medium | High | Reference tests, HISTORY.md, advisor review | GLM |
| Balatro comparison invites clone criticism | Medium | Medium | Mancala identity front and center; traditional mode | GLM |

## 11. Out of Scope

Online versus play; a full Bao tournament ruleset with all regional variants; physical board tie-in; endless mode (post-launch).

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 2–3 |
| P1 | GLM | 7–10 |
| P2 | GLM | 7–9 |
| P3 | GLM | 8–11 |
| P4 | GLM | 5–7 |
| P5 | GLM | 7–9 |
| P6 | GLM | 9–13 |
| P7 | GLM | 3–5 |
| P8 | GLM | 4–6 |
| P9 | GLM | 5–7 |
| P10 | GLM | 2–3 |
| **Total** | | **59–83** |

## 13. Open Questions

1. Include a versus mode (two humans, traditional rules) in v1.0? Default: local pass-and-play only in Traditional Play mode.
2. Name rivals after real towns on the Swahili coast? Default: yes, with advisor review; characters are fictional.

## 14. Sourcing Notes

- **Tradition:** the mancala family, with focus on Bao la Kiswahili (Tanzania, Kenya, and Zanzibar), Oware (West Africa and the Caribbean), Pallanguzhi (Tamil Nadu and Kerala), and Congkak (Maritime Southeast Asia).
- **Sources:** Penn Museum Expedition "Mancala"; Wikipedia "Bao (game)"; tradgames.org.uk; Masters of Games rules pages.
- **Restricted elements:** avoid using religious inscriptions found on some carved doors; do not caricature people.
- **Glossary seeds (statuses in the research file; pending advisor):** bao, nyumba (house pit), kichwa (end pit), oware, pallanguzhi — verified; mtaji/takasa (capturing/non-capturing turns), kete (seed), shimo (pit), kimbi, congkak — secondary sources.
- **Historical labels:** traditional rule sets are Attested (with regional variation noted); inlays and seeds are Invented.

## Appendix A. Extended Specification (Depth Pass)

This appendix extends §4–§13 and wins where they differ.

### A.1 Additional Rules

- R-17 Sowing loops: in 2-row boards both rows form one loop of `2 × cols` pits; in 4-row boards each player's loop is their own two rows (`2 × cols` pits), and seeds never enter the opponent's rows except by capture effects.
- R-18 Stores (Kalah): the mover's store is part of the loop; the opponent's store is skipped. A last seed in the mover's store grants an extra move.
- R-19 Pallanguzhi (simplified): after lifting, sow from the next pit; when the last seed lands, lift the next pit and continue (relay); if the next pit is empty, capture the pit after it. The simplification is documented in HISTORY.md.
- R-20 Bao-lite: a capture places the captured seeds into the mover's inner row starting at the end nearest the capture (kichwa choice when equidistant, chosen by the mover).
- R-21 Hostile inlays fire for the rival only; a player effect that "removes an inlay" can target hostile inlays only at rest nodes.
- R-22 Effect ordering: within one landing, inlay effects resolve before seed species effects; across landings, in landing order (R-13).
- R-23 Multipliers stack multiplicatively as exact fractions (num/den, reduced each step); flat bonuses add after multipliers.
- R-24 Ascension modifiers apply at run start and are listed on the run summary; at most one modifier per level.
- R-25 Traditional Play mode uses R-1 to R-9 only; inlays, species, and scores are disabled.

### A.2 Additional Invariants

- INV-6 Score fractions never overflow: numerators and denominators stay below 2^62, enforced by saturating math and a logged event.
- INV-7 A pit holds at most one player inlay.
- INV-8 With the trigger cap reached, the board state equals the state before the fizzled effects (no partial effect).
- INV-9 Traditional Play mode results equal the reference implementations (INV-2) for every rule set.

### A.3 Complete Schemas and Sample Rows

```swift
struct InlayDef: Codable, Sendable { var id: String; var rarity: Rarity; var trigger: Trigger; var cost: Int; var cultural: Bool }
struct SeedSpeciesDef: Codable, Sendable { var id: String; var value: Int; var trigger: Trigger?; var cultural: Bool }
struct RuleSetDef: Codable, Sendable { var id: String; var rows: Int; var cols: Int; var setup: Int; var direction: Direction; var relay: Bool; var capture: CaptureRule; var grandSlam: GrandSlam?; var feed: Bool; var minSeeds: Int; var label: HistLabel }
struct ScoreLedger: Codable, Hashable, Sendable { var captured: Int; var multiplier: Fraction; var flat: Int; var entries: [LedgerEntry] }
```

```json
{ "id": "thorn", "value": 1, "trigger": { "on": "seedLands", "condition": { "pitRivalSeeds": 1 }, "effects": [ { "captureHere": true } ] }, "cultural": false }
{ "id": "bao_lite", "rows": 4, "cols": 8, "setup": 2, "direction": "either", "relay": true, "capture": "bao_inner", "feed": false, "minSeeds": 2, "label": "Reconstructed" }
```

### A.4 Balance Tables and Sim Targets

| Parameter | Default | Range | Sim Target |
| --- | --- | --- | --- |
| `targetCurve` act 1 | 40 | 30–60 | RunBot clears act 1 in 70–85% of runs |
| `targetCurve` act 2 | 160 | 120–240 | Act 2 clear 45–60% |
| `targetCurve` act 3 | 600 | 400–900 | Ascension 0 win rate 30–45% |
| Inlay rarity weights | 60/30/10 | data | ≥ 25 inlays in ≥ 5% of winning runs |
| `triggerCap` | 256 | 64–512 | Cap hit in < 0.5% of moves |
| Harvest per contest | surplus/10, min 3 | data | Two shop purchases per act on median runs |

### A.5 AI Design in Detail

- **Rival search:** alpha-beta with iterative deepening, move ordering by capture size, and a transposition table keyed by board hash; hostile inlays are part of the state, so previews and search agree.
- **Evaluation:** store difference × 4 + seeds on own side × 1 + capture threats × 2 − vulnerable pits × 2; for Bao-lite, inner-row seeds count × 1.5.
- **Budgets:** p95 ≤ 0.8 s at depth 6 on iPad (base); depth falls back one ply when the budget is hit, always at a ply boundary for determinism.
- **RunBot:** used only in `Tools/sim` for balance; its inlay value table is a committed JSON file regenerated by a tool, never trained at runtime.

### A.6 Granular Task Breakdown

| ID | Task | Acceptance Criteria |
| --- | --- | --- |
| SF-P1.4 | Loop construction for 2-row and 4-row boards (R-17, R-18) | 20 fixtures per board shape |
| SF-P1.5 | Effect ordering and fraction math (R-22, R-23) | INV-6 property test over 2,000 random inlay sets |
| SF-P1.6 | Pallanguzhi and Bao-lite simplifications (R-19, R-20) | HISTORY.md entries; 15 fixtures each |
| SF-P3.6 | Traditional Play mode isolation (R-25) | INV-9 over 10,000 positions |
| SF-P4.3 | Rival move ordering and transposition table | Depth 6 within budget on 95% of positions |
| SF-P5.4 | Ascension modifiers 1–15 | Each modifier has a test and a summary string |

### A.7 Sharpened Gate Checks

- G1 adds: INV-6 to INV-9 pass; reference parity holds for Oware and Kalah.
- G4 adds: rival depth 6 beats depth 2 in ≥ 80% of Oware games.
- G5 adds: HISTORY.md labels every rule set (Attested, Reconstructed, or Invented).

### A.8 Additional Risks

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Bao simplified past recognition | Medium | High | Label as Reconstructed; full rules post-launch; advisor issue | GLM |
| Trigger chains feel opaque | Medium | Medium | Trigger log, speed control, and preview ledger | GLM |

### A.9 Additional Open Questions (Defaults)

1. Full Bao la Kiswahili at launch? Default: simplified only (SF-P5.1), labelled.
2. Real Swahili-coast town names for rivals? Default: as §13 (yes, with the names listed in the advisor issue; characters fictional).
