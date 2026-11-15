# 07 — Rosette Roadmap

> Play the 4,500-year-old Royal Game of Ur in a smoky tavern circuit, where the dice are fair but the stakes are not.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 in full before starting. Depth pass (15 Nov 2026): Appendix A extends §4–§13 and wins where they differ. This roadmap adds only what is specific to Rosette.

Research: [`RESEARCH.md`](RESEARCH.md) (art direction, design lineage, cultural context, advisor institutions, verified glossary, and audio direction).

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 07 · `rosette` |
| Code prefix | `RS` (packages `RSCore`, `RSContent`, `RSAI`, `RSRender`, `RSAudio`, `RSPlatform`, `RSMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Race game with wagering (push-your-luck) |
| Difficulty tier | Approachable |
| Scope | Solo-indie |
| Session length | 5–15 minutes per match; a circuit run 30–60 minutes |
| Renderer | SpriteKit (2D with lit, tilted board) |
| Players | Solo vs AI (tavern circuit); local pass-and-play; async online |
| Simulation | Turn-based, stochastic (seeded dice) |
| Sourcing tier | `HISTORICAL` (ancient Mesopotamian, Egyptian, and Mesoamerican games; no living-tradition sourcing required) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** see above.
- **Summary:** The core is the Royal Game of Ur using the widely played modern ruleset popularised by Irving Finkel and RoyalUr.net (Reconstructed): a 20-square board, 7 pieces each, 4 tetrahedral binary dice (0–4), rosettes that grant an extra roll and safety, and captures that send a piece home. The 7 pieces and tetrahedral dice come from the 3rd-millennium sets excavated at Ur; the Babylonian tablet of Itti-Marduk-balāṭu (BM 33333B, 177–176 BCE) is far later and, as attested, describes five pieces per player and astragal (knucklebone) dice. The game ships both: the modern ruleset as default (labelled Reconstructed) and a "Tablet" ruleset that follows only what the tablet attests (labelled Attested where attested, Reconstructed where gaps are filled). Rosette adds a wager layer: before each match the players set a stake; at the start of any turn, a player may offer to double (as in backgammon's doubling cube) or play an omen token (one-shot bend of the rules, bought between matches). The solo campaign is a circuit of taverns from Ur to Thebes to Tenochtitlan, adding historical variants (Finkel's tablet rules, the Masters 'long route', a Senet-like variant labelled Reconstructed, and Patolli on a 52-space cross). The goal is to grow a purse and win the final tavern's tournament.
- **Pillars:**
  1. **Fair dice, honest odds.** The odds of every roll and every move are available on demand.
  2. **The wager is the strategy.** Doubling decisions and omen timing matter as much as piece choices.
  3. **History labelled.** Every rule set states what is Attested, Reconstructed, or Invented.
  4. **Five-minute matches.** Every match fits a coffee break.
- **Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Lapis `#26619C`, shell `#EFE7D3`, red limestone `#A23B2A`, bitumen `#1E1A17`, gold `#C9A13B`, tavern wood `#5A3A22`, lamplight `#F2B866`, papyrus `#E2D3A6`, jade (Patolli) `#3E7C5A`. |
| Shapes | Board inlay patterns (rosettes, eyes, dots) adapted from the British Museum board, simplified; pieces as shell and lapis discs. |
| Typography | Humanist sans display (default: Avenir Next) with cuneiform-inspired ornaments (decorative only, never fake text). |
| Motion | Dice tumble with deterministic outcomes animated after the fact; pieces hop; lamplight flicker. |
| Music | Lyre and frame-drum loops (original, reconstruction-inspired, labelled as invented). |
| SFX | Dice on wood, piece click, crowd murmur, coin drop on doubling. |
| Haptics | Four ticks for the dice; strong tap on capture. |

- **Inspirations:** Finkel, "On the Rules for the Royal Game of Ur" (2007); British Museum "Tom Scott vs Irving Finkel" video; RoyalUr.net solved-game analysis; Duggan on Patolli.

## 2. Tech Stack Decision

Per `_CONVENTIONS.md` §2, plus:
- **Solver:** the Finkel ruleset is small enough to solve exactly (value iteration over a state space on the order of 10⁸ positions; RoyalUr.net publishes solved results). We compute a compressed value table offline for Finkel rules only, shipped as a 30–60 MB asset or via on-demand resources (ADR-0005), and use expectiminimax for other variants.
- **Doubling:** cube decisions via equity from the value table (Finkel) or Monte Carlo rollouts (variants).
- ADRs: ADR-0003 ruleset as data; ADR-0004 dice model; ADR-0005 solved table packaging; ADR-0006 doubling cube.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/RSCore/Sources/RSCore/
  Board/    Track.swift, Square.swift, RuleSet.swift
  Dice/     DiceModel.swift (binary tetrahedra, two-sided sticks, Patolli beans)
  Match/    Piece.swift, MoveGen.swift, Capture.swift, Rosette.swift
  Wager/    Stake.swift, Cube.swift, Omen.swift
  Engine/   MatchState.swift, Action.swift, Event.swift, Reducer.swift, Outcome.swift
  Circuit/  CircuitState.swift, Tavern.swift, Purse.swift
Packages/RSContent/  RuleSetDef.swift, TavernDef.swift, OpponentDef.swift, OmenDef.swift, Loader.swift
Packages/RSAI/       Expectiminimax.swift, SolvedTable.swift, Rollouts.swift, CubePolicy.swift, Personalities.swift
Packages/RSRender/   BoardScene.swift, DiceNode.swift, PieceNode.swift, TavernBackdrop.swift
Packages/RSMeta/     Circuit.swift, DailyMatch.swift, Stats.swift
Tools/SolveUr/       (macOS command-line tool: value iteration, writes RSAI/Resources/ur_finkel.bin)
Resources/Content/   rulesets.json, taverns.json, opponents.json, omens.json, balance.json, tutorial.json
```

## 4. Core Rules Specification (Modern Finkel/RoyalUr Ruleset, Reconstructed; Variants in `rulesets.json`)

**Board and pieces**
- R-1 (Reconstructed: piece count from the excavated Ur sets, not the tablet) Each player has 7 pieces off-board at start. Each player's path: 4 private squares, 8 shared middle squares, 2 private squares, then off (bear off with exact roll). Rosettes at private squares 4 and 14 and shared square 8 (indices per `rulesets.json`).
- R-2 (Reconstructed: dice from the excavated Ur sets; the tablet uses astragals) Dice: 4 binary tetrahedra; roll = number of marked tips up (0–4) with probabilities 1/16, 4/16, 6/16, 4/16, 1/16.

**Moves**
- R-3 On a roll `n > 0`, the player must move one piece exactly `n` squares along its path, if any legal move exists; otherwise the turn passes. A roll of 0 passes.
- R-4 A piece cannot land on a square occupied by its own piece.
- R-5 Landing on a shared square occupied by an opponent captures it (sent off-board to start), unless that square is the central rosette (safe; the move is illegal).
- R-6 Landing on any rosette grants another roll.
- R-7 Bearing off requires the exact number to move one past the last square.
- R-8 First player to bear off all 7 pieces wins the match.

**Wager layer**
- R-9 Match stake `S` is agreed before the match (circuit: set by tavern minimum and player purse).
- R-10 Cube: before rolling, a player who owns the cube (or anyone if centred) may offer a double. The opponent accepts (stake ×2, cube passes to them) or concedes (loses current stake). Max cube 64.
- R-11 Gammon-equivalent: if the loser has borne off zero pieces, they lose 2× stake (toggle per tavern).
- R-12 Omens: each player may hold up to 2 omens; one per match; played before the roll. Examples: "Re-roll once", "Treat central rosette as unsafe this turn", "Move two pieces splitting the roll". Omen effects are data with a closed set of effect kinds.

**Circuit**
- R-13 The circuit has 3 regions × 4 taverns. Each tavern has an opponent, ruleset, minimum stake, and buy-in. Purse below the cheapest available buy-in ends the run.
- R-14 Between matches, the player may buy omens or pay to learn an opponent's tell (shows its cube policy).

**Invariants**
- INV-1 Piece conservation (off-board + on-board + borne off = 7).
- INV-2 Dice distribution: χ² test over 10⁶ seeded rolls matches R-2 at p > 0.01.
- INV-3 Purse never negative; cube value ∈ {1, 2, 4, …, 64}.
- INV-4 Replay determinism.
- INV-5 Solved table: expectiminimax at depth 2 never finds a move with higher win probability than the table's choice on 10,000 random positions (within 1e-6 when converted).

## 5. Data Schemas and Content Tables

```swift
struct RuleSetDef: Codable, Sendable { var id: String; var label: HistoryLabel; var trackLength: Int; var pieces: Int; var rosettes: [Int]; var safeRosettes: [Int]; var dice: DiceModelID; var exactBearOff: Bool; var extraRollOnRosette: Bool; var captureRule: CaptureRule; var source: String }
struct OmenDef: Codable, Sendable { var id: String; var cost: Int; var effect: OmenEffect; var label: HistoryLabel }
struct OpponentDef: Codable, Sendable { var id: String; var name: String; var ai: String; var cubeAggression: Int; var omens: [String]; var tellCost: Int }
enum Action: Codable, Hashable { case roll, move(PieceID), offerDouble, acceptDouble, concede, playOmen(String), setStake(Int) }
```

| Table | G3 | G5 | Sample row |
| --- | --- | --- | --- |
| `rulesets.json` | 3 | 6 | `{ "id": "finkel", "label": "Reconstructed", "trackLength": 14, "pieces": 7, "rosettes": [3,7,13], "safeRosettes": [7], "dice": "tetra4", "source": "Finkel 2007" }` |
| `taverns.json` | 6 | 12 | `{ "id": "ur_harbor", "region": "sumer", "ruleset": "finkel", "opponent": "boatman", "minStake": 5, "buyIn": 10 }` |
| `opponents.json` | 6 | 12 | `{ "id": "boatman", "name": "The Boatman", "ai": "careful", "cubeAggression": 2, "omens": [], "tellCost": 15 }` |
| `omens.json` | 6 | 12 | `{ "id": "reroll", "cost": 12, "effect": {"kind":"reroll","n":1}, "label": "Invented" }` |

Variants: Finkel/RoyalUr (Reconstructed), Tablet (5 pieces, astragal dice modelled as 4-sided knucklebone throws with uneven face odds; the tablet's attested elements labelled Attested and every filled gap labelled Reconstructed, per Appendix A), Masters long route (Reconstructed from modern scholarship, labelled), Senet-like 30-square with throw sticks (Reconstructed, Kendall rules, labelled as one of several reconstructions), and Patolli 52-space with 5 beans (Reconstructed from Durán's account), plus "Tavern House Rules" (Invented).

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| Starting purse | 40 | 20–80 | `balance.json` |
| Omen costs | per row | 5–40 | `omens.json` |
| Cube max | 64 | 8–64 | `balance.json` |
| Gammon rule | per tavern | — | `taverns.json` |

Targets: Finkel first-player win rate matches the published solved value (slightly above 50%); circuit completion rate for an "optimal" bot 55–70% and for a "naive" bot 5–15%; median match length 4–9 minutes for humans (estimated from 60 plies at 5 s).

## 7. AI Approach

- **Finkel:** solved table lookup for moves; cube decisions by equity thresholds (double at ≥ 70% win, take at ≥ 25%).
- **Variants:** expectiminimax depth 2–3 with heuristic eval (pip count, safety, rosette control) plus cube via 200-rollout Monte Carlo.
- **Personalities:** data-driven (careful, greedy, bluffer, gambler) as deviations from optimal: noise level, cube offset, omen timing.
- **Tells:** a revealed tell shows the opponent's cube thresholds.

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7 and HIST0.1 (Attested: board, 20 squares, pieces; Reconstructed: Finkel rules, Senet, Patolli rules; Invented: wagering details, omens, taverns).

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; HIST0.1 complete
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- RS-P1.1 Finkel rules (R-1 to R-8), dice (INV-2).
- RS-P1.2 Wager layer (R-9 to R-12).
- RS-P1.3 Ruleset data model supports all variants; Senet-like and Patolli move generators.
- RS-P1.4 `Tools/SolveUr` value iteration; table compression; INV-5.

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-12 tagged tests; INV-1…INV-5
  [ ] Solved first-player win probability matches published value within 0.1 percentage point
  [ ] RSCore coverage ≥ 90%; make sim N=10000 deterministic
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5.
- RS-P2.1 Board scene, dice roll button, highlight legal moves, tap to move; odds panel ("Chance to capture next roll: 25%").
- RS-P2.2 Cube UI; stake; one tavern match vs a personality.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test completes a Finkel match with a double accepted, on iPad and Mac
  [ ] Odds panel values match exact computation in 200 sampled states
  [ ] `docs/SLICE_ASSESSMENT.md` written: self-assessment against the pillars, with every weakness turned into a P3 task (`_CONVENTIONS.md` §8.1)
Sign-off: GLM-SELF
```

### P3 Content and Systems
- RS-P3.1 Circuit (R-13, R-14) with G3 taverns, opponents, omens; HIST3.1 labels on rulesets and omens.
- RS-P3.2 Tutorial (3 lessons); "History" panel per ruleset quoting sources.
- RS-P3.3 Pass-and-play.

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts met; lint clean; 1,000 bot circuit runs complete without softlocks
Sign-off: GLM-SELF
```

### P4 AI Opponents
- RS-P4.1 Personalities; variant expectiminimax; cube policies; `docs/BALANCE.md`.

```
GATE G4 — AI
Checks:
  [ ] Optimal bot circuit completion 55–70%; naive 5–15%
  [ ] Decisions p95 ≤ 150 ms (table) and ≤ 600 ms (variants)
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- RS-P5.1 G5 counts; daily match (seeded dice sequence, same for everyone); stats; 20 achievements; HANDOFF.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Daily identical for 30 dates; counts met; HANDOFF complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- RS-P6.1 Board art per region (Ur, Thebes, Tenochtitlan); tavern backdrops; HIST6.1 fact-check by GLM.
- RS-P6.2 Original reconstruction-inspired music; SFX.

```
GATE G6 — Aesthetics
Checks:
  [ ] Snapshots approved; HIST6.1 report shows no unlabelled claims
Sign-off: GLM-SELF
```

### P7 Platform Features
- RS-P7.1 Game Center (daily, circuit purse), async matches with cube, iCloud.
- RS-P7.2 Solved table as on-demand resource; Mac keyboard (1–7 picks a piece).

```
GATE G7 — Platform
Checks:
  [ ] Async match with cube completes; ODR download and fallback (expectiminimax) verified offline
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- RS-P8.1 Pieces differ by shape; VoiceOver announces rolls, legal moves, and odds; Reduce Motion skips dice tumble.

```
GATE G8 — Polish
Checks:
  [ ] VoiceOver full match; budgets met
Sign-off: GLM-SELF
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard tasks; App Store age rating review for simulated gambling (no real money; purse is in-game only).

```
GATE G9 — Beta
Checks:
  [ ] Crash-free ≥ 99.5%; no S1/S2
Sign-off: GLM-SELF
GATE G10 — Release
Checks:
  [ ] Age rating questionnaire answered accurately (simulated gambling); final CI green
Sign-off: GLM-SELF
```

## 9. Fragile Areas and Priorities

- **Fragile areas:** solved table encoding; omen interactions with rosette extra rolls.
- **Priorities for P6–P10:** ODR packaging, VoiceOver odds; omen balance and history labels.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Gambling perception | Medium | Medium | No IAP currency; accurate age rating | GLM |
| Table size | Medium | Medium | ODR, compression | GLM |
| Competing free Ur apps | High | Medium | Circuit, variants, wagering | GLM |

## 11. Out of Scope

Real-money or purchasable currency; live online tournaments; full Senet scholarship debates (one labelled reconstruction only).

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 1–2 |
| P1 | GLM | 5–7 |
| P2 | GLM | 4–6 |
| P3 | GLM | 4–6 |
| P4 | GLM | 3–5 |
| P5 | GLM | 3–4 |
| P6 | GLM | 6–9 |
| P7 | GLM | 3–5 |
| P8 | GLM | 2–4 |
| P9 | GLM | 3–5 |
| P10 | GLM | 2–3 |
| **Total** | | **36–56** |

## 13. Open Questions

1. Ship the solved table in the app (larger download) or as on-demand? Default: on-demand.
2. Include Patolli at launch? Default: yes, as the final region.

## 14. Sourcing Notes

- **Sources:** Finkel, "On the Rules for the Royal Game of Ur", in Ancient Board Games in Perspective (British Museum Press, 2007), pp. 16–32 (British Museum tablet BM 33333B, 177–176 BCE, which attests five pieces and astragal dice; the 7-piece, tetrahedral-dice ruleset is a modern reconstruction); RoyalUr.net solved analysis; Kendall's Senet reconstruction; Durán's account of Patolli.
- **Historical labels:** listed in HIST0.1; the tablet attaches fortunes to squares, which inspires omens, but wagering and omen mechanics are Invented.

## Appendix A. Extended Specification (Depth Pass)

### A.1 Additional Rules

**Ruleset selection and labels**
- R-15 Every match states its ruleset and label on the table cloth before play. Default circuit ruleset: Finkel/RoyalUr (Reconstructed). The Tablet ruleset unlocks in region 2 with an About card explaining what the tablet attests and what is filled in.
- R-16 Tablet ruleset (each element labelled): 5 pieces per player (Attested); astragal dice, modelled as 4 knucklebones whose faces map to move values (Attested that astragals were used; the face-to-value mapping and face probabilities are Reconstructed parameters in `dice.json`); fortunes attached to specific squares, implemented as omen draws when a piece lands there (Attested that squares carry fortunes; the in-game effects are Invented); route and safety identical to Finkel/RoyalUr (Reconstructed).
- R-17 The Tablet dice model is a data table of `(outcome, weight)` pairs; weights must sum to the model's denominator and are stated in the odds panel.

**Moves (clarifications)**
- R-18 When several pieces can move, the player chooses; when exactly one legal move exists, Assist mode auto-plays it after 0.6 s (toggle).
- R-19 A rosette extra roll may chain without limit.
- R-20 A capture on a rosette other than the central rosette is legal only in rulesets where `safeRosettes` excludes that square (data).

**Wager layer (clarifications)**
- R-21 A double may be offered only before rolling and only once per turn; an omen and a double may both be used in one turn, omen first.
- R-22 The "Crawford" rule applies in circuit finals: when a player is one match from elimination, the cube is dead for the next match.
- R-23 Omen effects may never change dice probabilities; they act only on choices (re-roll, split, safety toggles). This keeps pillar 1 honest.
- R-24 Tavern tells reveal the opponent's doubling and take thresholds rounded to 5%.

### A.2 Additional Invariants
- INV-6 For each dice model the probability table shown in the odds panel equals the model used by Core (snapshot test).
- INV-7 Omens never change the RNG draw sequence for dice (separate RNG stream `omen`).
- INV-8 Tablet ruleset uses exactly 5 pieces (conservation analogous to INV-1).
- INV-9 Equity table win probabilities lie in [0,1] and sum with the opponent's to 1 within 1e-9.

### A.3 Complete Schemas and Sample Rows

```swift
struct DiceModelDef: Codable, Sendable { var id: String; var label: HistoryLabel; var outcomes: [DiceOutcome]; var denominator: Int; var note: String }
struct DiceOutcome: Codable, Sendable { var value: Int; var weight: Int }
struct FortuneSquareDef: Codable, Sendable { var ruleset: String; var square: Int; var omenDeck: String; var label: HistoryLabel }
struct CircuitDef: Codable, Sendable { var regions: [RegionDef]; var startPurse: Int; var finalCrawford: Bool }
struct RegionDef: Codable, Sendable { var id: String; var name: String; var taverns: [String]; var unlocks: [String] }
struct MatchRecord: Codable, Sendable { var seed: UInt64; var ruleset: String; var stake: Int; var cubeFinal: Int; var winner: PlayerID; var gammon: Bool; var plies: Int }
```

```json
{ "id": "tetra4", "label": "Reconstructed", "outcomes": [{"value":0,"weight":1},{"value":1,"weight":4},{"value":2,"weight":6},{"value":3,"weight":4},{"value":4,"weight":1}], "denominator": 16, "note": "4 binary tetrahedra, from excavated Ur sets" }
{ "id": "astragal4", "label": "Reconstructed", "outcomes": [{"value":1,"weight":10},{"value":2,"weight":40},{"value":3,"weight":40},{"value":4,"weight":10}], "denominator": 100, "note": "Placeholder face odds pending HIST review; tablet attests astragals but not these values" }
{ "id": "tablet", "label": "Reconstructed", "trackLength": 14, "pieces": 5, "rosettes": [3,7,13], "safeRosettes": [7], "dice": "astragal4", "source": "BM 33333B (Finkel 2007); gaps filled from modern ruleset" }
{ "ruleset": "tablet", "square": 7, "omenDeck": "fortune_good", "label": "Invented" }
```

### A.4 Balance Tables and Sim Targets

| Parameter | Default | Range | Sim Target |
| --- | --- | --- | --- |
| Starting purse | 40 | 20–80 | Optimal bot completes circuit 55–70% |
| Minimum stakes by region | 5 / 10 / 20 | — | Naive bot completes 5–15% |
| Omen prices | 5–40 | — | Each omen bought in 10–40% of optimal runs |
| Double threshold (optimal) | 70% | 65–75% | Cube turned in 30–60% of matches |
| Tablet astragal odds | 10/40/40/10 | to be reviewed | Tablet match length 40–70 plies |

Solver checks: Finkel first-player win probability reported to 4 decimals and compared with RoyalUr.net's published figure; any difference > 0.0005 blocks G3.

### A.5 AI Design in Detail
- **Finkel/RoyalUr:** value iteration over all positions (state: pieces off/on/borne for each side, side to move); store win probability as `UInt16` (scaled 0–65,535) in a memory-mapped file (~ 275 MB on disk for the complete state space; ship compressed and lazily load per piece count, or ship a reduced 5-piece table and compute 7-piece on device at first launch with progress UI; ADR-0004 decides).
- **Tablet and variants:** expectiminimax depth 3 with chance nodes, eval = `pipsOpp − pipsMe + 6·rosettesHeld + 4·safePieces − 5·exposedPieces` (exposed = within 1–4 of an enemy behind it, weighted by roll probability).
- **Cube:** equity from win probability with gammon factor; personalities shift thresholds (gambler −10%, careful +5%) and bluffers double early at 55–60% with probability 0.3.
- **Omen policy:** play an omen when expected equity gain ≥ 0.05 (computed by 64 rollouts per candidate).

### A.6 Granular Task Breakdown

| ID | Task | Acceptance Criteria |
| --- | --- | --- |
| RS-P0.1 | HISTORY.md lists tablet-attested vs reconstructed elements | Self-checked by GLM against Finkel 2007 summary |
| RS-P1.1 | Path, moves, captures, rosettes (R-1–R-8, R-18–R-20) | 50 fixtures |
| RS-P1.2 | Dice models from data (R-17) | INV-2 and INV-6 |
| RS-P1.3 | Tablet ruleset (R-16) | INV-8; 20 fixtures |
| RS-P1.4 | Cube, gammon, Crawford (R-10, R-11, R-21, R-22) | 25 fixtures |
| RS-P1.5 | Omens on separate RNG stream (R-12, R-23) | INV-7 |
| RS-P2.1 | Board scene and piece animation | 60 fps; tap-to-move and drag |
| RS-P2.2 | Odds panel per move (win probability delta) | Matches solver table |
| RS-P2.3 | Cube UI and stake ledger | Ledger reconciles purse |
| RS-P3.1 | Circuit (3 regions × 4 taverns) | Lint; each tavern reachable |
| RS-P3.2 | About the Game: tablet vs excavated sets | Text marked pending HIST review |
| RS-P4.1 | Solver build and loader (ADR-0004) | INV-5; first-launch time ≤ 90 s if computed |
| RS-P4.2 | Personalities and tells | Circuit targets met |
| RS-P5.1 | Senet and Patolli variants with labels | Each labelled as one reconstruction among several |

### A.7 Sharpened Gate Checks
- G1 adds: χ² dice test for every model; Tablet ruleset fixtures pass.
- G3 adds: HISTORY.md and in-game labels agree for every rule (lint against `rulesets.json` labels).
- G5 adds: About screen distinguishes 3rd-millennium Ur sets from the 2nd-century BCE tablet.

### A.8 Additional Risks

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Players read the modern ruleset as "the original rules" | High | Medium | Labels, About card, Tablet ruleset | GLM |
| Gambling classification by App Store | Medium | High | No real money, no purchasable currency for stakes; age rating review | GLM |
| Solver table size | Medium | Medium | ADR-0004 options | GLM |

### A.9 Additional Open Questions (Defaults)
1. Which astragal face odds to use? Default: placeholder 10/40/40/10 flagged Reconstructed until a historian of ancient games reviews.
2. Name the default "Finkel rules"? Default: "Modern rules (Finkel/RoyalUr)", to avoid implying an ancient source.
3. Show tablet fortunes text? Default: paraphrase only after HIST review; no direct translation claims.
