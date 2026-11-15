# 20 — The Sum of Small Wars Roadmap

> Fight several tiny battles at once, one move per turn, in any of them. Whoever makes the last move anywhere wins, so learn to count the value of each little war.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 in full before starting. Depth pass (15 Nov 2026): Appendix A extends §4–§13 and wins where they differ. This roadmap adds only what is specific to The Sum of Small Wars.

Research: [`RESEARCH.md`](RESEARCH.md) (art direction, design lineage, cultural context, advisor institutions, verified glossary, and audio direction).

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 20 · `the-sum-of-small-wars` |
| Code prefix | `SS` (packages `SSCore`, `SSContent`, `SSAI`, `SSRender`, `SSAudio`, `SSPlatform`, `SSMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Combinatorial game sums (partisan games under normal play) |
| Difficulty tier | Hardcore |
| Scope | Solo-indie |
| Session length | 5–15 minutes |
| Renderer | SwiftUI Canvas (flat Albers-style colour fields; no SpriteKit needed) |
| Players | Solo vs AI; local pass-and-play; async online |
| Simulation | Turn-based, perfect information, deterministic |
| Sourcing tier | `FULL` (regions derived from Kōnane (Hawaiian) and Mū tōrere (Māori); other regions original or from combinatorial game theory literature) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** see above.
- **Summary:** The board is a set of independent regions (3–6), each a small game: a Kōnane strip (jump captures on a small grid), a Mū tōrere star (8 points around a centre), Domineering patches (place dominoes vertically or horizontally), Toads and Frogs lines, Hackenbush drawings, and enclosure fields (original). On each turn the player moves in exactly one region. Under normal play, the player unable to move in any region loses. Combinatorial game theory (Conway, Berlekamp, and Guy) tells us a sum's outcome is determined by the regions' values (numbers, nimbers, switches, infinitesimals like ↑ and *). The game teaches values gradually: an optional "Value Lens" shows each region's canonical value once the player has unlocked that concept. The campaign is a ladder of increasingly subtle sums; the endgame is learning to play the hottest region first and counting tempo.
- **Pillars:**
  1. **Mathematics as play.** Real CGT values, computed exactly, taught through puzzles.
  2. **Simple moves, deep sums.** Each region's rules fit in one sentence; the sum creates depth.
  3. **The lens is earned.** Values appear only after the player has learned what they mean.
  4. **Credit the traditions.** Kōnane and Mū tōrere presented with their cultures' advisors.
- **Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Albers-style nested squares per region: warm set `#E1A436`, `#C9572E`, `#7A2E2A`; cool set `#6E8FA8`, `#2F4F6A`, `#1C2733`; neutral `#EDE6D6`, `#B8AE9A`; Left player black-violet `#2B2140`, Right player ivory `#F2EBDD`. |
| Shapes | Each region is a square framed by nested colour bands; pieces as flat circles and dominoes. |
| Typography | Futura (system) and SF Mono for values (with CGT notation: ↑, *, {a|b}). |
| Motion | Minimal; regions dim when finished; value lens slides out. |
| Music | Minimalist piano (Satie-like, original). |
| SFX | Soft wood clicks; chime at region exhaustion. |
| Haptics | Subtle tick per move. |

- **Inspirations:** Berlekamp, Conway, and Guy, "Winning Ways for Your Mathematical Plays" (2001–2004); Siegel, "Combinatorial Game Theory" (2013); Albers, "Interaction of Color" (1963); CGSuite (Siegel); Ernst, "Playing Konane Mathematically: A Combinatorial Game-Theoretic Analysis", UMAP Journal 16(2):95–121 (1995).

## 2. Tech Stack Decision

Per `_CONVENTIONS.md` §2, plus:
- **CGT engine:** canonical forms for short partisan games: game trees reduced by dominated-option removal and reversible-option bypass; values interned in a hash-consed table; arithmetic (sum, negation, comparison) implemented exactly (no floating point). Region positions memoised by canonical encoding.
- **Bounds:** regions capped in size so canonical form computation finishes in ≤ 50 ms per region on iPad (base) (validated in CI over all content).
- ADRs: ADR-0003 CGT engine design (reference: Siegel 2013 algorithms); ADR-0004 region rule sets; ADR-0005 Value Lens unlock policy.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/SSCore/Sources/SSCore/
  CGT/      Game.swift (hash-consed), Canonical.swift, Arithmetic.swift, Compare.swift, Temperature.swift, Notation.swift
  Regions/  Region.swift, Konane.swift, MuTorere.swift, Domineering.swift, ToadsFrogs.swift, Hackenbush.swift, Enclosure.swift
  Engine/   SumState.swift, Action.swift, Event.swift, Reducer.swift, Outcome.swift
Packages/SSContent/  RegionDef.swift, SumDef.swift, LessonDef.swift, Loader.swift, Validation.swift
Packages/SSAI/       Solver.swift (exact via values), Mistakes.swift (tiers via controlled errors), Hints.swift
Packages/SSRender/   SumView.swift, RegionViews/, ValueLens.swift
Packages/SSMeta/     Ladder.swift, DailySum.swift, Stats.swift
Resources/Content/   regions.json, sums.json, lessons.json, balance.json, tutorial.json, glossary.json, cultural_manifest.json
```

## 4. Core Rules Specification

**Sums**
- R-1 A game is a list of regions. Players are Left (moves first unless the sum specifies) and Right.
- R-2 On a turn, the player makes one legal move in exactly one region (for that player's side in that region's rules).
- R-3 Normal play: a player with no legal move in any region loses.

**Regions (each a partisan game)**
- R-4 Kōnane-style: rectangular grid (≤ 4 × 6) filled with alternating stones; Left owns black, Right white; a move jumps one's stone orthogonally over an adjacent enemy stone into an empty point, removing it; multiple jumps in a straight line allowed (one direction). Initial removals per the traditional opening (scenario-defined start positions after removals). Labelled as derived from Kōnane.
- R-5 Mū tōrere-style: 8 outer points (kāwai, also spelled kewai) and the centre (pūtahi); 4 counters (perepere) each; moves to an adjacent empty point, to the centre from a kāwai only if that piece is adjacent to an enemy piece (traditional restriction), or from the centre to an empty kāwai. A player unable to move loses (as in the traditional game). As a partisan region in a sum, repetition is impossible to bound, so the region is used with a move cap per piece (ADR; labelled as a variant) or as a loopy-game exception computed by retrograde outcome only (no value lens).
- R-6 Domineering: Left places vertical dominoes, Right horizontal, on empty cells of a small polyomino board.
- R-7 Toads and Frogs: a 1 × n strip; Left's toads move right one step or jump a frog; Right's frogs move left similarly.
- R-8 Blue-Red Hackenbush: Left cuts blue edges, Right red; edges disconnected from the ground vanish.
- R-9 Enclosure (original): a small graph; Left claims a vertex adjacent to one of their own or a start vertex; Right likewise; claimed vertices block.

**Invariants**
- INV-1 Canonical form of every content region is unique and stable across runs.
- INV-2 Outcome predicted by the sum of values (compare with 0) equals the outcome found by brute-force minimax on 1,000 small sums.
- INV-3 Region moves never affect other regions.
- INV-4 Replay determinism.
- INV-5 Known values check: catalogue fixtures (for example Domineering 2 × 2 = ±1, Toads and Frogs positions from Winning Ways) match.

## 5. Data Schemas and Content Tables

```swift
indirect enum Game: Hashable, Sendable { case node(left: [GameRef], right: [GameRef]) }  // interned; GameRef = UInt32
struct RegionDef: Codable, Sendable { var id: String; var kind: RegionKind; var position: String; var concept: Concept; var cultural: Bool; var label: HistoryLabel? }
struct SumDef: Codable, Sendable { var id: String; var regions: [String]; var firstPlayer: Side; var lesson: String?; var tier: Int }
enum Action: Codable, Hashable { case move(region: Int, RegionMove), resign }
```

| Table | G3 | G5 | Sample row |
| --- | --- | --- | --- |
| `regions.json` | 80 | 300 | `{ "id": "dom_2x3", "kind": "domineering", "position": "....../", "concept": "numbers" }` |
| `sums.json` | 40 | 150 | `{ "id": "s_up_01", "regions": ["tf_LR_R", "hack_up"], "firstPlayer": "left", "tier": 3 }` |
| `lessons.json` | 8 | 14 | numbers, fractions, star, up and down, switches, temperature, tiny and miny, nimbers |
| `glossary.json` | 10 | 20 | Kōnane and Mū tōrere terms pending advisor |

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| Regions per sum | 3–5 | 2–6 | `sums.json` |
| AI mistake rates by tier | 40/20/8/0% | — | `balance.json` |
| Lens unlock requirements | lesson completion | — | `balance.json` |

Targets: every campaign sum solvable and winnable for the human side (verified); median human solve time increases monotonically; top tier is perfect play.

## 7. AI Approach

- **Exact play:** choose a move leaving a sum with value favourable for the AI (compare with 0 under the next player); among winning moves prefer the one that keeps the most options (style).
- **Tiers:** controlled mistakes: with probability p choose a random non-losing-if-possible move; Novice, Student, Scholar, Master (perfect).
- **Hints:** explain using values ("Play in the region with temperature 2; it is the hottest").

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7, SRC0.1, SRC0.2, HIST0.1 (Attested: Kōnane rules and history, Mū tōrere rules; Invented: regions as sum components; credit CGT authors).

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; SRC0.1, SRC0.2, HIST0.1 complete
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- SS-P1.1 CGT engine (canonical forms, arithmetic, comparison, temperature) with catalogue fixtures (INV-5).
- SS-P1.2 Region rules (R-4 to R-9) and sum engine (R-1 to R-3); brute-force cross-check (INV-2).

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-9 tests; INV-1…INV-5
  [ ] Every region in G3 content computes in ≤ 50 ms; SSCore coverage ≥ 90%
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5, SRC2.1, SRC2.2.
- SS-P2.1 Sum view with region tiles; per-region interaction; turn indicator; outcome.
- SS-P2.2 First two lessons and Value Lens prototype.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test plays a 3-region sum on iPad and Mac
  [ ] Manifest marks Kōnane and Mū tōrere content pending; deny-list passes
  [ ] `docs/SLICE_ASSESSMENT.md` written: self-assessment against the pillars, with every weakness turned into a P3 task (`_CONVENTIONS.md` §8.1)
Sign-off: GLM-SELF
```

### P3 Content and Systems
- SS-P3.1 G3 content; lessons; About the Traditions (SRC3.1) for Kōnane and Mū tōrere; HIST3.1.

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts met; every sum verified winnable; lint clean
Sign-off: GLM-SELF
```

### P4 AI Opponents
- SS-P4.1 Tiers and hints; `docs/BALANCE.md`.

```
GATE G4 — AI
Checks:
  [ ] Master never loses a won position (10,000 tests); move ≤ 100 ms
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- SS-P5.1 G5 counts; ladder; daily sum; 24 achievements; SRC5.1; HANDOFF.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Counts met; packet and HANDOFF complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- SS-P6.1 Albers palette system; region visuals (Kōnane and Mū tōrere visuals approved by advisors); SRC6.1 and SRC6.2 with Hawaiian and Māori advisors.
- SS-P6.2 Music and SFX.

```
GATE G6 — Aesthetics and Cultural Review
Checks:
  [ ] Advisor review (both traditions) filed as a `needs-maintainer` issue (SUBSTITUTED, `_SET2_ADDENDUM.md` §4); every entry still pending advisor review listed in that issue; snapshots approved
Sign-off: GLM-SELF
```

### P7 Platform Features
- SS-P7.1 Game Center, async, iCloud.

```
GATE G7 — Platform
Checks:
  [ ] Async completes; iCloud round-trip
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- SS-P8.1 VoiceOver per region; values spoken ("up", "star"); colour-independent sides.

```
GATE G8 — Polish
Checks:
  [ ] VoiceOver completes lessons 1–3; budgets met
Sign-off: GLM-SELF
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard tasks; SRC9.1; SRC10.1.

```
GATE G9 — Beta
Checks:
  [ ] Crash-free ≥ 99.5%; community notes addressed
Sign-off: GLM-SELF
GATE G10 — Release
Checks:
  [ ] SRC10.1 credits draft filed as a `needs-maintainer` issue (SUBSTITUTED); final CI green
Sign-off: GLM-SELF
```

### Key Test Fixtures (GLM Writes These in P1)

1. Domineering 2 × 2 canonical value is ±1.
2. Domineering 1 × 2 vertical strip is 1 (Left has one move).
3. Blue-Red Hackenbush: a single blue edge is 1; a red edge on top of a blue edge (blue touching the ground) is 1/2.
4. Star (*) + star (*) = 0; the next player loses.
5. ↑ + * is a first-player win (fuzzy with 0).
6. Toads and Frogs positions and values from the Winning Ways tables (copied into `Tests/Fixtures/toads_frogs.json` with citation) match.
7. Sum outcome by values equals brute-force minimax on 1,000 random small sums.
8. Mū tōrere variant with move cap terminates within the cap in all generated positions.

## 9. Fragile Areas and Priorities

- **Fragile areas:** canonical form performance; Mū tōrere loopiness (ADR).
- **Priorities for P6–P10:** region UIs, VoiceOver notation; lesson flow; cultural packet.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Too mathematical | High | Medium | Lessons, lens, puzzles | GLM |
| Loopy region complexity | Medium | Medium | Variant or outcome-only | GLM |
| Cultural framing of Kōnane and Mū tōrere | Low | High | Advisors; About pages | GLM |

## 11. Out of Scope

Misère play; impartial-only mode (nimbers appear only in lessons); region editor.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 2 |
| P1 | GLM | 8–11 |
| P2 | GLM | 4–6 |
| P3 | GLM | 5–7 |
| P4 | GLM | 2–3 |
| P5 | GLM | 3–5 |
| P6 | GLM | 6–8 |
| P7 | GLM | 2–4 |
| P8 | GLM | 3–4 |
| P9 | GLM | 4–6 |
| P10 | GLM | 2–3 |
| **Total** | | **41–59** |

## 13. Open Questions

1. Include full-board Kōnane and Mū tōrere as standalone games? Default: yes as bonus modes, advisor-approved.

## 14. Sourcing Notes

- **Sources:** Ernst, UMAP Journal 16(2):95–121 (1995) on Kōnane; Bishop Museum and National Park Service (Puʻuhonua o Hōnaunau) materials on Kōnane; Straffin, "Position Graphs for Pong Hau K'i and Mu Torere", Mathematics Magazine 68(5):382–386 (1995), with a correction in 69(1):65; Te Ara encyclopedia on Māori games; Winning Ways; Siegel (2013).
- **Restricted elements:** no sacred or genealogical motifs; Māori and Hawaiian words with correct macrons and ʻokina.
- **Glossary seeds (verified against Te Ara, NPS, and Bishop Museum; pending advisors):** Hawaiian: kōnane, papamū (board), ʻiliʻili (stones: black lava and white coral). Māori: mū tōrere, kāwai (outer points; also spelled kewai), pūtahi (centre), perepere (counters, 4 per player).
- **Rules as attested:** Kōnane begins with removal of two adjacent centre stones, allows multiple jumps in one direction, and the player unable to move loses. Mū tōrere allows a move into the pūtahi only when the moving piece is adjacent to an opponent's piece; the blocked player loses.

## Appendix A. Extended Specification (Depth Pass)

### A.1 Additional Rules

**Sum construction**
- R-10 A content sum lists regions with their start positions and the player to move. Every region in a shipped sum must have a finite game tree (loopfree); Mū tōrere-style regions use the loopfree variant defined in R-5 (move cap and no-repeat rule), so canonical values exist.
- R-11 A region with no moves for either player is removed from display (value 0) with a fade, and the turn passes normally.
- R-12 Tutorial sums follow the order: integers (Hackenbush stalks), fractions (Hackenbush 1/2), switches (±n), stars (*), up (↑), then mixed sums; each lesson introduces one value type.

**Region specifics**
- R-13 Kōnane-style regions: openings follow the attested pattern (two adjacent centre stones removed, then the first jump); multi-jumps in one straight direction only; the mover may stop after any jump.
- R-14 Domineering boards: polyominoes up to 12 cells; Left vertical, Right horizontal.
- R-15 Toads and Frogs: toads (Left) move one step right into an empty cell or jump exactly one frog into an empty cell; frogs (Right) symmetric leftward.
- R-16 Blue-Red Hackenbush: removing an edge deletes all edges no longer connected to the ground.
- R-17 Enclosure (original): graphs ≤ 10 vertices; claims must be adjacent to a vertex the claimant already owns or to one of their start vertices.

**Scoring and modes**
- R-18 Campaign mode: each level is a sum; three stars for winning, winning as second player when the sum's outcome allows, and winning with par moves (the minimum number of moves needed against perfect play).
- R-19 "Value training": the player may tap a region to guess its value; correct guesses (canonical form) earn hints.
- R-20 Misère play is out of scope at launch (values do not add under misère).

### A.2 Additional Invariants
- INV-6 Every content region is loopfree: game-tree depth ≤ region size × 4 (static check).
- INV-7 Canonical forms computed by our Swift CGT engine equal CGSuite outputs exported for all content regions (golden files).
- INV-8 Value-guess checker accepts equal values in any form (compares canonical forms).
- INV-9 Thermograph temperatures shown in hints equal engine output.

### A.3 Complete Schemas and Sample Rows

```swift
indirect enum CGValue: Codable, Hashable, Sendable { case number(Dyadic), star(Int), up(Int), switch_(CGValue, CGValue), general(left: [CGValue], right: [CGValue]) }
struct Dyadic: Codable, Hashable, Sendable { var num: Int; var exp: Int }   // num / 2^exp
struct RegionDef: Codable, Sendable { var id: String; var kind: RegionKind; var start: String; var canonical: String; var temperature: Dyadic?; var label: HistoryLabel }
struct SumDef: Codable, Sendable { var id: String; var regions: [String]; var toMove: Side; var outcome: Outcome; var parMoves: Int; var lesson: String? }
enum Outcome: String, Codable, Sendable { case leftWins, rightWins, firstPlayerWins, secondPlayerWins }
struct GoldenValue: Codable, Sendable { var region: String; var cgsuite: String }
```

```json
{ "id": "hb_half", "kind": "hackenbush", "start": "ground-B-R", "canonical": "1/2", "temperature": null, "label": "Invented" }
{ "id": "dom_2x2", "kind": "domineering", "start": "##/##", "canonical": "±1", "temperature": {"num": 1, "exp": 0}, "label": "Invented" }
{ "id": "kon_3x4_a", "kind": "konane", "start": "BWBW/W..B/BWBW", "canonical": "computed", "label": "Attested-derived" }
{ "id": "lesson_switch_2", "regions": ["dom_2x2", "hb_half"], "toMove": "left", "outcome": "leftWins", "parMoves": 3, "lesson": "switches" }
```

`Attested-derived` regions use the traditional moves of Kōnane or Mū tōrere on smaller boards (labelled in HISTORY.md as Reconstructed adaptations, not traditional play).

### A.4 Balance Tables and Sim Targets

| Parameter | Default | Range | Target |
| --- | --- | --- | --- |
| Regions per sum (campaign) | 2–4 | 1–6 | Median solve time 2–6 minutes |
| Max region size | 12 cells | 6–16 | Canonical computation ≤ 50 ms per region |
| Novice error rate | 40% | 25–60% | Novice loses to Student ≥ 75% |
| Student error rate | 15% | — | — |
| Scholar error rate | 5% | — | — |
| Hint costs | 1 star-equivalent | — | Players use ≤ 2 hints per level on average (telemetry, opt-in) |

### A.5 AI Design in Detail
- **CGT engine:** recursive canonicalisation with memoisation (position hash → canonical form), dominated-option removal and reversible-option bypass; numbers as dyadic rationals; stars and ups as special forms for speed.
- **Move choice (Master):** for each move, compute the resulting sum's value and outcome class; choose a winning move; among winning moves, prefer moves in the hottest region (temperature) and then the most remaining options.
- **Controlled mistakes:** with probability p, pick uniformly among non-winning moves unless no winning move exists.
- **Hints:** three levels — "which region" (hottest), "which move", and "why" (shows values before and after).

### A.6 Granular Task Breakdown

| ID | Task | Acceptance Criteria |
| --- | --- | --- |
| SS-P1.1 | CGValue arithmetic, comparison, canonical form | Winning Ways fixtures; INV-2 |
| SS-P1.2 | Hackenbush region (R-8, R-16) | Value fixtures (stalks, 1/2) |
| SS-P1.3 | Domineering region (R-6, R-14) | 2 × 2 = ±1 and catalogue values |
| SS-P1.4 | Toads and Frogs (R-7, R-15) | Winning Ways table fixtures |
| SS-P1.5 | Kōnane-style (R-4, R-13) | Ernst 1995 small-position values |
| SS-P1.6 | Mū tōrere-style loopfree variant (R-5, R-10) | INV-6 |
| SS-P1.7 | Enclosure (R-9, R-17) | 15 fixtures |
| SS-P1.8 | Golden files from CGSuite | INV-7 |
| SS-P2.1 | Albers-style colour fields per region | Snapshot tests |
| SS-P2.2 | Value-guess UI (R-19) | INV-8 |
| SS-P2.3 | Thermograph hint view | INV-9 |
| SS-P3.1 | Campaign of 60 sums with lesson order (R-12) | Lint |
| SS-P3.2 | About: Kōnane and Mū tōrere as living games | Pending advisor marks |
| SS-P4.1 | Tiers and hints | Targets met |
| SS-P5.1 | Daily sum | Seeded and solvable |

### A.7 Sharpened Gate Checks
- G1 adds: golden-file agreement with CGSuite for all regions; Straffin's position-graph facts for Mū tōrere reproduced (first-player outcomes on the standard start).
- G3 adds: Hawaiian and Māori terms only from verified glossary with ʻokina and macrons rendered correctly.
- G5 adds: advisor sign-off on how traditional games are described.

### A.8 Additional Risks

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Traditional games reduced to "math toys" | Medium | High | About screens present them as living games; advisor review | GLM |
| Canonical-form blow-up | Medium | Medium | Region size caps; precomputed values | GLM |
| Players do not grasp sums | High | Medium | Lesson order (R-12) | GLM |

### A.9 Additional Open Questions (Defaults)
1. Ship full-size traditional Kōnane and Mū tōrere modes? Default: yes, as standalone games with attested rules (outside sums).
2. Use ʻokina and kahakō in UI throughout? Default: yes.
3. Misère mode? Default: post-launch.
