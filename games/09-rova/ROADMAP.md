# 09 — Rova Roadmap

> Fanorona's sweeping captures, rebuilt as a roguelite: chain approach and withdrawal strikes across a shifting board and draft the rules you will play by.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 in full before starting. Depth pass (15 Nov 2026): Appendix A extends §4–§13 and wins where they differ. This roadmap adds only what is specific to Rova.

Research: [`RESEARCH.md`](RESEARCH.md) (art direction, design lineage, cultural context, advisor institutions, verified glossary, and audio direction).

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 09 · `rova` (working title; see §13) |
| Code prefix | `RV` (packages `RVCore`, `RVContent`, `RVAI`, `RVRender`, `RVAudio`, `RVPlatform`, `RVMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Line-capture tactics roguelite built on Fanorona |
| Difficulty tier | Intermediate |
| Scope | Small team |
| Session length | 3–8 minutes per board; a run 30–50 minutes |
| Renderer | SpriteKit (2D, paper texture with pressed flowers) |
| Players | Solo roguelite; classic Fanorona vs AI; local pass-and-play; async classic |
| Simulation | Turn-based, perfect information |
| Sourcing tier | `FULL` (Fanorona, the national game of Madagascar; Antaimoro paper craft) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** see above.
- **Summary:** Classic Fanorona (fanoron-tsivy, also written fanoron-sivy; 9 × 5 lines with diagonals at strong points, 22 pieces each) is fully implemented as "Classic". The roguelite mode ("Run") uses Fanorona's capture rules on smaller authored boards: the player commands a small band against waves of opponent pieces across 8–12 encounters. Between encounters the player drafts "charms" (rule modifiers, for example "your first capture each turn may use approach and withdrawal together") and recruits stronger pieces. Everything is built on the core rules: approach capture, withdrawal capture, chain captures that change direction, no revisiting points and no repeating direction in a chain, and mandatory capture when available.
- **Pillars:**
  1. **Respect the original.** Classic mode follows the established rules exactly (including vela opening rules in a variant).
  2. **Chains are the joy.** UI makes long chains discoverable and satisfying.
  3. **Rules you draft.** Charms bend rules within a closed, tested set of effects.
  4. **Malagasy voices.** Text, names, and art reviewed by Malagasy advisors.
- **Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Antaimoro paper `#EDE3CC`, fibre shadow `#D2C3A0`, pressed bougainvillea `#B33A6B`, frangipani `#F3E3A1`, fern `#4F6B3A`, laterite `#A5482A`, ink `#2A2420`, Player pieces dark `#3B2F2A`, light `#E9E1D2` with shell sheen. |
| Shapes | Board lines as pressed grass stems; pieces as seeds and shells. |
| Typography | SF Pro and a humanist serif (Charter); Malagasy text with correct orthography. |
| Motion | Captured lines fold away like paper; chain path draws as an ink stroke. |
| Music | Valiha (tube zither) and kabosy textures performed by Malagasy musicians (commissioned by the maintainer through a `needs-maintainer` issue). |
| SFX | Seed click, paper rustle, chain crescendo. |
| Haptics | Rising taps per captured piece in a sweep. |

- **Inspirations:** published Fanorona rule descriptions (see [`RESEARCH.md`](RESEARCH.md)); Schadd et al., "Best Play in Fanorona Leads to Draw" (2008); Slay the Spire and Into the Breach for run structure.

## 2. Tech Stack Decision

Per `_CONVENTIONS.md` §2, plus:
- **Board graph:** points and lines as a graph (classic board 45 points, strong points with 8 neighbours); authored boards via JSON graphs.
- **Search:** alpha-beta over whole-turn moves (a chain is one move) with TT.
- ADRs: ADR-0003 graph boards; ADR-0004 chain as single move; ADR-0005 charm effect closed set.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/RVCore/Sources/RVCore/
  Board/   BoardGraph.swift, Point.swift, Direction.swift, ClassicBoard.swift
  Rules/   Capture.swift (approach, withdrawal), Chain.swift, Mandatory.swift, Vela.swift, Paika.swift
  Run/     RunState.swift, Encounter.swift, Charm.swift, Recruit.swift, PieceKind.swift
  Engine/  GameState.swift, Action.swift, Event.swift, Reducer.swift, MoveGen.swift, Victory.swift, Zobrist.swift
Packages/RVContent/  BoardDef.swift, EncounterDef.swift, CharmDef.swift, PieceKindDef.swift, Loader.swift
Packages/RVAI/       AlphaBeta.swift, Eval.swift, WaveAI.swift, Tiers.swift
Packages/RVRender/   BoardScene.swift, ChainPreview.swift, PaperShader.fsh
Packages/RVMeta/     RunMeta.swift, Unlocks.swift, DailyRun.swift, Stats.swift
Resources/Content/   boards.json, encounters.json, charms.json, pieces.json, balance.json, tutorial.json, glossary.json, cultural_manifest.json
```

## 4. Core Rules Specification

**Classic**
- R-1 Board: 9 × 5 grid of points; orthogonal lines everywhere; diagonal lines from strong points (points where x + y is even). Initial setup: 22 pieces each, filling each side's two rows and alternating in the middle row, centre empty.
- R-2 A move slides one piece along a line to an adjacent empty point.
- R-3 Approach capture: moving toward an enemy piece directly beyond the destination along the same line captures it and every contiguous enemy piece beyond it on that line.
- R-4 Withdrawal capture: moving directly away from an adjacent enemy piece along the line captures it and the contiguous line behind it.
- R-5 If a move allows both approach and withdrawal, the player chooses one.
- R-6 Chain: after a capturing move, the same piece may continue capturing, but cannot move in the same direction twice consecutively and cannot return to a point visited this turn. The player may stop the chain at any time (except in mandatory variants, per ruleset).
- R-7 Capturing is mandatory: if any capturing move exists, a non-capturing move (paika) is illegal.
- R-8 The first move of the game may capture only along one chain step (per common rule; ruleset flag).
- R-9 Win by capturing all enemy pieces. Draw by repetition (3×) or 50 plies without capture (ruleset flag).
- R-10 Vela variant (Attested in rule sources; see research file): in the game after a win, the previous loser moves first. Until the previous winner is reduced to 5 pieces, the previous loser captures exactly one piece per move (the nearest piece in the capture line, no chains, no paika), and the previous winner makes no captures; every move of the previous winner must leave the previous loser a capture, or the previous winner forfeits. When the previous winner has 5 pieces left, normal rules resume.

**Run mode**
- R-11 Encounter boards are graphs; the player's band starts with 6–10 pieces; enemies have kinds (standard, Shield: immune to withdrawal, Root: cannot be moved by charms, Elder: counts 2 for win quotas).
- R-12 Encounter objectives: capture all, capture quota within N turns, survive N turns, or escort a piece to a point.
- R-13 Charms (max 5 held): closed effect set — `doubleCapture` (approach and withdrawal in one move), `extraStep` (one paika after a chain), `ignoreDirectionRepeatOnce`, `diagonalEverywhere` (for one turn), `stoneOfReturn` (revive one piece), and others listed in `charms.json` (≤ 24 effect kinds).
- R-14 Recruits: after each encounter choose 1 of 3 rewards (charm, piece upgrade, or heal).
- R-15 A run ends when the band has no pieces left at encounter start or after the final encounter.

**Invariants**
- INV-1 Every legal chain obeys R-6.
- INV-2 Mandatory capture: if any capture exists, generated moves are all captures.
- INV-3 Piece conservation per turn.
- INV-4 Replay determinism.
- INV-5 Classic perft at depths 1–3 from start matches a reference implementation in `Tests/Reference/` written independently.

## 5. Data Schemas and Content Tables

```swift
struct BoardDef: Codable, Sendable { var id: String; var points: [PointDef]; var lines: [[Int]]; var setup: [Int: Side]; var cultural: Bool }
struct CharmDef: Codable, Sendable { var id: String; var effect: CharmEffect; var rarity: Int; var nameKey: String }
enum Action: Codable, Hashable { case paika(from: Int, to: Int), capture(path: [Int], kinds: [CaptureKind]), stop, pass }
```

| Table | G3 | G5 | Sample row |
| --- | --- | --- | --- |
| `boards.json` | 10 | 30 | `{ "id": "rice_terrace", "points": "<graph>", "setup": {...} }` |
| `encounters.json` | 15 | 45 | `{ "id": "e07", "board": "rice_terrace", "objective": {"kind": "quota", "n": 8, "turns": 10}, "enemies": [...] }` |
| `charms.json` | 12 | 36 | `{ "id": "double_strike", "effect": {"kind": "doubleCapture"}, "rarity": 2, "nameKey": "charm.double_strike" }` |
| `glossary.json` | 10 | 25 | `"fanorona", "paika", "vela", "manindrona", "misintona"` (pending advisor) |

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| Starting band | 8 | 6–10 | `balance.json` |
| Charm cap | 5 | 3–7 | `balance.json` |
| Encounters per run | 10 | 8–12 | `balance.json` |
| Elder weight | 2 | 1–3 | `balance.json` |

Targets: Classic first-player results across top-tier self-play mostly draws (consistent with the solved result); run win rate for a greedy bot 15–25%, for a search bot 45–60%; median chain length 2–3 with ≥ 5% of turns ≥ 5.

## 7. AI Approach

- **Classic:** alpha-beta, whole-chain moves, eval = material + mobility + strong-point control; tiers Novice, Player, Master (1.0 s), Mpanjaka-equivalent name pending advisor (2.5 s).
- **Run enemies:** wave AI with greedy-plus-depth-2 search; per-encounter scripts in data (for example "hold the line").

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7, SRC0.1, SRC0.2, HIST0.1 (Attested: Fanorona rules, vela, board; Invented: run mode, charms).

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; SRC0.1, SRC0.2, HIST0.1 complete
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- RV-P1.1 Graph board, classic rules (R-1 to R-9), chain generation, mandatory capture.
- RV-P1.2 Reference implementation and perft (INV-5).
- RV-P1.3 Run rules (R-11 to R-15) and charm effects.

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-15 tagged tests; INV-1…INV-5
  [ ] RVCore coverage ≥ 90%; make sim N=5000 deterministic
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5, SRC2.1, SRC2.2.
- RV-P2.1 Board scene, drag a piece; chain preview shows capture lines before release; approach/withdrawal chooser when ambiguous; "Stop chain" button.
- RV-P2.2 Classic vs Player AI; three-encounter run slice.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test completes a classic game and a three-encounter run on iPad and Mac
  [ ] Manifest marks glossary, music, and art pending; deny-list passes
  [ ] `docs/SLICE_ASSESSMENT.md` written: self-assessment against the pillars, with every weakness turned into a P3 task (`_CONVENTIONS.md` §8.1)
Sign-off: GLM-SELF
```

### P3 Content and Systems
- RV-P3.1 G3 content; About the Tradition (SRC3.1); HIST3.1.
- RV-P3.2 Tutorial (5 lessons); pass-and-play; run save and resume.

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts met; lint clean; 1,000 bot runs complete
Sign-off: GLM-SELF
```

### P4 AI Opponents
- RV-P4.1 Tiers; wave AI; `docs/BALANCE.md`.

```
GATE G4 — AI
Checks:
  [ ] Each tier beats the one below ≥ 70%; run win targets met; p95 budgets
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- RV-P5.1 G5 counts; daily run; unlocks; 24 achievements; SRC5.1; HANDOFF.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Counts met; daily deterministic; packet and HANDOFF complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- RV-P6.1 Paper art (ideally by a Malagasy illustrator, commissioned by the maintainer through a `needs-maintainer` issue); music (commissioned).
- RV-P6.2 SRC6.1 and SRC6.2 advisor review.

```
GATE G6 — Aesthetics and Cultural Review
Checks:
  [ ] Advisor review filed as a `needs-maintainer` issue (SUBSTITUTED, `_SET2_ADDENDUM.md` §4); every entry still pending advisor review listed in that issue; snapshots approved
Sign-off: GLM-SELF
```

### P7 Platform Features
- RV-P7.1 Game Center, async classic, iCloud; Malagasy and French localisation (a maintainer decision filed as an issue; GLM ships String Catalogs ready for translation).

```
GATE G7 — Platform
Checks:
  [ ] Async classic completes; localisation pseudo-tests pass
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- RV-P8.1 VoiceOver chain navigation (rotor of capture options); colour-independent sides.

```
GATE G8 — Polish
Checks:
  [ ] VoiceOver classic game; budgets met
Sign-off: GLM-SELF
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard tasks; SRC9.1; SRC10.1.

```
GATE G9 — Beta
Checks:
  [ ] Crash-free ≥ 99.5%; community playtest filed as a `needs-maintainer` issue (SUBSTITUTED: scripted UI-test playthroughs and recordings, `_CONVENTIONS.md` §8.2)
Sign-off: GLM-SELF
GATE G10 — Release
Checks:
  [ ] SRC10.1 credits draft filed as a `needs-maintainer` issue (SUBSTITUTED); final CI green
Sign-off: GLM-SELF
```

### Key Test Fixtures (GLM Writes These in P1)

1. Opening position: exactly the legal first moves listed in `Tests/Fixtures/classic_opening.json` (all captures, since capture is mandatory).
2. Approach-or-withdrawal choice: a move that allows both produces two distinct `capture` actions with different `kinds`.
3. Chain direction rule: a chain attempting the same direction twice in a row is rejected.
4. Chain revisit rule: a chain returning to a visited point is rejected.
5. Paika illegal when any capture exists (20 positions).
6. Shield enemy immune to withdrawal capture; approach still captures it.
7. `doubleCapture` charm: one move removes both the approach line and the withdrawal line.
8. Run reset: losing all band pieces at encounter start ends the run with the correct summary.

## 9. Fragile Areas and Priorities

- **Fragile areas:** chain generation with charm effects; first-move restriction flag.
- **Priorities for P6–P10:** chain preview UX, VoiceOver; charm balance; cultural packet.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Misrepresenting Fanorona | Medium | High | Classic mode exact, advisors | GLM |
| Chain UX confusing | Medium | High | Previews, tutorial | GLM |
| Run balance | Medium | Medium | Sims, data tuning | GLM |

## 11. Out of Scope

Fanoron-telo and fanoron-dimy at launch (post-launch candidates); online ranked play.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 2 |
| P1 | GLM | 6–8 |
| P2 | GLM | 5–7 |
| P3 | GLM | 6–8 |
| P4 | GLM | 4–6 |
| P5 | GLM | 4–6 |
| P6 | GLM | 7–10 |
| P7 | GLM | 3–5 |
| P8 | GLM | 3–4 |
| P9 | GLM | 4–6 |
| P10 | GLM | 2–3 |
| **Total** | | **46–65** |

## 13. Open Questions

1. Title "Rova" (Malagasy for a royal enclosure) needs advisor input. Default: "Rova" stays the working title; GLM files a `needs-maintainer` issue for advisor input and continues.
2. Malagasy localisation at launch? Default: yes if a translator is available.

## 14. Sourcing Notes

- **Sources:** Schadd, Winands, Uiterwijk, van den Herik, and Bergsma, "Best Play in Fanorona Leads to Draw", New Mathematics and Natural Computation 4(3):369–387 (2008) (weakly solved as a draw); published rule descriptions (distad.net Fanorona rules PDF; Super Duper Games rules PDF; Wikipedia "Fanorona"); Antaimoro paper descriptions from Malagasy craft sources (Unverified). The previously cited "Montgomery (1886)" could not be verified and was removed.
- **Restricted elements:** no sikidy (divination) or ancestral (razana) imagery; no royal symbols beyond the title if approved.
- **Glossary seeds (verified against rule sources; pending advisor):** fanorona, fanoron-tsivy (9 × 5), fanoron-dimy (5 × 5), fanoron-telo (3 × 3), paika (non-capturing move), vela (rematch handicap), manindrona (approach capture), and misintona (withdrawal capture). "vakizoro" could not be verified and was removed.

## Appendix A. Extended Specification (Depth Pass)

### A.1 Additional Rules

**Classic clarifications**
- R-16 Points are indexed `i = y·9 + x` (x 0–8, y 0–4). Strong points have `(x + y)` even and connect diagonally to strong neighbours; weak points connect orthogonally only.
- R-17 Opening setup (R-1): rows y = 0–1 are Side A, rows y = 3–4 Side B; the middle row is `B A B A · B A B A` from x = 0 (alternation as in published diagrams), centre (4,2) empty. A ruleset flag mirrors colours if a source differs.
- R-18 A capture line stops at the first empty point or enemy-free point or board edge; friendly pieces end the line.
- R-19 When approach and withdrawal are both possible with one move, the player chooses one (R-5); both is never allowed in Classic (only via the Run charm `doubleCapture`).
- R-20 During a chain the moving piece may not revisit any point it occupied this turn, including the starting point; the direction restriction (R-6) compares direction vectors of consecutive capturing steps.
- R-21 A chain step must itself capture; a non-capturing step ends the turn and is illegal mid-chain.
- R-22 Draw rules are ruleset flags because sources differ: `repetition3`, `noCapture50`, or none (agreement only). Default: both enabled, labelled Invented convenience rules.
- R-23 Vela (R-10) applies only when the player enables "Vela series" in Classic; the series tracks the previous winner across games.

**Run mode clarifications**
- R-24 Encounter graphs must be planar with ≤ 45 points and use only orthogonal and diagonal unit edges (renders like a Fanorona board fragment).
- R-25 Shield enemies are immune to withdrawal; Root enemies cannot be displaced by charm effects; Elder enemies count 2 toward quotas; Runner enemies move 2 steps when not capturing (≤ 1 per wave).
- R-26 Enemy waves spawn on marked edge points at the start of specified turns; spawning onto an occupied point is skipped.
- R-27 Charm stacking: at most one charm of each effect kind; duplicates convert to 10 coins.
- R-28 Coins buy heals (3), upgrades (5), and rerolls (2) at camps between acts.

### A.2 Additional Invariants
- INV-6 Classic move generator equals the independent reference on 1,000 random positions (all chains, both capture kinds).
- INV-7 Vela: in vela phase every generated move of the previous winner leaves at least one capture for the previous loser, else the only legal action is forfeit.
- INV-8 Charm effects never alter Classic (lint: Classic rulesets have empty charm lists).
- INV-9 Each encounter is winnable: solver finds a winning line for the default band at depth ≤ 6 with no charms (generator check).

### A.3 Complete Schemas and Sample Rows

```swift
struct PointDef: Codable, Sendable { var id: Int; var x: Int; var y: Int; var strong: Bool; var spawn: Bool }
struct RuleSetDef: Codable, Sendable { var id: String; var label: HistoryLabel; var firstMoveSingleCapture: Bool; var mandatoryCapture: Bool; var mandatoryChain: Bool; var draws: [DrawRule]; var vela: Bool; var source: String }
enum CaptureKind: String, Codable, Sendable { case approach, withdrawal }
struct EnemyDef: Codable, Sendable { var id: String; var kind: EnemyKind; var hp: Int; var ai: String }
struct EncounterDef: Codable, Sendable { var id: String; var board: String; var objective: Objective; var waves: [Wave]; var act: Int; var rewards: [String] }
struct Wave: Codable, Sendable { var turn: Int; var spawns: [Int: String] }
struct RunState: Codable, Sendable { var seed: UInt64; var act: Int; var encounter: Int; var band: [BandPiece]; var charms: [String]; var coins: Int }
struct VelaState: Codable, Hashable, Sendable { var previousWinner: Side; var active: Bool }
```

```json
{ "id": "classic", "label": "Attested", "firstMoveSingleCapture": true, "mandatoryCapture": true, "mandatoryChain": false, "draws": ["repetition3", "noCapture50"], "vela": false, "source": "distad.net; Super Duper Games; Wikipedia" }
{ "id": "classic_vela", "label": "Attested", "firstMoveSingleCapture": true, "mandatoryCapture": true, "mandatoryChain": false, "draws": ["repetition3"], "vela": true, "source": "distad.net Fanorona rules (vela section)" }
{ "id": "e07", "board": "terrace_small", "objective": {"kind": "quota", "n": 8, "turns": 10}, "waves": [{"turn": 1, "spawns": {"3": "standard", "5": "shield"}}, {"turn": 4, "spawns": {"0": "elder"}}], "act": 1, "rewards": ["charm", "upgrade", "heal"] }
{ "id": "double_strike", "effect": {"kind": "doubleCapture"}, "rarity": 2, "nameKey": "charm.double_strike" }
```

### A.4 Balance Tables and Sim Targets

| Parameter | Default | Range | Sim Target |
| --- | --- | --- | --- |
| Starting band | 8 | 6–10 | Act 1 clear rate (Master pilot) 85–95% |
| Charms held | 5 | 3–6 | Median charms used per encounter 1–2 |
| Shield frequency | 20% of enemies | 10–35% | Withdrawal share of captures 30–50% |
| Quota turns | per encounter | — | Quota encounters failed 10–25% |
| Coin rewards | 3–6 | — | Camp purchases 1–2 per camp |
| Classic Master time | 1.0 s | — | Master vs Player ≥ 75% |

Run sims: 5,000 seeded runs with the Master pilot and 5,000 with a greedy pilot; win rate 30–45% (Master) and 2–8% (greedy); no single charm in > 60% of winning runs.

### A.5 AI Design in Detail
- **Chain generation:** DFS from each piece over capture steps with visited-set and last-direction state; each complete chain prefix is a candidate (player may stop). Typical branching 5–40 in Classic.
- **Evaluation:** `100·(pieces_me − pieces_opp) + 6·mobility + 4·strongPointsHeld + 8·captureThreatsMe − 10·hangingPieces` where hanging pieces are those capturable next ply.
- **Search:** alpha-beta with iterative deepening, TT keyed on position + side + vela state, move ordering by capture size; endgame tablebases are out of scope.
- **Vela AI:** previous-winner side uses a filtered generator (INV-7) and evaluates by keeping its piece count high while giving minimal captures.
- **Run enemies:** wave AI greedy + depth 2; scripted behaviours (`holdLine`, `rushEscort`, `guardElder`) as data.

### A.6 Granular Task Breakdown

| ID | Task | Acceptance Criteria |
| --- | --- | --- |
| RV-P0.1 | SOURCING.md with verified rule sources and glossary statuses | Every term has status and URL |
| RV-P1.1 | Board graph and setup (R-1, R-16, R-17) | Setup snapshot matches published diagram |
| RV-P1.2 | Approach and withdrawal (R-3, R-4, R-18, R-19) | 40 fixtures |
| RV-P1.3 | Chains (R-6, R-20, R-21) | INV-1; 30 fixtures |
| RV-P1.4 | Mandatory capture and first move (R-7, R-8) | INV-2 |
| RV-P1.5 | Draw flags (R-9, R-22) | 10 fixtures |
| RV-P1.6 | Vela series (R-10, R-23) | INV-7; 15 fixtures |
| RV-P1.7 | Reference generator and perft | INV-5, INV-6 |
| RV-P2.1 | Board renderer with line art | Snapshot tests on 3 sizes |
| RV-P2.2 | Capture choice UI (approach vs withdrawal) | Prompt appears only when both possible |
| RV-P2.3 | Chain drawing with stop button | Matches Core chains |
| RV-P3.1 | Run content (15 encounters, 12 charms) | Lint; INV-9 |
| RV-P3.2 | About the Tradition placeholders | Pending marks |
| RV-P4.1 | Classic AI tiers | Gaps ≥ 75% |
| RV-P4.2 | Run sims | Targets met |
| RV-P5.1 | Acts 2–3 and camps | 45 encounters lint clean |

### A.7 Sharpened Gate Checks
- G1 adds: opening position perft depth 1–3 equals reference (INV-5); vela fixtures pass.
- G3 adds: glossary contains no unverified terms (vakizoro removed).
- G5 adds: title question recorded in the advisor issue; "Rova" stays the working title, and the title string lives in one String Catalog key so a later change is one edit.

### A.8 Additional Risks

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| "Rova" (royal enclosure) title seen as appropriative | Medium | High | Advisor decision; fallback "Fanorona Run" | GLM |
| Rule variants dispute (setup colours, draws) | Medium | Low | Ruleset flags with sources | GLM |
| Chain UI confusion | Medium | Medium | Ghost path preview | GLM |

### A.9 Additional Open Questions (Defaults)
1. Include fanoron-dimy and fanoron-telo at launch? Default: post-launch.
2. Use Malagasy terms in UI (manindrona/misintona) or English (approach/withdrawal)? Default: English with Malagasy in tooltips after advisor approval.
3. Top AI tier name? Default: "Master"; no royal titles.
