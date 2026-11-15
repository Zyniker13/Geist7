# 05 — Watered Stock Roadmap

> Float railroads, rig their share prices, run them for dividends, then dump the stock on a rival just before the trains rust.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 in full before starting. Depth pass (15 Nov 2026): Appendix A extends §4–§13 and wins where they differ. This roadmap adds only what is specific to Watered Stock.

Research: [`RESEARCH.md`](RESEARCH.md) (art direction, design lineage, cultural context, advisor institutions, verified glossary, and audio direction).

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 05 · `watered-stock` |
| Code prefix | `WS` (packages `WSCore`, `WSContent`, `WSAI`, `WSRender`, `WSAudio`, `WSPlatform`, `WSMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | 18xx-style railroad and stock-market game |
| Difficulty tier | Hardcore |
| Scope | Small team |
| Session length | 2–4 hours (async across days; a "short line" scenario at 60–90 minutes) |
| Renderer | SwiftUI for market, charter, and certificate panels; SpriteKit for the hex map |
| Players | 3–5 (solo vs AI fills seats); pass-and-play; async online (GameKit turn-based) |
| Simulation | Turn-based phases: private auction, stock rounds, operating rounds |
| Sourcing tier | `NONE` (an original fictional 1890s continent; HIST labels optional for era flavor) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** see above.
- **Summary:** An original 18xx design on a fictional map ("The Ferrous Coast", about 90 hexes). Players buy private companies by auction, then alternate stock rounds (buy or sell one share per turn, float corporations at a chosen par) and operating rounds (each corporation's president lays track, places tokens, runs trains for revenue, then pays dividends or withholds, and buys trains). Train phases advance as trains are bought; older trains rust. Route revenue is computed automatically and optimally, which removes the genre's worst arithmetic chore. A player goes bankrupt if a corporation must buy a train it cannot afford and the president's cash fails. The game ends on bank break or bankruptcy; most net worth wins.
- **Pillars:**
  1. **Arithmetic is the computer's job.** Routes, revenue, share prices, and net worth are always computed and shown.
  2. **Every rule is an 18xx rule.** Nothing simplified away that players of 1830 would miss; a curated subset of mechanics, each fully implemented.
  3. **Async first.** Games run over days with push notifications per turn; any game can be resumed at any point.
  4. **Readable money.** Every cash change has an audit line in the ledger.
- **Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Certificate paper `#F3ECD9`, banknote green `#2F5B45`, engraving ink `#1E2430`, gold leaf `#B8933B`, map land `#E7DCC0`, water `#9DB7C2`, track black `#222222`, corporation colors (8): `#8C1C13`, `#1F4E79`, `#2E6B30`, `#C58B00`, `#5B2C6F`, `#2B2B2B`, `#B35C1E`, `#4D7C8A`. |
| Shapes | Guilloche borders, engraved vignettes per corporation, standard 18xx tile shapes (yellow, green, brown, grey). |
| Typography | Engraved serif display (default: Baskerville, bundled license check in ADR) and SF Mono for ledgers. |
| Motion | Trains run along chosen routes with puffs; stock price token slides on the market. |
| Music | Ragtime piano loops (original compositions), quiet in operating rounds. |
| SFX | Ticker tape, stamp, coin clink, train whistle per train type, rust crumble. |
| Haptics | Stamp tick on share purchase; heavy thump on train rust. |

- **Inspirations:** 1830, 1846, and 18Chesapeake; 18xx.games and Board18 for async patterns; Dunn's analysis of 18xx route revenue algorithms.

## 2. Tech Stack Decision

Per `_CONVENTIONS.md` §2, plus:
- **Route solver:** exact optimal assignment of trains to routes by branch-and-bound over station-to-station paths, with a node-visit cap; integer revenue only.
- **Market:** 2D stock market grid (11 × 7) as data.
- **Async:** GameKit turn-based with full `GameState` in `matchData` (compressed `LZFSE`, ≤ 64 KB); fallback to action log if larger (ADR-0006).
- ADRs: ADR-0003 rules subset; ADR-0004 route solver; ADR-0005 money as `Int` (no Fixed needed); ADR-0006 match data size strategy.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/WSCore/Sources/WSCore/
  Map/      Hex.swift, Tile.swift, TileManifest.swift, TrackGraph.swift, Station.swift, Upgrade.swift
  Finance/  Bank.swift, Player.swift, Corporation.swift, Share.swift, Certificate.swift, StockMarket.swift, Ledger.swift
  Rounds/   PrivateAuction.swift, StockRound.swift, OperatingRound.swift, Phase.swift, TrainRoster.swift
  Routes/   RouteSolver.swift, Route.swift, Revenue.swift
  Engine/   GameState.swift, Action.swift, Event.swift, Reducer.swift, EndGame.swift, NetWorth.swift
Packages/WSContent/  MapDef.swift, TileSetDef.swift, CorporationDef.swift, PrivateDef.swift, TrainDef.swift, MarketDef.swift, ScenarioDef.swift
Packages/WSAI/       Bots/(Investor.swift, Operator.swift, Looter.swift), StockEval.swift, TrackPlanner.swift, TrainPolicy.swift
Packages/WSRender/   MapScene.swift, TileNode.swift, RouteOverlay.swift
Packages/WSMeta/     Scenarios.swift, Stats.swift, Tutorials.swift
Resources/Content/   maps.json, tiles.json, corporations.json, privates.json, trains.json, market.json, scenarios.json, balance.json, tutorial.json
```

## 4. Core Rules Specification

**Privates**
- R-1 Private companies are sold by the 1830-style "buy cheapest or bid" auction. Each private pays fixed income each OR and has a special ability (data).
- R-2 Privates close when phase 5 begins or when their ability is used, per data.

**Stock rounds**
- R-3 In turn order, each player may sell any number of shares (subject to R-6), then buy one share, or pass. Selling then buying the same corporation in one stock round is forbidden.
- R-4 Floating: the first purchase of a corporation's president certificate (20%) sets par from the par row; the corporation floats when 60% is sold; it receives 10× par from the bank.
- R-5 Certificate limit per player by player count (data); 60% cap per corporation per player unless price is in the brown zone.
- R-6 Selling drops price one row per share sold; shares cannot be sold in the first stock round; the bank pool cannot hold more than 50%.
- R-7 Presidency transfers to the player holding the most shares (ties keep the current president) when another player exceeds the president.
- R-8 Stock round ends after all pass consecutively. Priority deal goes to the player after the last to act.
- R-9 After a stock round, sold-out corporations move up one row.

**Operating rounds**
- R-10 Number of ORs per set depends on phase (1, 2, or 3).
- R-11 Corporations operate in share-price order (highest first; ties by arrival on the space).
- R-12 Operation: lay one tile or upgrade (legality: connects to the corporation's network, matches existing track, colour allowed by phase, terrain cost paid); place one station token (cost per data); run trains; pay dividends or withhold; buy trains.
- R-13 Runs: each train of size N runs a route visiting N stations (cities and towns), starting and ending at stations, not reusing track segments, containing ≥ 1 of the corporation's tokens, not passing through cities blocked by others' tokens. Multiple trains cannot share track. Revenue = sum of station values (phase-adjusted per tile colour).
- R-14 The route solver chooses the revenue-maximising legal assignment. The player may choose a different legal assignment (rarely matters); default is optimal.
- R-15 Dividends: full payout moves price right one column; withhold moves price left; revenue goes to shareholders by share percentage (bank-pool shares pay the corporation).
- R-16 Train purchases: from the bank (current type) or another corporation (agreed price ≥ 1). Each corporation has a train limit per phase.
- R-17 Mandatory train: a corporation with a route and no train at the end of its turn must buy one. If its treasury is short, the president pays the remainder from personal cash, selling shares if needed (but never selling the presidency of the corporation in trouble, as in 1830); if still short, the president is bankrupt.
- R-18 Phase changes occur on first purchase of a train type; on certain phases older trains rust (removed) per data; train limits drop and excess trains are discarded to the bank.

**End**
- R-19 Game ends when the bank breaks (complete the current OR set) or immediately on bankruptcy. Net worth = cash + share value at market. Highest wins; ties share.

**Invariants**
- INV-1 Money conservation: sum of all cash (bank, players, corporations) is constant except bank-break overflow accounted explicitly.
- INV-2 Share conservation: each corporation's shares total 100% across players, treasury (IPO), and pool.
- INV-3 Route solver result is a legal assignment and its revenue ≥ any assignment found by a randomized search of 10,000 samples (tested on 300 positions).
- INV-4 Replay determinism including AI choices.
- INV-5 Every cash change has a ledger line; ledger sums reconcile with balances.

## 5. Data Schemas and Content Tables

```swift
struct Corporation: Codable, Hashable, Sendable { var id: String; var par: Int?; var price: MarketCell?; var treasury: Int; var trains: [TrainID]; var tokensPlaced: [Hex]; var president: PlayerID?; var floated: Bool }
struct Tile: Codable, Hashable, Sendable { var id: String; var colour: TileColour; var paths: [PathSeg]; var stations: [StationDef]; var upgradesTo: [String] }
struct TrainDef: Codable, Sendable { var id: String; var size: Int; var cost: Int; var count: Int; var rustsOn: String?; var triggersPhase: Int? }
enum Action: Codable, Hashable { case bid(PrivateID, Int), buyPrivate(PrivateID), par(CorpID, Int), buyShare(CorpID, from: Source), sellShares(CorpID, Int), pass, layTile(Hex, TileID, rotation: Int), placeToken(Hex, slot: Int), runRoutes([RouteAssignment]), payout(Bool), buyTrain(TrainID, from: Seller, price: Int), discardTrain(TrainID) }
```

| Table | G3 | G5 | Sample row |
| --- | --- | --- | --- |
| `maps.json` | 1 (short line) | 2 (short line, full) | `{ "id": "ferrous_coast", "hexes": 92, "homes": {"FCR": "E5"}, "terrain": {"F9": "mountain:120"} }` |
| `tiles.json` | 46 tile defs | 64 | `{ "id": "57", "colour": "yellow", "paths": [[0,"c"],["c",3]], "stations": [{"type":"city","value":20,"slots":1}], "upgradesTo": ["14","15"] }` |
| `corporations.json` | 6 | 8 | `{ "id": "FCR", "name": "Ferrous Coast Railway", "tokens": 4, "home": "E5", "colour": "#8C1C13" }` |
| `privates.json` | 5 | 6 | `{ "id": "ferry", "cost": 40, "income": 10, "ability": "free_tile_on:water_hex" }` |
| `trains.json` | 6 types | 6 | `{ "id": "2", "size": 2, "cost": 80, "count": 6, "rustsOn": "4" }` |
| `scenarios.json` | 2 | 6 | `{ "id": "short_line", "map": "ferrous_coast_short", "bank": 6000, "players": [3,4] }` |

All names are invented; no real railroad names.

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| Bank size | 12,000 (full), 6,000 (short) | ±30% | `scenarios.json` |
| Cert limits by players | 3: 20, 4: 16, 5: 13 | — | `balance.json` |
| Par values | 67, 71, 76, 82, 90, 100 | — | `market.json` |
| Train counts and costs | data | — | `trains.json` |
| OR count per phase | 1, 2, 2, 3, 3, 3 | 1–3 | `balance.json` |

Targets (AI-only, 1,000 games per player count): game length 8–12 OR sets (full), 4–6 (short); bank break ends ≥ 70% of games (bankruptcy the rest); 4-player first-seat win rate 22–28%; median route solve < 20 ms, p99 < 200 ms on iPad (base).

## 7. AI Approach

- **Bots as data:** three personalities with weighted heuristics (Investor: safe dividends, Operator: builds network and runs big trains, Looter: floats, withholds, dumps trains and shares).
- **Stock decisions:** one-step lookahead of net-worth change over the next OR set using simulated operations (fast mode: each corporation runs its current solver revenue and buys trains by policy).
- **Track:** beam search (width 8) over legal tile lays maximising projected revenue next OR plus connectivity to targets.
- **Trains:** policy table (buy when rust threat or when the corporation can afford the next type; rush rust when holding competitors' presidencies is advantageous).
- **Tiers:** Clerk, Broker, Tycoon (all personalities), with time budgets 0.2 s, 0.8 s, 2.0 s per decision.

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7.
- WS-P0.1 ADR-0003 rules subset document listing every implemented rule with its 1830/1846 analogue.

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; ADR-0003 complete
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- WS-P1.1 Finance: bank, shares, market, ledger (R-3 to R-9, R-15, INV-1, INV-2, INV-5).
- WS-P1.2 Map and tiles: track graph, tile legality, upgrades (R-12).
- WS-P1.3 Route solver (R-13, R-14, INV-3) with 60 hand-built fixtures.
- WS-P1.4 Phases, trains, rusting, mandatory purchase, bankruptcy (R-16 to R-19).

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-19 tagged tests; INV-1…INV-5 across 2,000 random games
  [ ] Route solver fixtures pass; p99 < 200 ms
  [ ] WSCore coverage ≥ 90%; make sim N=1000 deterministic
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5.
- WS-P2.1 Short-line scenario playable: private auction, stock round panel (market grid, certificate stacks), OR flow with tile tray, route overlay, payout choice, and train buy.
- WS-P2.2 Ledger view; net-worth chart.
- WS-P2.3 Seats filled by Broker AI.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test completes a 3-player short-line game (2 AI) on iPad and Mac
  [ ] Ledger reconciles at every step
  [ ] Hardcore rules self-reviewed by GLM against ADR-0003, with the checklist in `docs/STATUS.md`
  [ ] `docs/SLICE_ASSESSMENT.md` written: self-assessment against the pillars, with every weakness turned into a P3 task (`_CONVENTIONS.md` §8.1)
Sign-off: GLM-SELF
```

### P3 Content and Systems
- WS-P3.1 Full map, tiles, corporations, privates (G3 counts); save and resume at any action.
- WS-P3.2 Tutorial: 6 interactive lessons (shares, par, OR, routes, rust, presidency dumping).
- WS-P3.3 Undo within the current player's turn (for local games); hotseat privacy screen.

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts met; lint clean; 1,000 full-game sims finish without stuck states
Sign-off: GLM-SELF
```

### P4 AI Opponents
- WS-P4.1 Personalities and tiers as data; track planner; train policy; `docs/BALANCE.md`.

```
GATE G4 — AI
Checks:
  [ ] Tycoon beats Clerk tables ≥ 60% win share in 4-player sims (vs 25% baseline)
  [ ] Decision budgets met at p95
  [ ] Targets from §6 met or ADR
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- WS-P5.1 G5 scenarios (variable privates, random corporation sets, short and full); stats; 20 achievements; HANDOFF.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Counts met; coverage thresholds; HANDOFF complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- WS-P6.1 Guilloche certificate generator (procedural rosettes, deterministic per corporation); engraved vignettes (commissioned).
- WS-P6.2 Ragtime soundtrack (commissioned, 6 pieces); SFX.

```
GATE G6 — Aesthetics
Checks:
  [ ] Snapshots approved; 60 fps map pan on a base iPad
Sign-off: GLM-SELF
```

### P7 Platform Features
- WS-P7.1 Async GameKit turn-based with ADR-0006; push on your turn; reminder after 24 h.
- WS-P7.2 Game Center achievements and leaderboards (highest net worth by scenario).
- WS-P7.3 Mac: full keyboard flow, multiple windows (map and market side by side); iPad Stage Manager.

```
GATE G7 — Platform
Checks:
  [ ] 4-device async game completes over simulated days; match data within limits
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- WS-P8.1 Corporations distinguished by colour, logo, and abbreviation; VoiceOver for market and ledger; tile lays via list alternative.
- WS-P8.2 Dynamic Type to XXL on panels.

```
GATE G8 — Polish
Checks:
  [ ] VoiceOver completes a short-line game; budgets met
Sign-off: GLM-SELF
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard tasks; recruit 18xx players for beta.

```
GATE G9 — Beta
Checks:
  [ ] Crash-free ≥ 99.5%; no rules-dispute bug open at S1/S2
Sign-off: GLM-SELF
GATE G10 — Release
Checks:
  [ ] Store assets; final CI green
Sign-off: GLM-SELF
```

## 9. Fragile Areas and Priorities

- **Fragile areas:** route solver edge cases (towns, blocked cities, loops), R-17 forced-sale ordering, presidency transfer with pool shares.
- **Priorities for P6–P10:** async match data size, keyboard flow; map balance and bot personalities.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Rules bugs anger experts | High | High | Fixture suite from ADR-0003; beta with 18xx players | GLM |
| Route solver too slow | Medium | High | Caps, caching, background thread, solver tests | GLM |
| Licensing confusion with existing 18xx titles | Low | High | Original map and names; mechanics only | GLM |
| Hardcore niche limits audience | High | Medium | Short-line scenario and tutorials | GLM |

## 11. Out of Scope

Licensed 18xx titles; real-time multiplayer; mergers and minor companies (post-launch candidate); map editor.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 2–3 |
| P1 | GLM | 14–20 |
| P2 | GLM | 10–14 |
| P3 | GLM | 7–10 |
| P4 | GLM | 8–12 |
| P5 | GLM | 4–6 |
| P6 | GLM | 8–12 |
| P7 | GLM | 7–10 |
| P8 | GLM | 5–7 |
| P9 | GLM | 6–9 |
| P10 | GLM | 2–3 |
| **Total** | | **73–106** |

## 13. Open Questions

1. Include mergers (1846-style or 1817-style) at launch? Default: no.
2. Online play with strangers (matchmaking) or friends only? Default: friends and Game Center invites only.

## Appendix A. Extended Specification (Depth Pass)

### A.1 Additional Rules

**Private auction (detail)**
- R-20 Privates are offered in ascending face value. On a turn a player may buy the cheapest unsold private at face value, place a bid (≥ face + 5, in multiples of 5) on any more expensive private, or pass. Bid money is committed and unavailable.
- R-21 When the cheapest private is bought, the next cheapest with bids is resolved: one bidder buys at their bid; several bidders auction it in ascending bids (minimum +5) among themselves only.
- R-22 If all players pass consecutively without buying, the cheapest private's price drops by 5; at 0 the next player in order must take it.

**Stock market detail**
- R-23 The market is a 2D grid (data). Price movement: dividend paid ≥ price → right one column (up-right at the edge); withhold → left; each share sold → down one row; sold out at the end of a stock round → up one row. Ledge cells stop movement (data flags).
- R-24 Ties on the same market cell operate in the order they arrived (stack order, top first).
- R-25 Colour zones: yellow (shares don't count toward the certificate limit), orange (60% cap lifted), brown (both). Exact zones in `market.json`.
- R-26 The president's certificate (20%) can never be sold to the bank pool; if a sale would transfer presidency, the new president swaps two 10% shares for the president's certificate.

**Track and tokens**
- R-27 Tile lay costs: plain 0, river 40, mountain 80/120 (data); terrain is paid once on the first lay.
- R-28 Upgrades must preserve all existing track connections (path superset under any rotation) and city station counts never decrease.
- R-29 Token costs: home token free, second 40, third onward 100; a token requires a route from an existing token of that corporation.
- R-30 Tile supply is finite (manifest counts); when a tile id is exhausted it cannot be laid.

**Trains and phases**
- R-31 Phase table (data) defines: train limit per corporation, tile colours allowed, OR count, privates close, and which trains rust. Default: 2 (limit 4, yellow), 3 (4, green), 4 (3, green, 2s rust), 5 (2, brown, privates close, 3s rust), 6 (2, brown, 4s rust), D (2, grey).
- R-32 Diesel (D) trains may be bought by trading in a 4, 5, or 6 train for a discount (data).
- R-33 Bank break: when the bank cannot pay, record shortfall; finish the current OR set; paying continues from an "overflow" ledger line.

**Endgame and bankruptcy**
- R-34 Bankruptcy (R-17) ends the game immediately; remaining players compare net worth. The bankrupt player's shares go to the pool and their corporation keeps operating if another player can be president, otherwise it is closed.
- R-35 Corporations reaching the top-right market cell end the game after the current OR set (optional rule, scenario flag).

### A.2 Additional Invariants
- INV-6 Market positions are always valid cells; stack order is a permutation of corporations on that cell.
- INV-7 Tile counts (laid + supply) equal manifest totals.
- INV-8 Every laid tile is reachable for its owning corporation at the time of laying (audit replay).
- INV-9 Presidency always belongs to the holder of the president's certificate, and that holder has ≥ the share percentage of every other player.
- INV-10 Route solver output is invariant to train ordering in input (same total revenue).

### A.3 Complete Schemas and Sample Rows

```swift
struct MarketDef: Codable, Sendable { var rows: [[MarketCellDef?]]; var parRow: [Int] }
struct MarketCellDef: Codable, Sendable { var price: Int; var zone: Zone; var ledge: Bool; var endGame: Bool }
struct PrivateDef: Codable, Sendable { var id: String; var name: String; var face: Int; var income: Int; var ability: AbilityDef; var closesOnPhase: Int }
enum AbilityDef: Codable, Sendable { case freeTile(hex: String), terrainDiscount(kind: String, amount: Int), extraToken(hex: String), shareOf(corp: String, percent: Int), blocksHex(String) }
struct PhaseDef: Codable, Sendable { var id: String; var trainLimit: Int; var tiles: [TileColour]; var orCount: Int; var rusts: [String]; var closesPrivates: Bool }
struct ScenarioDef: Codable, Sendable { var id: String; var map: String; var bank: Int; var players: ClosedRange<Int>; var corporations: [String]; var privates: [String]; var certLimits: [Int: Int]; var startingCash: [Int: Int]; var flags: [String: Bool] }
struct LedgerLine: Codable, Hashable, Sendable { var seq: Int; var from: Account; var to: Account; var amount: Int; var reason: String }
```

```json
{ "id": "ferry", "name": "Grey Harbour Ferry", "face": 40, "income": 10, "ability": {"freeTile": {"hex": "J4"}}, "closesOnPhase": 5 }
{ "id": "4", "trainLimit": 3, "tiles": ["yellow", "green"], "orCount": 2, "rusts": ["2"], "closesPrivates": false }
{ "price": 100, "zone": "white", "ledge": false, "endGame": false }
{ "id": "full_ferrous", "map": "ferrous_coast", "bank": 12000, "players": [3, 5], "corporations": ["FCR","LVR","NSL","CBR","PRR2","MWR"], "certLimits": {"3": 20, "4": 16, "5": 13}, "startingCash": {"3": 800, "4": 600, "5": 480} }
{ "seq": 1182, "from": "bank", "to": "player:2", "amount": 140, "reason": "dividend FCR OR4.1 (20%)" }
```

### A.4 Balance Tables and Sim Targets

| Parameter | Default | Range | Sim Target |
| --- | --- | --- | --- |
| Bank (full) | 12,000 | 9,000–15,000 | Bank breaks in 8–12 OR sets |
| Starting cash (4p) | 600 | 500–700 | 3–5 corporations float in SR1–SR2 |
| 2-train count/cost | 6 / 80 | 5–7 / 70–100 | 2s rust after 2–4 ORs of use |
| 4-train cost | 300 | 260–340 | Forced-buy bankruptcies in 5–15% of games |
| Token costs | 0/40/100 | — | Average 2.5–3.5 tokens per corporation |
| Mountain cost | 80/120 | 60–160 | Mountain hexes developed by game end 40–70% |
| Private incomes | 5–25 | — | Private auction prices 0.9–1.3× face |

Sim protocol: 1,000 games per player count (3, 4, 5) with mixed personality seats; report win share by seat and personality, OR sets, end condition, rust events, and bankruptcies; plus a route-solver timing histogram.

### A.5 AI Design in Detail
- **State features:** for each corporation: treasury, trains, token network revenue potential (solver with a hypothetical next train), share distribution, price, and stack position.
- **Stock round policy:** enumerate candidate actions (each legal buy, each legal sell batch up to 3 shares, pass). Score each by simulating to the end of the next OR set with fast heuristics (corporations run current optimal revenue; payout policy by president personality; trains bought when affordable). Personalities weight: Investor (dividend income ×1.3), Operator (presidencies ×1.4), Looter (price drops of rival presidencies ×1.5, dumping value).
- **Dumping logic:** Looter evaluates selling to transfer presidency of a trainless corporation (R-26 compatible) when the corporation faces a forced buy.
- **Operating round:** tile lay by beam search (width 8, depth 2 ORs) maximising revenue of best route set plus a connectivity bonus to off-board hexes; token placement blocks rivals when the blocked revenue ≥ 20; payout when the corporation can still afford the next train with withheld funds by the next phase, otherwise withhold.
- **Train policy table:** buy the current train if the corporation has none (forced) or if buying triggers rust that hurts rival presidencies more than self (Looter, Operator); avoid triggering rust otherwise.
- **Time budgets:** Clerk 0.2 s, Broker 0.8 s, Tycoon 2.0 s per decision; background computation while the human acts.

### A.6 Granular Task Breakdown

| ID | Task | Acceptance Criteria |
| --- | --- | --- |
| WS-P0.1 | ADR-0003 rules subset with 1830/1846 analogues | Every R-n listed with analogue or "original" |
| WS-P0.2 | Money and ledger types | INV-1 and INV-5 property tests scaffolded |
| WS-P1.1 | Private auction (R-1, R-2, R-20–R-22) | 25 fixtures incl. price drop to 0 |
| WS-P1.2 | Stock rounds (R-3–R-9, R-23–R-26) | 50 fixtures incl. presidency swaps |
| WS-P1.3 | Market movement and zones | INV-6; 30 movement fixtures |
| WS-P1.4 | Track graph and tile legality (R-12, R-27, R-28, R-30) | 60 fixtures; INV-7 |
| WS-P1.5 | Tokens (R-29) | 15 fixtures |
| WS-P1.6 | Route solver (R-13, R-14) | 60 fixtures; INV-3, INV-10; p99 < 200 ms |
| WS-P1.7 | Trains, phases, rust, diesel trade-in (R-16, R-18, R-31, R-32) | 30 fixtures |
| WS-P1.8 | Forced buy and bankruptcy (R-17, R-34) | 20 fixtures |
| WS-P1.9 | End conditions (R-19, R-33, R-35) | 10 fixtures |
| WS-P2.1 | Market grid view and certificate stacks | Snapshot tests; values match Core |
| WS-P2.2 | Map scene, tile tray, rotation preview, legality highlight | Only legal rotations shown |
| WS-P2.3 | Route overlay and revenue panel | Overlay equals solver result |
| WS-P2.4 | Ledger and net-worth chart | Reconciles each action |
| WS-P3.1 | Full map, tiles, corporations, privates | Lint clean |
| WS-P3.2 | Six tutorials | UI tests complete each |
| WS-P4.1 | Bot personalities and tiers | Tier targets met |
| WS-P4.2 | Beam track planner | ≤ 800 ms p95 |
| WS-P5.1 | Variable privates and corporation sets | 6 scenarios pass sims |

### A.7 Sharpened Gate Checks
- G1 adds: an expert-reviewed list of 20 "known 18xx gotchas" (e.g., selling in SR1, presidency swap with pool limit, train limit overflow) each with a passing test.
- G2 adds: a scripted bot-vs-bot short-line game and the 20 gotcha tests run with zero S1/S2 rules bugs.
- G4 adds: no bot strategy wins > 40% in 4-player all-personality sims.
- G5 adds: save files from G3 load in G5 builds (migration test).

### A.8 Additional Risks

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Async games stall | High | Medium | Reminders, auto-pass timers (opt-in), bot takeover | GLM |
| Ledger UI overwhelms | Medium | Medium | Filter by player/corporation | GLM |
| Route solver worst cases | Medium | High | Node caps and solver timeouts with best-so-far plus ADR | GLM |

### A.9 Additional Open Questions (Defaults)
1. Offer an "explain my net worth" breakdown? Default: yes.
2. Allow undo in async games by unanimous consent? Default: no.
3. Include a 2-player variant? Default: post-launch.
