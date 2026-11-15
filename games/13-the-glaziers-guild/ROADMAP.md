# 13 — The Glaziers' Guild Roadmap

> Bid for coloured glass at the guild auction, then fit it into a cathedral window, where every lead line must hold and every long straight seam is a crack waiting to happen.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 in full before starting. Depth pass (15 Nov 2026): Appendix A extends §4–§13 and wins where they differ. This roadmap adds only what is specific to The Glaziers' Guild.

Research: [`RESEARCH.md`](RESEARCH.md) (art direction, design lineage, cultural context, advisor institutions, verified glossary, and audio direction).

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 13 · `the-glaziers-guild` |
| Code prefix | `GG` (packages `GGCore`, `GGContent`, `GGAI`, `GGRender`, `GGAudio`, `GGPlatform`, `GGMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Auction plus polyomino-placement euro game |
| Difficulty tier | Deep |
| Scope | Small team |
| Session length | 40–70 minutes |
| Renderer | SpriteKit with Metal light-transmission shader for glass |
| Players | 2–4 (AI fills seats); pass-and-play with hidden sealed bids; async online |
| Simulation | Turn-based, imperfect information (sealed bids), seeded lot draws |
| Sourcing tier | `HISTORICAL` (13th-century French Gothic glazing workshops; Theophilus) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** see above.
- **Summary:** Each player is a master glazier commissioned to fill a lancet window (a grid of about 8 × 16 cells inside a pointed-arch outline with stone tracery cells that cannot be filled). Each round, the guild offers lots of glass pieces (polyomino shapes 1–5 cells, each in a colour: ruby, cobalt, emerald, gold, murrey, white). Lots are sold by alternating auction formats: open ascending (English), sealed first-price, or Dutch descending (format shown per lot). Players place won pieces in their window. Scoring at the end: colour panels (connected same-colour regions) score by size and by the commission's iconographic requirements (for example "a blue field of at least 12 cells in the upper third"); leading: every boundary between pieces is a lead line, and any straight lead line longer than the "hinge limit" (default 5 cells) fails inspection and costs points (as long straight leads are weak). Unfilled cells cost points. The guild treasury and reputation tracks complete the economy: money pays for glass and is earned by completed commissions mid-game (2 windows per game: a small and a large).
- **Pillars:**
  1. **Auctions with personality.** Three formats and AI bidders with distinct, readable styles.
  2. **Spatial craft.** Placement is a satisfying puzzle with physical logic (weak seams).
  3. **Light as reward.** Finished windows glow with transmitted light; players can rotate the sun.
  4. **Honest economics.** Every bid's expected value is explainable in the hint panel.
- **Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Ruby `#9B1B30`, cobalt `#1F3C88`, emerald `#1E6B4A`, silver-stain gold `#D9A520`, murrey `#6B2D5C`, white glass `#E8E6DA`, lead `#3A3A3C`, stone `#B9AE9A`, workshop wood `#5A4632`. |
| Shapes | Polyomino glass with slightly irregular edges and seeds (bubbles); arched windows with trefoil and quatrefoil tracery. |
| Typography | Textura-inspired display (default: a licensed blackletter, used sparingly) and SF Pro. |
| Motion | Glass pieces lower onto the light table; leading draws as soldered lines; sunrise sweep on scoring. |
| Music | Organum-inspired vocal and organ textures (original compositions). |
| SFX | Glass clink, grozing iron nibble, solder hiss, auctioneer gavel. |
| Haptics | Clink on placement; buzz when a hinge exceeds the limit. |

- **Inspirations:** Theophilus, "De diversis artibus" (c. 1120s); Chartres Cathedral windows; Brown and O'Connor, "Glass-painters"; Patchwork and Sagrada for polyomino and colour drafting; Klemperer on auction theory.

## 2. Tech Stack Decision

Per `_CONVENTIONS.md` §2, plus:
- **Information boundary:** `PlayerView` projection hides sealed bids until reveal (like Eight Suits); AI receives only `PlayerView`.
- **Lead analysis:** lead lines computed from cell-edge boundaries between differently-owned pieces; straight runs measured along grid lines.
- **Glass shader:** Metal fragment shader using colour + seed noise + light direction (render only).
- ADRs: ADR-0003 auction formats; ADR-0004 hinge rule; ADR-0005 PlayerView boundary.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/GGCore/Sources/GGCore/
  Window/    WindowGrid.swift, Tracery.swift, Piece.swift, Polyomino.swift, Placement.swift, Leading.swift, Panels.swift
  Auction/   Lot.swift, OpenAuction.swift, SealedAuction.swift, DutchAuction.swift, Treasury.swift
  Guild/     Commission.swift, Reputation.swift, Requirement.swift
  Engine/    GameState.swift, PlayerView.swift, Action.swift, Event.swift, Reducer.swift, Score.swift
Packages/GGContent/  PieceDef.swift, LotDeckDef.swift, CommissionDef.swift, WindowDef.swift, BidderDef.swift, Loader.swift
Packages/GGAI/       Valuation.swift, Bidders/(Cautious.swift, Shark.swift, Collector.swift, Spoiler.swift), PlacementSearch.swift
Packages/GGRender/   WorkshopScene.swift, GlassShader.metal, LeadRenderer.swift, AuctionView.swift
Packages/GGMeta/     Campaign.swift (Guild career), Stats.swift
Resources/Content/   pieces.json, lots.json, commissions.json, windows.json, bidders.json, balance.json, tutorial.json
```

## 4. Core Rules Specification

**Setup**
- R-1 Each player receives a small window (6 × 10) and later a large window (8 × 16) from `windows.json`; tracery cells blocked. Starting money 20, reputation 0.
- R-2 Each round reveals `playerCount + 1` lots, each with format (open, sealed, Dutch) and 1–3 pieces.

**Auctions**
- R-3 Open: bidding in turn order from the round's lead player; each bid must exceed the last by ≥ 1; passing is permanent for that lot; the last bidder wins and pays.
- R-4 Sealed: all players submit a hidden bid (0 allowed); highest wins and pays their bid; ties broken by reputation, then turn order.
- R-5 Dutch: price starts at the lot's list price and drops by 1 per tick; the first player to claim pays the current price; in turn-based async the Dutch auction is resolved by each player privately submitting a claim price (equivalent to sealed bid with a twist: the winner pays their claim, ties by reputation).
- R-6 Unsold lots go to the "scrap bin" and can be taken for 1 by the player with lowest money at round end.
- R-7 Money cannot go negative; a player may not bid more than their money.

**Placement**
- R-8 Won pieces must be placed immediately or put in the workbench (max 2 pieces). Pieces may rotate and flip. Placement must be inside the window, not over tracery or other glass.
- R-9 A window is complete when all non-tracery cells are filled or the player declares completion (unfilled cells penalised).

**Scoring a window (on completion)**
- R-10 Panels: each connected same-colour region of size n scores `panelScore(n)` (table, convex: 1, 3, 6, 10, 15 …, capped).
- R-11 Requirements: commission requirements (data) give bonuses if met (for example "cobalt ≥ 12 cells in upper third", "ruby frame around border").
- R-12 Hinges: compute every maximal straight lead line along grid lines (edges between distinct pieces; the window boundary is excluded). Each line with length > hingeLimit costs `hingePenalty × (length − hingeLimit)`.
- R-13 Empty cells: −2 each.
- R-14 Reputation: + window score / 5; money reward = commission fee.

**End**
- R-15 Game ends after both windows are completed by all players or after `maxRounds`. Final score = window scores + reputation + money / 4.

**Invariants**
- INV-1 Money conservation (bank and players), except commission fees from the bank recorded in the ledger.
- INV-2 Piece conservation (lots, workbench, windows, scrap).
- INV-3 PlayerView never contains other players' unrevealed sealed bids (property test).
- INV-4 Replay determinism.
- INV-5 Lead analysis recomputed equals incremental.

## 5. Data Schemas and Content Tables

```swift
struct PieceDef: Codable, Sendable { var id: String; var cells: [GridOffset]; var colour: GlassColour; var listPrice: Int }
struct CommissionDef: Codable, Sendable { var id: String; var window: String; var fee: Int; var requirements: [Requirement]; var label: HistoryLabel }
struct BidderDef: Codable, Sendable { var id: String; var name: String; var valuationNoise: Int; var shading: Int /* percent below value */; var aggression: Int; var colourBias: [GlassColour: Int] }
enum Action: Codable, Hashable { case bid(Int), passLot, sealedBid(Int), dutchClaim(Int), place(PieceRef, GridPos, rotation: Int, flipped: Bool), stash(PieceRef), declareComplete, takeScrap }
```

| Table | G3 | G5 | Sample row |
| --- | --- | --- | --- |
| `pieces.json` | 40 | 80 | `{ "id": "ruby_L4", "cells": [[0,0],[0,1],[0,2],[1,2]], "colour": "ruby", "listPrice": 6 }` |
| `commissions.json` | 8 | 24 | `{ "id": "chartres_blue", "window": "lancet_large", "fee": 18, "requirements": [{"colour":"cobalt","min":12,"zone":"upper_third"}], "label": "Attested" }` |
| `windows.json` | 4 | 10 | `{ "id": "lancet_large", "w": 8, "h": 16, "tracery": "<mask>" }` |
| `bidders.json` | 4 | 8 | `{ "id": "shark", "name": "Master Renaud", "shading": 5, "aggression": 8, "valuationNoise": 2 }` |

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| Starting money | 20 | 12–30 | `balance.json` |
| `hingeLimit` | 5 | 4–7 | `balance.json` |
| `hingePenalty` | 2 | 1–3 | `balance.json` |
| Panel score cap | size 10 | 6–14 | `balance.json` |
| Format mix | open 40%, sealed 40%, Dutch 20% | — | `lots.json` |

Targets (4-player AI sims, 2,000 games): seat win rates 22–28%; average winning-bid / estimated value 0.7–1.0; hinge penalties occur in 40–70% of windows; game length 10–14 rounds.

## 7. AI Approach

- **Valuation:** for each lot, estimate marginal score by placement search (best placement among top 50 by heuristic: panel growth, requirement progress, hinge risk) plus option value.
- **Bidding:** personality applies shading and noise; sealed bids use a Bayesian estimate of opponents' values (from their public windows) to optimise expected surplus (discretised).
- **Tiers:** Apprentice, Journeyman, Master (deeper placement search, opponent modelling).

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7, HIST0.1 (Attested: Theophilus methods, lead cames, colour palette of Chartres, guild organisation; Invented: auction formats in guild context, scoring).

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; HIST0.1 complete
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- GG-P1.1 Window grid, polyomino placement, lead analysis, panels, scoring (R-8 to R-14).
- GG-P1.2 Auctions (R-2 to R-7) with PlayerView (INV-3).
- GG-P1.3 Game flow and end (R-1, R-15).

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-15 tests; INV-1…INV-5
  [ ] GGCore coverage ≥ 90%; make sim N=1000 deterministic
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5.
- GG-P2.1 Auction view (all formats; sealed bid entry with privacy shield for pass-and-play); workshop light table with drag-rotate-flip placement; hinge warning overlay.
- GG-P2.2 Journeyman bidders.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test completes a 2-player game vs AI on iPad and Mac with all three formats
  [ ] Hinge overlay matches Core lead analysis on 300 random windows
  [ ] `docs/SLICE_ASSESSMENT.md` written: self-assessment against the pillars, with every weakness turned into a P3 task (`_CONVENTIONS.md` §8.1)
Sign-off: GLM-SELF
```

### P3 Content and Systems
- GG-P3.1 G3 content; HIST3.1 labels; commissions with flavor text.
- GG-P3.2 Tutorial (5 lessons); pass-and-play sealed bids.

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts met; lint clean; 1,000 4-player sims complete
Sign-off: GLM-SELF
```

### P4 AI Opponents
- GG-P4.1 Personalities; tiers; `docs/BALANCE.md`.

```
GATE G4 — AI
Checks:
  [ ] Master beats Apprentice tables ≥ 45% win share in 4-player; p95 ≤ 800 ms per decision
  [ ] Targets in §6 met or ADR
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- GG-P5.1 G5 counts; Guild career (series of commissions with rising requirements); 20 achievements; HANDOFF.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Counts met; HANDOFF complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- GG-P6.1 Glass shader with sun rotation; finished-window gallery; HIST6.1.
- GG-P6.2 Music and SFX.

```
GATE G6 — Aesthetics
Checks:
  [ ] Snapshots approved; 120 fps workshop on iPad Pro; HIST6.1 clean
Sign-off: GLM-SELF
```

### P7 Platform Features
- GG-P7.1 Async with sealed bids via GameKit (bids encrypted in match data per player, revealed at round end; ADR); Game Center; iCloud.

```
GATE G7 — Platform
Checks:
  [ ] Async 4-player game completes; sealed bids not readable by other clients (test)
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- GG-P8.1 Colour-independent glass identification (pattern overlays and names); VoiceOver placement grid; bid stepper.

```
GATE G8 — Polish
Checks:
  [ ] VoiceOver completes a game; color-blind modes reviewed
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

- **Fragile areas:** sealed-bid privacy in async (encryption key handling in ADR), lead analysis edge cases near tracery.
- **Priorities for P6–P10:** glass shader, async privacy; auction balance and bidder personalities.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Auction AI exploitable | Medium | High | Opponent modelling, noise | GLM |
| Async sealed bids leak | Low | High | Per-player encryption, tests | GLM |
| Colour-dependent gameplay | High | High | Patterns and names | GLM |

## 11. Out of Scope

Real-time Dutch clock in online play; glass painting mini-game; rose windows (post-launch).

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 2 |
| P1 | GLM | 7–10 |
| P2 | GLM | 6–8 |
| P3 | GLM | 5–7 |
| P4 | GLM | 6–8 |
| P5 | GLM | 3–5 |
| P6 | GLM | 8–11 |
| P7 | GLM | 5–7 |
| P8 | GLM | 3–5 |
| P9 | GLM | 4–6 |
| P10 | GLM | 2–3 |
| **Total** | | **51–72** |

## 13. Open Questions

1. Include rose windows (circular grids) at launch? Default: post-launch.

## 14. Sourcing Notes

- **Sources:** Theophilus, "On Divers Arts" (Hawthorne and Smith translation); Corpus Vitrearum publications; Chartres Cathedral window studies.
- **Historical labels:** the hinge rule is a gameplay abstraction of Attested structural concerns (glaziers used saddle bars and avoided long straight leads); auction formats are Invented.

## Appendix A. Extended Specification (Depth Pass)

### A.1 Additional Rules

**Round structure**
- R-16 Round order: (1) reveal lots; (2) resolve lots in list order, each by its format; (3) placement window (all players place simultaneously in async; in live play, in turn order); (4) scrap; (5) completion checks; (6) lead player passes left.
- R-17 Lot list price = Σ piece list prices; Dutch auctions start at list price + 2 and floor at 1.
- R-18 A player may win at most 2 lots per round (prevents a cash-rich sweep); after winning 2, they automatically pass.
- R-19 Workbench overflow: a third held piece must be discarded to scrap immediately (no refund).

**Placement detail**
- R-20 Pieces must align to the grid; flips and 90° rotations allowed (8 orientations).
- R-21 Saddle bars: each window has fixed horizontal saddle-bar rows (data, e.g., every 4th row boundary). Lead lines along a saddle-bar row do not count toward hinge penalties (bars support the glass, as in medieval practice).
- R-22 Tracery cells are not glass; their edges count as boundary for lead analysis.
- R-23 Declaring completion early is allowed only after ≥ 75% of non-tracery cells are filled.

**Scoring detail**
- R-24 Panel score table (default): size 1:1, 2:3, 3:6, 4:10, 5:15, 6–8:18, 9–12:22, ≥ 13:25 (cap discourages one-colour floods).
- R-25 Colour balance: a window using fewer than 3 colours scores −5; using all 6 scores +3.
- R-26 Hinge limit is per window (small 4, large 6); penalty 2 per cell over the limit per line.
- R-27 Commission requirements are checked against the final window; each unmet requirement loses half its bonus (rounded down) rather than all, if at least half of the target was met.

**Market events**
- R-28 Between windows, an event (data) may change prices: "cobalt shortage" (+2 list price to cobalt), "glasshouse fire" (one colour removed for a round), "bishop's visit" (bonus reputation for completed requirements). Event types are Invented.

### A.2 Additional Invariants
- INV-6 No player wins more than 2 lots per round (R-18).
- INV-7 Hinge penalty computation ignores saddle-bar rows (fixture and property test).
- INV-8 Panel scores computed by union-find equal flood-fill results on 10,000 random windows.
- INV-9 Sealed and Dutch claims are committed via hashed commitments in async play (hash revealed at resolution).

### A.3 Complete Schemas and Sample Rows

```swift
struct WindowDef: Codable, Sendable { var id: String; var w: Int; var h: Int; var tracery: [String]; var saddleRows: [Int]; var hingeLimit: Int; var label: HistoryLabel }
enum Requirement: Codable, Sendable { case colourMin(GlassColour, Int, zone: Zone), frame(GlassColour), panelMin(GlassColour, size: Int), symmetry(axis: Axis) }
enum Zone: String, Codable, Sendable { case any, upperThird, middleThird, lowerThird, border, centreColumn }
struct LotDef: Codable, Sendable { var format: AuctionFormat; var pieces: [String] }
struct RoundLog: Codable, Sendable { var round: Int; var lots: [LotResult]; var placements: [PlayerID: [PlacementRecord]]; var events: [String] }
struct Commitment: Codable, Hashable, Sendable { var player: PlayerID; var hash: String; var lot: Int }
```

```json
{ "id": "lancet_large", "w": 8, "h": 16, "tracery": ["########", "###..###", "##....##"], "saddleRows": [4, 8, 12], "hingeLimit": 6, "label": "Invented" }
{ "id": "rose_frame", "window": "lancet_small", "fee": 12, "requirements": [{"frame": "ruby"}, {"colourMin": ["gold", 4, "centreColumn"]}], "label": "Invented" }
{ "format": "sealed", "pieces": ["cobalt_T4", "white_I2"] }
{ "id": "cobalt_shortage", "effect": {"priceDelta": {"cobalt": 2}}, "label": "Invented" }
```

### A.4 Balance Tables and Sim Targets

| Parameter | Default | Range | Sim Target |
| --- | --- | --- | --- |
| Starting money | 20 | 15–30 | Average money at end 5–15 |
| Lots per round | players + 1 | — | 10–20% of lots unsold (scrap) |
| Max lots won per round | 2 | 1–3 | No player wins > 40% of all lots |
| Hinge limit (small/large) | 4/6 | 3–8 | Hinge penalties 5–15% of window score |
| Panel cap | 25 | 18–30 | Largest panel median 8–12 cells |
| Commission fee | 12–18 | — | Fees 20–35% of final score |

Auction-format sim check: across 3,000 4-player bot games, average price/value ratio per format: open 0.85–1.0, sealed 0.75–0.95, Dutch 0.8–1.0 (value = Master's marginal estimate).

### A.5 AI Design in Detail
- **Marginal value:** for each lot, run placement search (beam width 12 over the next 2 pieces held) for the current window; value = Δ expected window score + 0.3 × flexibility (number of legal placements for the most common shape classes remaining).
- **Open auctions:** bid up to `value × (1 − shading)` with integer increments; jump-bid to deter when value − current ≥ 6 (aggression ≥ 6).
- **Sealed:** model each opponent's value as their marginal value (computed from their public window) + noise σ = valuationNoise; choose bid b maximising `(v − b) · P(all opponents < b)` by discrete search 0..money.
- **Dutch:** claim when price ≤ `value × (1 − shading)` or when P(opponent claims before next tick) × surplus loss is larger than one tick of savings.
- **Placement:** exact search for ≤ 2 pieces, greedy beyond; tie-break by fewer long leads.

### A.6 Granular Task Breakdown

| ID | Task | Acceptance Criteria |
| --- | --- | --- |
| GG-P0.1 | HISTORY.md (Theophilus, saddle bars, Chartres blue) | Labels complete |
| GG-P1.1 | Lots, round flow, lead player (R-2, R-16, R-17) | 20 fixtures |
| GG-P1.2 | Open, sealed, Dutch auctions (R-3–R-5, R-18) | INV-6; 30 fixtures |
| GG-P1.3 | Commitments for async (INV-9) | Tamper test fails verification |
| GG-P1.4 | Placement and workbench (R-8, R-19, R-20, R-23) | INV-2 |
| GG-P1.5 | Lead analysis with saddle bars (R-12, R-21, R-22, R-26) | INV-5, INV-7 |
| GG-P1.6 | Panel scoring, colour balance, requirements (R-10, R-11, R-24, R-25, R-27) | INV-8 |
| GG-P1.7 | Events (R-28) and end (R-15) | 10 fixtures |
| GG-P2.1 | Window renderer with lead lines and light transmission shader | 60 fps; leads drawn exactly where Core says |
| GG-P2.2 | Auction UIs for three formats | UI tests per format |
| GG-P2.3 | Hinge warning overlay | Shows lines over limit before commit |
| GG-P3.1 | 8 commissions, 4 windows, 40 pieces | Lint |
| GG-P4.1 | Bidder AI and personalities | Format price ratios in range |
| GG-P5.1 | Async with commitments | End-to-end test on 2 devices |

### A.7 Sharpened Gate Checks
- G1 adds: INV-3 and INV-9 tests; 1,000 random windows score identically by two independent scorers.
- G3 adds: every commission labelled; "Attested" only where HISTORY.md cites a source.
- G4 adds: Master beats Journeyman ≥ 70% in 3-player games.

### A.8 Additional Risks

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Sealed bidding feels random | Medium | Medium | Post-auction reveal of all bids and values | GLM |
| Window art too close to real cathedral glass | Low | Medium | Original designs; reference only | GLM |
| Religious imagery expectations | Medium | Medium | Abstract colour-field windows; no saints or scenes | GLM |

### A.9 Additional Open Questions (Defaults)
1. Include figurative panels? Default: no; abstract and grisaille-inspired only.
2. Rename "chartres_blue" commission? Default: "deep blue" with Chartres mentioned only in About.
3. Real-time Dutch clock in live local play? Default: yes, 1 tick per second.
