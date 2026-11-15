# 08 — Turncoat Roadmap

> Condottieri sell their swords to the highest bidder: capture an enemy company and it fights for you next turn, unless its contract says otherwise.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 in full before starting. Depth pass (15 Nov 2026): Appendix A extends §4–§13 and wins where they differ. This roadmap adds only what is specific to Turncoat.

Research: [`RESEARCH.md`](RESEARCH.md) (art direction, design lineage, cultural context, advisor institutions, verified glossary, and audio direction).

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 08 · `turncoat` |
| Code prefix | `TC` (packages `TCCore`, `TCContent`, `TCAI`, `TCRender`, `TCAudio`, `TCPlatform`, `TCMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Drop-capture tactics (shogi family) with a mercenary campaign |
| Difficulty tier | Deep |
| Scope | Small team |
| Session length | 15–30 minutes per battle; campaign 6–10 hours |
| Renderer | SpriteKit (2D, tempera-panel style with gold-leaf highlights) |
| Players | Solo campaign vs AI; local pass-and-play; async online |
| Simulation | Turn-based, perfect information |
| Sourcing tier | `HISTORICAL` (Renaissance Italian condottieri; drop rule borrowed as a mechanic from shogi, credited) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** see above.
- **Summary:** A 9 × 9 battlefield. Each side fields companies (pieces) with distinct movement. Captured companies go to the captor's reserve and may later be dropped onto empty squares as the captor's own, as in shogi. Twist one: every company is a two-faced tile — its front face shows its current employer's livery and moves one way; when it promotes (entering the last three ranks) it flips to a veteran face. Twist two: contracts. Each company has a loyalty value (0–3). A company with loyalty ≥ 2 captured from you returns to your reserve instead of the captor's on its first capture ("they ransom themselves back"), consuming one loyalty. Loyalty grows by winning battles in the campaign and is spent by ransoms. Win by capturing the enemy captain (checkmate equivalent: the captain has no escape) or by holding the enemy's banner square for 2 full turns. The campaign is a map of Italian city-states (1440s, fictionalised) where you hire, pay, and lose companies between battles.
- **Pillars:**
  1. **Nothing dies; everything changes sides.** Material never leaves the game.
  2. **Contracts are counterplay.** Loyalty makes some captures poisoned.
  3. **Readable threats.** Every square shows which pieces attack it on demand; drop squares are highlighted.
  4. **Campaign with consequence.** Companies you lose in battle may serve your rival in the next.
- **Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Tempera ground `#E4D3B0`, terre verte `#6F7F5A`, vermilion `#C0392B`, azurite `#2E5E8E`, lead white `#F4EFE4`, gold leaf `#C8A34A`, umber `#5B4128`, lance black `#1C1C1C`. Livery colours per employer (6) from this palette plus pairs. |
| Shapes | Piece tiles as pentagonal shields (pointing toward the enemy, like shogi pieces) with heraldic charges; board as a foreshortened field with lances in Uccello's perspective grid. |
| Typography | Roman inscriptional capitals (default: Trajan-like Cinzel, OFL) and SF Pro. |
| Motion | Tiles flip in 300 ms with gold glints; drops fall from the reserve with banner flutter. |
| Music | Renaissance consort (shawms, sackbuts, lute) in original compositions; drums for battle. |
| SFX | Hoof on turf, steel clash, coin bag, banner snap. |
| Haptics | Clack on capture; double tick on flip. |

- **Inspirations:** Shogi (Japan Shogi Association rules); Uccello's "The Battle of San Romano"; Mallett, "Mercenaries and Their Masters"; Crazyhouse chess.

## 2. Tech Stack Decision

Per `_CONVENTIONS.md` §2, plus:
- **Board:** 81-square mailbox with bitboards (`UInt128` via two `UInt64`) for attack maps.
- **Search:** alpha-beta (PVS) with Zobrist hashing including reserve counts and loyalty; null-move pruning disabled in positions with drops pending (ADR-0005).
- ADRs: ADR-0003 piece set and movement data; ADR-0004 loyalty and ransom; ADR-0005 search pruning choices.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/TCCore/Sources/TCCore/
  Board/     Square.swift, Bitboard.swift, Attacks.swift
  Pieces/    PieceKind.swift, Face.swift, Movement.swift, Promotion.swift, Loyalty.swift
  Engine/    GameState.swift, Action.swift, Event.swift, Reducer.swift, MoveGen.swift, Check.swift, Victory.swift, Zobrist.swift, Repetition.swift
  Campaign/  CampaignState.swift, CityState.swift, Contract.swift, Treasury.swift, Muster.swift
Packages/TCContent/  PieceDef.swift, EmployerDef.swift, MapDef.swift, BattleDef.swift, EventDef.swift, Loader.swift
Packages/TCAI/       PVS.swift, Eval.swift, PieceSquareTables.swift, CampaignAI.swift, Personalities.swift
Packages/TCRender/   FieldScene.swift, TileNode.swift, ReserveTray.swift, AttackOverlay.swift
Packages/TCMeta/     Campaign.swift, Puzzles.swift, Stats.swift
Resources/Content/   pieces.json, employers.json, map.json, battles.json, events.json, puzzles.json, balance.json, tutorial.json
```

## 4. Core Rules Specification

**Board and pieces**
- R-1 9 × 9 board; each side's first three ranks are its camp; the opposite three are its promotion zone. Each side has a banner square (centre of its back rank).
- R-2 Standard army (data): 1 Captain, 2 Lances, 2 Crossbows, 2 Knights, 2 Halberds, 1 Bombard, 1 Engineer, 9 Pikes. Movement per `pieces.json` (step, slide, leap patterns, relative to owner's forward direction).
- R-3 Each piece has a front face and a veteran face; promotion is optional on entering, moving within, or leaving the promotion zone, mandatory when the piece would otherwise have no legal moves. Captains do not promote.

**Moves and drops**
- R-4 A turn is either a board move or a drop.
- R-5 Capturing an enemy piece removes it; it reverts to its front face and goes to the captor's reserve (subject to R-9).
- R-6 Drop: place a reserve piece face-up (front face) on any empty square, except: a Pike cannot be dropped on a file containing an unpromoted friendly Pike; no piece may be dropped where it would have no legal move; a Pike drop cannot deliver immediate captain mate (as in shogi's uchifuzume).
- R-7 Check: a captain under attack must be relieved; moves leaving one's captain attacked are illegal.
- R-8 Repetition: the same position (board, reserves, side to move, loyalties) four times ends the battle as a draw, except perpetual check loses for the checker.

**Contracts and loyalty**
- R-9 Loyalty: each piece entering a battle has loyalty L (0–3) from its contract. When a piece with L ≥ 2 is captured, it goes to its original owner's reserve instead (ransom), and L decreases by 1. Pieces with L ≤ 1 defect normally. Loyalty of a defected piece resets to 0 for its new owner.
- R-10 Captains have no loyalty and cannot be dropped.

**Victory**
- R-11 Captain mate wins.
- R-12 Banner: a side occupying the enemy banner square at the end of its turn for two consecutive own turns, with that piece not attacked at the end of either, wins.
- R-13 Turn cap 200 plies → adjudicated by material value (data) then draw.

**Campaign**
- R-14 Map of 9 city-states; each season the player chooses an employer contract (pay, target, battle type). Battles may have special setups (sieges, river fords).
- R-15 Muster: before a battle, choose up to the battle's point budget from your company roster; companies captured at battle end (in the enemy reserve) join the enemy roster; companies in your reserve at the end join yours.
- R-16 Treasury: pay upkeep per company per season; unpaid companies lose 1 loyalty.

**Invariants**
- INV-1 Piece conservation within a battle (board + reserves totals constant).
- INV-2 Perft counts on 10 reference positions match the stored values (generated by an independent slow move generator in tests).
- INV-3 Zobrist hash incremental equals full recompute.
- INV-4 Replay determinism.
- INV-5 Loyalty never exceeds 3 or drops below 0.

## 5. Data Schemas and Content Tables

```swift
struct PieceDef: Codable, Sendable { var id: String; var front: MovementPattern; var veteran: MovementPattern?; var value: Int; var veteranValue: Int; var label: HistoryLabel }
struct MovementPattern: Codable, Sendable { var steps: [Offset]; var slides: [Offset]; var leaps: [Offset] }
struct Contract: Codable, Hashable, Sendable { var employer: String; var pay: Int; var loyaltyGrant: Int; var target: String; var seasons: Int }
enum Action: Codable, Hashable { case move(from: Square, to: Square, promote: Bool), drop(PieceKind, Square), resign, offerDraw, acceptDraw }
```

| Table | G3 | G5 | Sample row |
| --- | --- | --- | --- |
| `pieces.json` | 10 kinds | 12 | `{ "id": "knight", "front": {"leaps": [[-1,2],[1,2]]}, "veteran": {"steps": [[0,1],[1,1],[-1,1],[1,0],[-1,0],[0,-1]]}, "value": 4, "veteranValue": 6, "label": "Invented" }` |
| `employers.json` | 6 | 9 | `{ "id": "florence", "name": "Florence", "livery": ["#C0392B","#F4EFE4"], "pay": 3, "label": "Attested" }` |
| `battles.json` | 10 | 30 | `{ "id": "ford_of_arno", "setup": "<FEN-like>", "special": "river_rank_5_blocks_slides", "budget": 40 }` |
| `events.json` | 12 | 40 | `{ "id": "plague", "effect": "upkeep_+1", "label": "Attested" }` |
| `puzzles.json` | 40 | 150 | mate-in-N and banner-in-N |

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| Piece values | per row | — | `pieces.json` |
| Ransom threshold L | 2 | 2–3 | `balance.json` |
| Banner hold turns | 2 | 1–3 | `balance.json` |
| Upkeep per company | 1 | 0–2 | `balance.json` |
| Battle budget | 40 | 30–60 | `battles.json` |

Targets: standard battle first-player win rate 50–56% (shogi baseline); banner victories 10–25% of decisive games; ransom triggers in 30–60% of battles; campaign completion for Captain-tier bot 40–60%.

## 7. AI Approach

- **Search:** PVS with TT, killer and history heuristics, check extensions, late move reductions; quiescence includes captures and checks (drops excluded except checking drops).
- **Evaluation:** material (including reserve pieces at 1.1× value), piece-square tables per kind, captain safety (attackers near captain, escape squares), banner pressure, loyalty-adjusted material (pieces with L ≥ 2 count less to the attacker).
- **Tiers:** Recruit (depth 2), Sergeant (depth 4), Captain (1.0 s), Condottiero (3.0 s with TT 2²²).
- **Campaign AI:** employers choose contracts by utility; rival condottieri as personalities (aggressive, mercenary, loyal).

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7, HIST0.1 (Attested: condottieri, contracts called condotte, liveries, employers; Invented: piece movements, loyalty mechanic). Credit shogi's drop rule in `docs/HISTORY.md`.

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; HIST0.1 complete
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- TC-P1.1 Bitboards, attacks, move generation, drops with restrictions (R-1 to R-7).
- TC-P1.2 Loyalty and ransom (R-9, R-10); repetition; victory (R-8, R-11 to R-13).
- TC-P1.3 Perft reference suite (INV-2).

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-13 tagged tests; INV-1…INV-5
  [ ] Perft depth 4 from start < 2 s; TCCore coverage ≥ 90%; make sim N=2000 deterministic
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5.
- TC-P2.1 Field scene; drag or tap-tap moves; reserve tray with drop highlights; promotion prompt; attack overlay on long-press.
- TC-P2.2 One battle vs Sergeant.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test completes a battle including a drop, a promotion, and a ransom, on iPad and Mac
  [ ] `docs/SLICE_ASSESSMENT.md` written: self-assessment against the pillars, with every weakness turned into a P3 task (`_CONVENTIONS.md` §8.1)
Sign-off: GLM-SELF
```

### P3 Content and Systems
- TC-P3.1 Campaign (R-14 to R-16) with G3 counts; HIST3.1 labels.
- TC-P3.2 Tutorial (6 lessons); puzzles (40).
- TC-P3.3 Pass-and-play; save and resume.

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts met; lint clean; 500 bot campaigns complete without softlocks
Sign-off: GLM-SELF
```

### P4 AI Opponents
- TC-P4.1 Tiers; campaign AI; `docs/BALANCE.md`.

```
GATE G4 — AI
Checks:
  [ ] Each tier beats the one below ≥ 70% over 400 games; p95 budgets
  [ ] Targets in §6 met or ADR
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- TC-P5.1 G5 counts; daily puzzle; stats; 24 achievements; HANDOFF.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Counts met; daily deterministic; HANDOFF complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- TC-P6.1 Tempera tile art (commissioned heraldic charges); battlefield backdrops; HIST6.1 fact-check.
- TC-P6.2 Consort music; SFX.

```
GATE G6 — Aesthetics
Checks:
  [ ] Snapshots approved; HIST6.1 clean
Sign-off: GLM-SELF
```

### P7 Platform Features
- TC-P7.1 Game Center, async battles, iCloud campaign saves; Mac keyboard notation entry.

```
GATE G7 — Platform
Checks:
  [ ] Async battle completes; iCloud round-trip
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- TC-P8.1 Piece glyph mode (abstract symbols) for clarity; VoiceOver board rotor; owner shown by tile orientation and pattern.

```
GATE G8 — Polish
Checks:
  [ ] VoiceOver battle; budgets met
Sign-off: GLM-SELF
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard tasks.

```
GATE G9 — Beta
Checks:
  [ ] Crash-free ≥ 99.5%; no S1/S2
Sign-off: GLM-SELF
GATE G10 — Release
Checks:
  [ ] Store assets; final CI green
Sign-off: GLM-SELF
```

## 9. Fragile Areas and Priorities

- **Fragile areas:** drop restrictions (pike-drop mate), repetition with loyalty in the hash, campaign roster transfers.
- **Priorities for P6–P10:** tile art pipeline, VoiceOver; piece values and banner rule balance.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Too close to shogi | Medium | Medium | Loyalty, banner, campaign; credit shogi | GLM |
| Learning curve | High | Medium | Glyph mode, tutorial, puzzles | GLM |
| Search slow with drops | Medium | Medium | Move ordering, budgets | GLM |

## 11. Out of Scope

Standard shogi mode; 3D board; online ranked ladder.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 2 |
| P1 | GLM | 8–11 |
| P2 | GLM | 5–7 |
| P3 | GLM | 7–10 |
| P4 | GLM | 6–9 |
| P5 | GLM | 3–5 |
| P6 | GLM | 8–11 |
| P7 | GLM | 4–6 |
| P8 | GLM | 3–5 |
| P9 | GLM | 4–6 |
| P10 | GLM | 2–3 |
| **Total** | | **52–75** |

## 13. Open Questions

1. Real city-state names (Florence, Milan, Venice) or fictionalised ones? Default: real names, fictional events.

## 14. Sourcing Notes

- **Sources:** Mallett, "Mercenaries and Their Masters" (1974); Caferro on John Hawkwood; National Gallery notes on San Romano; Japan Shogi Association rules for the drop mechanic.
- **Historical labels:** condotte and liveries Attested; battles fictional.

## Appendix A. Extended Specification (Depth Pass)

### A.1 Additional Rules

**Movement table (G3 army, Invented)**

| Piece | Front Face | Veteran Face | Value / Veteran |
| --- | --- | --- | --- |
| Captain | 1 step any direction | — | ∞ |
| Lance | slide forward | Captain-like 1 step any direction except diagonal back | 3 / 6 |
| Crossbow | slide diagonally (bishop) | slide diagonally + 1 orthogonal step | 8 / 10 |
| Knight | leap 2 forward + 1 sideways (forward only) | 1 step forward, sideways, back, and forward diagonals | 4 / 6 |
| Halberd | 1 step forward or diagonally forward, or 1 back | slide orthogonally (rook) | 5 / 9 |
| Bombard | slide orthogonally, must jump exactly 1 piece to capture (cannon) | as front + 1 step any direction | 7 / 9 |
| Engineer | 1 step orthogonally; may swap with an adjacent friendly piece instead of moving | as front + diagonal steps | 3 / 5 |
| Pike | 1 step forward | Captain-like minus diagonal back | 1 / 5 |

- R-17 Bombard capture (R-2 data): the Bombard moves like a rook when not capturing; to capture it must jump exactly one piece (either colour) along the line. Bombards cannot be dropped on the promotion zone.
- R-18 Engineer swap counts as a move of both pieces but cannot move a piece into check or out of the camp into the promotion zone (no promotion by swap).
- R-19 A piece dropped in the promotion zone may not promote until it moves.
- R-20 Pike and Lance must promote on reaching the last rank; Knight must promote on reaching the last two ranks (no legal moves otherwise).

**Loyalty detail**
- R-21 Loyalty is per company instance; the reserve shows each reserve piece's loyalty pip(s). Ransomed pieces (R-9) land in the original owner's reserve face-up with L − 1.
- R-22 A contract's loyalty grant is spread across mustered companies by the player (each company 0–3, total ≤ contract grant).
- R-23 Unpaid upkeep (R-16) applies before muster; a company reaching L = 0 while unpaid deserts (removed from roster) with probability 0 in battle, 1 at season end (deterministic, no RNG).

**Campaign detail**
- R-24 Seasons: spring, summer, autumn, winter; winter has no battles but recruitment and repairs. Campaign length 12 seasons.
- R-25 Employers' relations: accepting a contract against an employer lowers their regard by 2; regard ≤ −3 means that employer refuses you contracts for 4 seasons.
- R-26 Victory points: gold, battles won, cities held at campaign end (as a garrison contract). Score shown per category.
- R-27 Events (`events.json`) fire on season start from a deck seeded per campaign; attested event types (plague, papal interdict, truce) are labelled Attested as types, but their effects are Invented.

### A.2 Additional Invariants
- INV-6 Loyalty totals per contract ≤ grant (R-22).
- INV-7 A promoted piece in reserve is always stored unpromoted.
- INV-8 Bombard capture requires exactly one screen (property test over 100,000 random positions vs slow generator).
- INV-9 Campaign state after N seasons is a pure function of seed and choices.
- INV-10 Mate and banner detection agree with the slow generator on 500 reference positions.

### A.3 Complete Schemas and Sample Rows

```swift
struct CompanyInstance: Codable, Hashable, Sendable { var id: UUIDLike; var kind: String; var veteran: Bool; var loyalty: Int; var battles: Int; var originalOwner: PlayerID }
struct Roster: Codable, Sendable { var companies: [CompanyInstance]; var gold: Int; var regard: [String: Int] }
struct EmployerDef: Codable, Sendable { var id: String; var name: String; var livery: [String]; var pay: Int; var rivals: [String]; var label: HistoryLabel; var manifestKey: String? }
struct BattleDef: Codable, Sendable { var id: String; var setup: String; var special: [BattleSpecial]; var budget: Int; var objective: Objective }
enum BattleSpecial: String, Codable, Sendable { case riverRank5BlocksSlides, siegeWalls, fog, nightNoDropsFirst10 }
struct SeasonLog: Codable, Sendable { var season: Int; var contract: Contract?; var battle: String?; var result: BattleResult?; var events: [String] }
```

`UUIDLike` is a deterministic counter-based id (no `UUID()` in Core).

```json
{ "id": "co_0042", "kind": "crossbow", "veteran": true, "loyalty": 2, "battles": 5, "originalOwner": "p1" }
{ "id": "siena", "name": "Siena", "livery": ["#1C1C1C", "#F4EFE4"], "pay": 2, "rivals": ["florence"], "label": "Attested" }
{ "id": "night_raid", "setup": "lnkh1hknl/....", "special": ["nightNoDropsFirst10"], "budget": 36, "objective": "banner" }
{ "employer": "milan", "pay": 5, "loyaltyGrant": 6, "target": "verona", "seasons": 2 }
```

### A.4 Balance Tables and Sim Targets

| Parameter | Default | Range | Sim Target |
| --- | --- | --- | --- |
| Reserve value factor (eval) | 1.1 | 1.0–1.3 | — (AI only) |
| Loyalty ransom threshold | L ≥ 2 | 1–3 | 20–35% of captures are ransoms in campaign |
| Banner hold turns | 2 | 1–3 | Banner wins 15–30% of decisive games |
| Battle budget | 40 | 30–50 | Mustered armies 14–20 companies |
| Upkeep | 1/company/season | — | Players end 12 seasons with 0–30% of peak gold |
| Turn cap | 200 plies | — | < 2% of Captain-vs-Captain games hit cap |

Symmetric sims: Captain vs Captain 2,000 games on the standard setup: White 50–56%, draws ≤ 15%, median 90–140 plies.

### A.5 AI Design in Detail
- **Move generator:** bitboards (two `UInt64` + overflow `UInt32` per mask, or SIMD3<UInt32>), precomputed leap and step masks per piece face and side, slide attacks by loop (board is small); drops generated per reserve kind with pawn-file mask.
- **Search detail:** iterative deepening, aspiration ±50 centipawns, null-move pruning disabled when side has ≤ 2 non-pike pieces on board or is in check (zugzwang risk in drop games is low but captain-mate nets matter), LMR after 4 moves at depth ≥ 3, check extension +1 (max 3 per line).
- **Evaluation weights (initial, tuned in P4 by self-play SPSA over 20,000 games):** material, reserve × 1.1, captain safety (−25 per attacked adjacent square, +15 per defender), banner pressure (+30 per own piece attacking enemy banner square), loyalty factor (enemy pieces with L ≥ 2 counted at 0.6 for capture gain).
- **Campaign:** employer AIs choose contracts maximising regard-weighted utility; rival condottieri use a simple MCTS over season choices with 200 rollouts.

### A.6 Granular Task Breakdown

| ID | Task | Acceptance Criteria |
| --- | --- | --- |
| TC-P0.1 | HISTORY.md (condotte, liveries, San Romano) | Labels list complete |
| TC-P1.1 | Bitboards and move gen per face | Perft depth 1–4 on 10 positions (INV-2) |
| TC-P1.2 | Bombard and Engineer special moves (R-17, R-18) | INV-8; 20 fixtures |
| TC-P1.3 | Drops and restrictions (R-6, R-19) | 30 fixtures incl. pike-drop mate |
| TC-P1.4 | Promotion rules (R-3, R-20) | 20 fixtures |
| TC-P1.5 | Loyalty and ransom (R-9, R-21, R-22) | INV-5, INV-6 |
| TC-P1.6 | Check, mate, banner, repetition (R-7, R-8, R-11–R-13) | INV-10 |
| TC-P1.7 | Campaign core (R-14–R-16, R-23–R-27) | INV-9; 12-season replay test |
| TC-P2.1 | Board with livery flip animation | Snapshot tests |
| TC-P2.2 | Reserve tray with loyalty pips | Pips equal Core |
| TC-P2.3 | Move hints and threat overlay | Matches attack maps |
| TC-P3.1 | 6 employers, 10 battles, 12 events | Lint |
| TC-P3.2 | Tutorial: drops, loyalty, banner | UI tests |
| TC-P4.1 | Search and eval | Tier gaps ≥ 75%; Captain ≤ 1.0 s p95 |
| TC-P4.2 | SPSA tuning harness | Report in BALANCE.md |
| TC-P5.1 | Campaign map and season flow | 12-season playthrough UI test |

### A.7 Sharpened Gate Checks
- G1 adds: perft agreement with the slow generator to depth 4 on 10 positions; 20 shogi-derived drop fixtures.
- G3 adds: liveries (Attested) checked against HIST sources; any uncertain livery labelled Invented.
- G4 adds: Condottiero beats Captain ≥ 70% over 400 games.

### A.8 Additional Risks

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Draw-heavy play with drops | Low | Medium | Banner rule and turn cap | GLM |
| Livery accuracy disputes | Medium | Low | Label uncertain liveries Invented | GLM |
| Campaign length fatigue | Medium | Medium | 6-season short campaign option | GLM |

### A.9 Additional Open Questions (Defaults)
1. Should real condottieri (Hawkwood, Sforza) appear? Default: no; fictional captains, real names only in About text.
2. Allow hot-seat with reserve hidden? Default: no; reserves are public as in shogi.
3. Include Uccello-style art for menus? Default: original art inspired by, not copying, the panels.
