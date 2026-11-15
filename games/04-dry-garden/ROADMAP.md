# 04 — Dry Garden Roadmap

> Two gardeners set stones and rake gravel in one shared courtyard, and the ripples around each stone decide whose garden it is.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 in full before starting. Depth pass (15 Nov 2026): Appendix A extends §4–§13 and wins where they differ. This roadmap adds only what is specific to Dry Garden.

Research: [`RESEARCH.md`](RESEARCH.md) (art direction, design lineage, cultural context, advisor institutions, verified glossary, and audio direction).

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 04 · `dry-garden` |
| Code prefix | `DG` (packages `DGCore`, `DGContent`, `DGAI`, `DGRender`, `DGAudio`, `DGPlatform`, `DGMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Area-influence abstract (two players, perfect information) |
| Difficulty tier | Approachable (easy to learn, deep to master) |
| Scope | Solo-indie |
| Session length | 10–20 minutes |
| Renderer | SpriteKit (2D top-down) with a normal-mapped gravel shader (`SKShader`) for raked lines |
| Players | Solo vs AI; local pass-and-play; async online (GameKit turn-based) |
| Simulation | Turn-based on a hex lattice of gravel cells |
| Sourcing tier | `FULL` (Japanese karesansui gardens, a living tradition tied to Zen temples) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** see above.
- **Summary:** The courtyard is a hex lattice of gravel cells (default 13 × 11 within an irregular wall outline). Players alternate placing stones (small, medium, or large, each from a limited supply) or raking a line (a straight run of up to 5 cells). Stones radiate influence rings: each ring distance gives decreasing influence; rake lines carry influence along their length from an adjacent stone. Each cell belongs to whoever exerts more influence there. Garden principles are rules: no placement may create bilateral mirror symmetry of the stone layout around any lattice axis, no three stones may stand in one straight lattice line, and stones score only when in groups of odd size. The game ends when both supplies are spent. Score is controlled gravel plus group bonuses.
- **Pillars:**
  1. **Few rules, deep play.** Three actions and three garden laws; a full game teaches itself in two lessons.
  2. **Influence you can see.** Every cell's owner and margin are visible on demand (hover or press).
  3. **Beauty is legal.** The legality rules are the aesthetic rules; an ugly garden is usually a losing one.
  4. **Quiet.** No timers, no shaking, no fanfare; feedback is sound and subtle light.
- **Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Gravel `#E9E6DF`, gravel shadow `#C9C4B8`, rake groove `#B7B1A3`, wall plaster `#D8CDB6`, roof tile `#3E4246`, moss `#5F7A3A`, Player 1 stones basalt `#2F2F33`, Player 2 stones granite `#9C8F80` with lichen flecks, maple `#B5482A` (seasonal), influence tints at 10–25% alpha (P1 cool slate `#4A5C6E`, P2 warm ochre `#B08A4F`). |
| Shapes | Natural stone silhouettes (6 per size, varied), raked grooves following the seven classic patterns as UI motifs. |
| Typography | Light serif display (default: New York Light) and SF Pro for numbers. |
| Motion | Stones lower into place over 500 ms; ripples animate outward once per placement; raking draws grooves at finger speed. |
| Music | Mostly silence; sparse shakuhachi and koto phrases between turns (optional). |
| SFX | Rake rasp, stone set on gravel, wooden clapper at game end, water drip. |
| Haptics | Soft thud on stone placement; fine texture while raking. |

- **Inspirations:** NAJGA on karesansui asymmetry, odd groupings, and raking patterns; the British Go Association on good shape; Browne's shibui ideal.

## 2. Tech Stack Decision

Per `_CONVENTIONS.md` §2, plus:
- **Lattice:** axial hex coordinates (`q`, `r`) with a precomputed distance table per courtyard; influence is integer.
- **Legality checks:** symmetry detection over the 6 hex mirror axes through every cell center and edge midpoint within the courtyard (pre-enumerated per courtyard); collinearity over the 3 lattice directions.
- **Search:** alpha-beta with Zobrist hashing; incremental influence updates.
- ADRs: ADR-0003 hex lattice and courtyard masks; ADR-0004 symmetry definition (exact mirror of all stones including size, within the courtyard mask); ADR-0005 incremental influence.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/DGCore/Sources/DGCore/
  Lattice/  Hex.swift, Courtyard.swift, DistanceTable.swift, Axis.swift
  Garden/   Stone.swift, StoneSize.swift, RakeLine.swift, Influence.swift, Ownership.swift, Group.swift
  Laws/     SymmetryLaw.swift, CollinearLaw.swift, OddGroupScoring.swift, ViewingFaceRule.swift
  Engine/   GameState.swift, Action.swift, Event.swift, Reducer.swift, Score.swift, LegalMoves.swift, Zobrist.swift
Packages/DGContent/  CourtyardDef.swift, SeasonDef.swift, PuzzleDef.swift, Loader.swift, Validation.swift
Packages/DGAI/       Evaluator.swift, AlphaBeta.swift, MoveOrdering.swift, PuzzleGenerator.swift, PuzzleSolver.swift
Packages/DGRender/   GardenScene.swift, GravelShader.fsh, StoneNode.swift, RakeNode.swift, InfluenceOverlay.swift, SeasonFX.swift
Packages/DGMeta/     DailyGarden.swift, Ladder.swift, Stats.swift
Resources/Content/   courtyards.json, seasons.json, puzzles.json, balance.json, tutorial.json, achievements.json, cultural_manifest.json
```

## 4. Core Rules Specification

**Setup**
- R-1 The courtyard is a set of hex cells defined by `courtyards.json` (default "Ryōan" outline: 113 cells). Some cells are fixed features (moss or a basin) and cannot hold stones; they can be owned.
- R-2 Supplies per player: 2 large, 3 medium, 4 small stones; rake lines unlimited but at most `rakesPerPlayer` (default 6).
- R-3 Player 1 (basalt) moves first. The veranda edge (the viewing side) is the courtyard's bottom edge.

**Actions**
- R-4 `place(cell, size, facing)`: an empty non-feature cell not adjacent to an existing stone of the same player of the same size (prevents clumps). `facing` is one of 6 hex directions; it matters for R-12.
- R-5 `rake(start, direction, length)`: a straight run of 2–5 empty, non-feature cells starting adjacent to one of the mover's stones. Raked cells cannot later receive stones. A raked cell already raked by the opponent cannot be raked again.
- R-6 `pass`: legal only when the mover has no legal placement and no rakes left.

**Garden laws (legality)**
- R-7 Symmetry law: an action is illegal if, after it, the full set of stones (position and size, ignoring owner) is mirror-symmetric about any lattice axis of the courtyard, with ≥ 4 stones on the board.
- R-8 Collinearity law: an action is illegal if, after it, any three stones lie on one straight lattice line with equal spacing.

**Influence and ownership**
- R-9 A stone of size `s` exerts influence `I_s(d)` on cells at hex distance `d`: large 6, 5, 4, 3, 2, 1 for d = 0…5; medium 4, 3, 2, 1; small 3, 2, 1.
- R-10 A rake line owned by player P adds P's influence of the anchoring stone at distance 1 (R-5's adjacent stone) to every cell of the line and to each cell adjacent to the line, undiminished along its length.
- R-11 A cell's owner is the player with strictly greater total influence; ties are unowned.

**Scoring**
- R-12 Viewing face: a large or medium stone whose `facing` points toward the veranda (the three downward directions) adds +1 influence at distances 1–2 in those directions (rewarding stones turned to their viewer).
- R-13 Groups: stones of the same owner within distance 2 form a group. At game end, each group of odd size (1, 3, 5, or 7) scores `groupBonus[size]` (default 0, 4, 9, 15); even-sized groups score nothing.
- R-14 Score = owned cells + group bonuses.
- R-15 Game ends when both players have passed consecutively or both supplies and rakes are spent; highest score wins; tie → Player 2 wins.

**Invariants**
- INV-1 After any legal action, R-7 and R-8 hold.
- INV-2 Ownership recomputed from scratch equals incremental ownership (1,000 random games).
- INV-3 Stone supplies never go negative.
- INV-4 Replay determinism.
- INV-5 Alpha-beta equals minimax at depth ≤ 3 on 500 positions.

## 5. Data Schemas and Content Tables

```swift
struct Hex: Codable, Hashable, Sendable { var q: Int; var r: Int }
struct Stone: Codable, Hashable, Sendable { var owner: PlayerID; var cell: Hex; var size: StoneSize; var facing: Int }
struct RakeLine: Codable, Hashable, Sendable { var owner: PlayerID; var cells: [Hex]; var anchor: Hex }
struct GameState: Codable, Hashable, Sendable { var courtyardID: String; var stones: [Stone]; var rakes: [RakeLine]; var supplies: [PlayerID: Supply]; var toMove: PlayerID; var passes: Int; var season: String }
enum Action: Codable, Hashable { case place(Hex, StoneSize, facing: Int), rake(Hex, dir: Int, length: Int), pass }
```

| Table | G3 | G5 | Sample row |
| --- | --- | --- | --- |
| `courtyards.json` | 4 | 10 | `{ "id": "long_wall", "cells": "<mask string>", "features": [{"q":3,"r":2,"kind":"moss"}], "veranda": "bottom", "cultural": true }` |
| `seasons.json` | 2 | 4 | `{ "id": "autumn", "modifier": "leaf_cells_reduce_influence_1", "leafCount": 6 }` |
| `puzzles.json` | 30 | 120 | `{ "id": "dg_p001", "start": "<GameState>", "goal": "win", "plies": 3, "solution": [ ... ] }` |
| `tutorial.json` | 4 lessons | 6 | — |

Season modifiers (G5): Spring (none), Summer (moss spreads: feature cells grow by 1 every 4 turns, deterministic), Autumn (fallen-leaf cells reduce influence by 1), Winter (snow: rake lines last only 6 turns).

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| Stone supply L/M/S | 2/3/4 | 1–5 each | `balance.json` |
| Influence curves | R-9 | per size | `balance.json` |
| `rakesPerPlayer` | 6 | 3–10 | `balance.json` |
| `groupBonus` | 0, 4, 9, 15 | 0–25 | `balance.json` |
| `viewingFaceBonus` | 1 | 0–2 | `balance.json` |
| `symmetryMinStones` | 4 | 3–6 | `balance.json` |

Targets (Master vs Master, 2,000 games per courtyard): Player 1 win rate 47–53%; illegal-by-law candidate moves 5–20% of all placements in mid-game (so laws matter but do not choke); median margin 3–9 cells; odd-group bonuses decide 10–30% of games.

## 7. AI Approach

- **Search:** alpha-beta with iterative deepening, Zobrist TT (2²⁰), and move ordering by influence gain.
- **Evaluation:** owned cells × 10 + contested margin sum + projected group parity (+6 for odd, −6 for even groups) + remaining supply value − exposure to rival rakes.
- **Tiers:** Novice (depth 1, 25% noise among top 6), Gardener (depth 2), Master (depth 4 or 1.0 s), Abbot (depth 6 or 2.0 s).
- **Puzzles:** generate from Master games positions with a unique best move by ≥ 4 points at depth 3; verify with depth 5.
- **Daily garden:** seed chooses courtyard, season, and a 2-stone opening; play vs Master.

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7, SRC0.1, SRC0.2, and HIST0.1.
- DG-P0.1 Hex lattice, courtyard mask loader, and axis enumeration with tests.

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; SRC0.1, SRC0.2, and HIST0.1 complete
  [ ] Axis enumeration test: the default courtyard yields the expected axis count (fixture)
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- DG-P1.1 Placement, rakes, and pass (R-4 to R-6).
- DG-P1.2 Symmetry and collinearity laws (R-7, R-8) with ≥ 40 fixtures each, including near-symmetric positions.
- DG-P1.3 Influence, ownership, viewing face, groups, and scoring (R-9 to R-15); incremental influence (INV-2).

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-15 tagged tests pass; INV-1…INV-4 over 5,000 seeds
  [ ] DGCore coverage ≥ 90%; make sim N=5000 deterministic; < 5 ms per random game
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5, SRC2.1, and SRC2.2.
- DG-P2.1 Garden scene: drag a stone from a tray, twist to set facing (or tap the facing arrows), release to preview influence; confirm chip commits. Draw a rake by dragging from beside a stone. Illegal placements show which law (symmetry axis drawn as a faint line, or the collinear trio).
- DG-P2.2 Influence overlay toggle; ownership tally.
- DG-P2.3 Opponent: Gardener AI.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test plays a full game vs Gardener on iPad and Mac
  [ ] Illegal-move explanations match Core reasons in 100% of 200 scripted illegal attempts
  [ ] Manifest and deny-list checks pass
  [ ] `docs/SLICE_ASSESSMENT.md` written: self-assessment against the pillars, with every weakness turned into a P3 task (`_CONVENTIONS.md` §8.1)
Sign-off: GLM-SELF
```

### P3 Content and Systems
- DG-P3.1 G3 courtyards and seasons; 30 puzzles hand-tagged by difficulty.
- DG-P3.2 Tutorial (4 lessons: stones and ripples, rakes, laws, groups).
- DG-P3.3 Pass-and-play; casual undo.
- DG-P3.4 About the Tradition and glossary (SRC3.1); HIST3.1 labels.

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts met; lint clean; tutorial UI test passes; 1,000-game sims per courtyard
Sign-off: GLM-SELF
```

### P4 AI Opponents
- DG-P4.1 Four tiers; puzzle generator; `docs/BALANCE.md`.

```
GATE G4 — AI
Checks:
  [ ] INV-5 passes; each tier beats the one below ≥ 75% over 500 games
  [ ] Master p95 ≤ 1.0 s, Abbot p95 ≤ 2.0 s
  [ ] Player 1 win rate 47–53% per courtyard (or ADR)
  [ ] ≥ 300 verified puzzles generated
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- DG-P5.1 G5 counts; seasons; daily garden; ladder of 12 gardeners (styles named descriptively, not after real temples' monks); stats and 24 achievements; SRC5.1.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Daily identical for 30 dates; counts met; coverage thresholds met
  [ ] SOURCING_REVIEW_PACKET and HANDOFF complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- DG-P6.1 Gravel shader with groove normals; stone art set (photogrammetry-style 2D renders); seasonal light.
- DG-P6.2 Sparse shakuhachi and koto recordings (commissioned or licensed); SFX.
- DG-P6.3 SRC6.1 and SRC6.2 advisor review (garden designer or scholar of Japanese gardens).

```
GATE G6 — Aesthetics
Checks:
  [ ] Snapshot set approved; 120 fps on iPad Pro; Advisor review filed as a `needs-maintainer` issue (SUBSTITUTED, `_SET2_ADDENDUM.md` §4); every entry still pending advisor review listed in that issue
Sign-off: GLM-SELF
```

### P7 Platform Features
- DG-P7.1 Game Center leaderboards (daily margin, ladder), achievements, challenges, async matches.
- DG-P7.2 Pencil: hover shows contested cells; draw rake lines with the Pencil; barrel roll rotates stone facing. Finger fallbacks.
- DG-P7.3 iCloud; Mac menus and shortcuts (R rotates facing).

```
GATE G7 — Platform
Checks:
  [ ] Async match completes; iCloud round-trip; Pencil fallback checklist complete
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- DG-P8.1 Player stones differ by shape outline and texture; influence overlay uses hatching option.
- DG-P8.2 VoiceOver cell rotor ("Row 4, cell 6, yours by 2"); law explanations spoken.
- DG-P8.3 Reduce Motion; large-touch-target mode.

```
GATE G8 — Polish
Checks:
  [ ] VoiceOver full game UI test; color-blind simulations reviewed; budgets met
Sign-off: GLM-SELF
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard tasks; SRC9.1; SRC10.1.

```
GATE G9 — Beta
Checks:
  [ ] Crash-free ≥ 99.5%; no S1/S2
Sign-off: GLM-SELF
GATE G10 — Release
Checks:
  [ ] Store assets approved; SRC10.1 credits draft filed as a `needs-maintainer` issue (SUBSTITUTED); final CI green
Sign-off: GLM-SELF
```

## 9. Fragile Areas and Priorities

- **Fragile areas:** symmetry law performance on large courtyards; ADR-0004 definition (owner ignored); rake ownership conflicts.
- **Priorities for P6–P10:** gravel shader, VoiceOver rotor; group bonus values and influence curves; whether the symmetry law bites too rarely.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Feels like Go-lite | Medium | Medium | Laws and rakes as signature; marketing on beauty | GLM |
| Laws feel arbitrary | Medium | High | Explain with drawn axes; tutorial frames them as garden principles | GLM |
| First-player advantage | Medium | High | P2 tie-break, supply tweak | GLM |
| Stereotyped "Zen" presentation | Medium | High | Advisor gate; avoid temple names and monks as characters | GLM |

## 11. Out of Scope

3D garden; real-time; more than 2 players; garden sandbox (post-launch candidate); named real temples as courtyards.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 2 |
| P1 | GLM | 5–7 |
| P2 | GLM | 6–8 |
| P3 | GLM | 4–6 |
| P4 | GLM | 5–7 |
| P5 | GLM | 4–6 |
| P6 | GLM | 7–10 |
| P7 | GLM | 4–6 |
| P8 | GLM | 3–5 |
| P9 | GLM | 4–6 |
| P10 | GLM | 2–3 |
| **Total** | | **46–66** |

## 13. Open Questions

1. Include a free garden sandbox? Default: post-launch.
2. Ship music at all, or silence plus SFX? Default: optional music, off by default.

## 14. Sourcing Notes

- **Tradition:** karesansui (dry landscape gardens), Muromachi period onward; the Sakuteiki garden manual.
- **Sources:** NAJGA "The Dry Landscape Garden" and "7 Common Raking Patterns"; Portland Japanese Garden "Stones: The Bones of the Garden".
- **Restricted elements:** no Buddhist iconography, sutra text, or monks as playable characters; do not name courtyards after specific temples without permission.
- **Glossary seeds:** karesansui, ishigumi (stone arrangement), samon (raked pattern), Sakuteiki, tsukubai (basin).
- **Historical labels:** odd groupings and asymmetry are Attested design principles; influence math is Invented.

## Appendix A. Extended Specification (Depth Pass)

### A.1 Additional Rules

**Courtyard geometry**
- R-16 Axial coordinates use `q` (east) and `r` (south-east); hex distance `d(a,b) = (|dq| + |dr| + |dq + dr|) / 2`. The veranda edge is the set of cells with maximal `r` for each `q`.
- R-17 Mirror axes are the 6 lattice reflection families (3 through cell centres, 3 through edge midpoints). An axis is "in play" for a courtyard only if reflecting the courtyard mask about it maps at least 70% of non-feature cells onto non-feature cells (precomputed at load; stored in `courtyards.json` as `axes`).
- R-18 Symmetry test (R-7) compares the multiset of `(cell, size)` for all stones with its reflection; stones reflecting onto a wall or feature cell break symmetry automatically.
- R-19 Collinearity test (R-8) applies to three stones on one straight lattice line with equal spacing `k ≥ 1`, regardless of owner and size. Spacing counts in cells along the line.

**Placement and rakes**
- R-20 A stone may not be placed on a raked cell, a feature cell, or adjacent to a basin (`tsukubai`-style feature) unless the courtyard sets `basinAdjacentAllowed`.
- R-21 Rake lines may cross an opponent's rake line at exactly one cell; the crossing cell carries both rakes' influence bonuses (R-10) and belongs to neither rake for future crossings.
- R-22 Rakes cannot pass through stones, features, or walls; a rake's `anchor` must remain adjacent to the first cell for the whole game (if the anchor stone is removed by a variant, the rake becomes inert).
- R-23 Rake pattern: each rake line records a `pattern` (straight, ripple, wave) chosen for display only; all patterns have identical rules at launch.

**Influence detail**
- R-24 Influence is additive per player; a stone's own cell receives `I_s(0)`. Features receive influence and can be owned (moss and basin cells count as owned cells for scoring at weight 1).
- R-25 Viewing-face bonus (R-12) applies only if no stone of the opponent stands between the stone and the veranda on the facing ray within distance 3 (the "view is clear").
- R-26 Group connectivity (R-13) uses hex distance ≤ 2 between stones of the same owner; groups are computed at game end only.

**Turn flow**
- R-27 A player with legal moves may not pass. If every placement is illegal by laws R-7/R-8 and no rakes remain, the player must pass (R-6).
- R-28 Undo in casual mode reverts the last full turn pair; ranked, daily, and async modes have no undo.
- R-29 Seasons (G5) apply their modifier at fixed turns stored in `seasons.json`; modifiers never change legality retroactively.
- R-30 Resign is legal at any time and scores as a loss with margin recorded as the current difference.

### A.2 Additional Invariants
- INV-6 Symmetry and collinearity checks are order-independent: permuting the stone list never changes legality (property test, 2,000 positions).
- INV-7 Every axis listed in `courtyards.json` maps the courtyard to at least 70% of itself (content lint).
- INV-8 Score equals owned cells + group bonuses and is recomputable from the final state alone.
- INV-9 No two rakes overlap in more than one cell (R-21).
- INV-10 `LegalMoves` never returns a move rejected by the reducer (fuzz 100,000 moves).

### A.3 Complete Schemas and Sample Rows

```swift
enum StoneSize: String, Codable, Sendable { case small, medium, large }
enum FeatureKind: String, Codable, Sendable { case moss, basin, lantern }
struct CourtyardDef: Codable, Sendable { var id: String; var name: String; var mask: [String]; var features: [FeatureDef]; var veranda: String; var axes: [AxisDef]; var cultural: Bool; var manifestKey: String? }
struct FeatureDef: Codable, Sendable { var q: Int; var r: Int; var kind: FeatureKind }
struct AxisDef: Codable, Sendable { var family: Int; var offset: Int }
struct SeasonDef: Codable, Sendable { var id: String; var modifier: SeasonModifier; var turns: [Int]; var params: [String: Int] }
struct PuzzleDef: Codable, Sendable { var id: String; var courtyard: String; var start: GameState; var goal: PuzzleGoal; var plies: Int; var solution: [Action]; var difficulty: Int }
struct BalanceDef: Codable, Sendable { var supply: [StoneSize: Int]; var influence: [StoneSize: [Int]]; var rakesPerPlayer: Int; var groupBonus: [Int]; var viewingFaceBonus: Int; var symmetryMinStones: Int; var rakeMaxLength: Int }
enum Event: Codable, Sendable { case placed(Stone), raked(RakeLine), passed(PlayerID), illegal(Action, reason: IllegalReason), gameOver(scores: [PlayerID: Int]) }
enum IllegalReason: String, Codable, Sendable { case occupied, raked, feature, sameSizeAdjacent, symmetry, collinear, noSupply, rakeBlocked, rakeNoAnchor, rakeCrossing, mustMove }
```

```json
{ "id": "long_wall", "name": "Long Wall", "mask": ["..........###", ".............", "............."], "features": [{"q": 3, "r": 2, "kind": "moss"}, {"q": 9, "r": 6, "kind": "basin"}], "veranda": "bottom", "axes": [{"family": 1, "offset": 0}], "cultural": false }
{ "id": "autumn", "modifier": "leafCells", "turns": [6, 12], "params": {"leafCount": 6, "influencePenalty": 1} }
{ "id": "dg_p014", "courtyard": "long_wall", "goal": {"kind": "winByAtLeast", "margin": 3}, "plies": 3, "difficulty": 2, "solution": [{"place": {"cell": [4, 5], "size": "medium", "facing": 4}}] }
{ "supply": {"large": 2, "medium": 3, "small": 4}, "influence": {"large": [6,5,4,3,2,1], "medium": [4,3,2,1], "small": [3,2,1]}, "rakesPerPlayer": 6, "groupBonus": [0, 0, 0, 4, 0, 9, 0, 15], "viewingFaceBonus": 1, "symmetryMinStones": 4, "rakeMaxLength": 5 }
```

`groupBonus` is indexed by group size (0–7); even indices must be 0 (lint).

### A.4 Balance Tables and Sim Targets

| Parameter | Default | Range | Sim Target It Controls |
| --- | --- | --- | --- |
| Large/medium/small supply | 2/3/4 | 1–5 | Game length 16–22 plies per player |
| Large curve | 6,5,4,3,2,1 | top 5–7 | Large stones own 30–45% of owned cells |
| Rake max length | 5 | 3–6 | Rakes decide ownership of 10–25% of cells |
| Group bonus (3/5/7) | 4/9/15 | 2–25 | Bonuses are 10–20% of the winner's score |
| Viewing-face bonus | 1 | 0–2 | Facing chosen toward veranda in 50–80% of medium/large placements by Master |
| Symmetry min stones | 4 | 3–6 | Law-illegal candidates 5–20% mid-game |
| P2 tie-break | P2 wins ties | P1/P2/draw | Overall P1 win 47–53% |

Sim protocol: 2,000 games per courtyard per balance candidate (Master vs Master, seeds 1–2,000, alternating colours), plus 500 Gardener vs Master to confirm tier gap. Report win rate with 95% Wilson interval, mean margin, plies, rake usage, law-blocked candidate rate, and group-size histogram in `docs/BALANCE.md`.

### A.5 AI Design in Detail
- **Move generation:** placements = empty legal cells × 3 sizes × 6 facings (facing pruned to the 3 veranda-ward directions plus the best of the rest for medium/large; small ignores facing); rakes = anchors × 6 directions × lengths 2–5. Typical branching 150–400.
- **Ordering:** TT move, then moves maximising immediate influence delta, then rakes that flip ≥ 2 cells, then the rest. Killer moves per ply (2 slots).
- **Evaluation (integer):** `10·(owned_me − owned_opp) + Σ_cells clamp(margin, −3, 3) + 6·parityPotential + 4·(supplyValue_me − supplyValue_opp) − 3·exposedCells`, where `parityPotential` is +1 for each group that is currently odd and −1 for each even group within distance 3 of a free stone, and `exposedCells` are owned cells that an opponent rake could flip next turn.
- **Search:** PVS with iterative deepening, aspiration windows ±20, TT 2²⁰ entries (Zobrist on stones, rakes, supplies, side), quiescence over rakes that flip ≥ 3 cells (max 2 plies).
- **Tiers:** Novice (depth 1, softmax over top 6 with temperature 30), Gardener (depth 2, no noise), Master (iterative deepening to 1.0 s, cap depth 6), Abbot renamed "Ancient Gardener" pending advisor input (2.0 s, cap depth 8, opening book from 50,000 self-play games).
- **Puzzle generator:** sample positions from Master games at plies 10–30; keep if best move beats second by ≥ 4 at depth 3 and the solution is unique at depth 5; tag difficulty by depth needed (1–5).
- **Explain:** after a loss, show the 3 largest evaluation swings with the move that caused each.

### A.6 Granular Task Breakdown

| ID | Task | Acceptance Criteria |
| --- | --- | --- |
| DG-P0.1 | Hex lattice: `Hex`, distance, neighbours, line iteration | 100% branch coverage; distance symmetric and triangle inequality hold on 10,000 random pairs |
| DG-P0.2 | Courtyard loader and mask parser | Loads all fixtures; invalid masks fail with line and column |
| DG-P0.3 | Axis enumeration and 70% filter | Default courtyard yields stored axis list exactly |
| DG-P0.4 | `cultural_manifest.json` and lint (SRC0.2) | Lint fails on any asset with `cultural: true` lacking an entry |
| DG-P1.1 | Placement legality (R-4, R-20) | 40 fixtures pass, each tagged with its rule |
| DG-P1.2 | Rake legality and crossing (R-5, R-21, R-22) | 30 fixtures; INV-9 property test |
| DG-P1.3 | Symmetry law (R-7, R-17, R-18) | 40 fixtures incl. near-symmetric; INV-6 |
| DG-P1.4 | Collinearity law (R-8, R-19) | 40 fixtures incl. spacing 1–4 |
| DG-P1.5 | Influence and ownership, incremental (R-9–R-11, R-24) | INV-2 over 1,000 games; incremental update < 0.2 ms |
| DG-P1.6 | Viewing face and clear-view (R-12, R-25) | 20 fixtures |
| DG-P1.7 | Groups and scoring (R-13–R-15, R-26) | INV-8; 20 scored end positions match hand calculation |
| DG-P1.8 | `LegalMoves` and fuzz | INV-10 over 100,000 moves |
| DG-P2.1 | Stone tray, drag, facing rotate, influence preview | Preview equals Core result in 500 random cases |
| DG-P2.2 | Rake drawing gesture with snap | Only legal rakes can be committed |
| DG-P2.3 | Law explanation overlay | Axis or trio drawn for 100% of 200 illegal attempts |
| DG-P2.4 | Ownership overlay toggle and tally | Tally equals Core owned cells |
| DG-P2.5 | Pending-review mark in debug builds (SRC2.1) | Visible on every cultural asset in debug, absent in release |
| DG-P3.1 | Courtyards (4) and seasons (2) | Lint clean; each courtyard has ≥ 1 axis |
| DG-P3.2 | Tutorial lessons 1–4 | Scripted UI test completes each lesson |
| DG-P3.3 | About the Tradition (SRC3.1) with placeholders | Screen renders all sections; text keys marked pending |
| DG-P4.1 | PVS search and TT | INV-5; Master p95 ≤ 1.0 s on A15 |
| DG-P4.2 | Tiers and opening book | Tier gaps ≥ 75% |
| DG-P4.3 | Puzzle generator | ≥ 300 unique verified puzzles |
| DG-P5.1 | Daily garden (seeded) | Same courtyard and opening for a date on 3 devices |
| DG-P5.2 | Ladder of 12 gardeners | Each rung beatable by Master at ≥ 60% |
| DG-P5.3 | Review packet (SRC5.1) | Every manifest entry listed with asset preview |

### A.7 Sharpened Gate Checks
- G1 adds: `make sim N=5000` produces identical hash on macOS CI and an iPad build; zero `Float` uses in `DGCore` (import check).
- G2 adds: a scripted UI test confirms the law overlay appears and explains the first illegal attempt; the human first-time-user check is SUBSTITUTED per `_CONVENTIONS.md` §8.2.
- G3 adds: every courtyard tested with 1,000 Master-vs-Master sims; no courtyard outside 45–55% P1 win rate.
- G4 adds: Novice beats a random mover ≥ 95%; Ancient Gardener never times out over 500 games.
- G5 adds: 300 puzzles each solved by the solver within its stated plies; manifest pending count reported.

### A.8 Additional Risks

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Symmetry law rarely triggers on irregular courtyards | Medium | Medium | Axis filter and sim metric (5–20%) | GLM |
| Facing input fiddly on iPhone | Medium | Medium | Auto-face toward veranda with optional twist | GLM |
| Season modifiers break balance | Medium | Medium | Separate sims per season; ADR for each | GLM |
| Players read the game as "Zen" kitsch | Medium | High | Research file's avoid list; advisor gate | GLM |

### A.9 Additional Open Questions (Defaults)
1. Allow 3-player free-for-all on large courtyards? Default: no.
2. Name courtyards after raking patterns (`samon`) or neutral English names? Default: neutral English names, with pattern names only in the glossary after advisor review.
3. Include a lantern feature? Default: no at launch (stone lanterns carry religious associations).
