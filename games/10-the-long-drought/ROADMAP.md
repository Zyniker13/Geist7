# 10 — The Long Drought Roadmap

> The Bronze Age is ending. Four factions scramble as the rains fail, the palaces falter, and the sea brings raiders, in a card-driven insurgency game for one to four players.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 in full before starting. Depth pass (15 Nov 2026): Appendix A extends §4–§13 and wins where they differ. This roadmap adds only what is specific to The Long Drought.

Research: [`RESEARCH.md`](RESEARCH.md) (art direction, design lineage, cultural context, advisor institutions, verified glossary, and audio direction).

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 10 · `the-long-drought` |
| Code prefix | `LD` (packages `LDCore`, `LDContent`, `LDAI`, `LDRender`, `LDAudio`, `LDPlatform`, `LDMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | COIN-style card-assisted asymmetric wargame |
| Difficulty tier | Hardcore |
| Scope | Small team |
| Session length | 90–180 minutes (short scenario 45–60) |
| Renderer | SpriteKit map with SwiftUI panels (cards, faction mats, flowcharts) |
| Players | 1–4 humans; empty factions run by flowchart bots; pass-and-play; async online |
| Simulation | Turn-based, card-driven, stochastic (seeded deck) |
| Sourcing tier | `HISTORICAL` (Late Bronze Age Aegean and Eastern Mediterranean, c. 1200 BCE) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** see above.
- **Summary:** A COIN-series-inspired design (original rules and content). The map is about 24 regions of a fictionalised Aegean basin: palaces, farmland, hills, and coasts. Four factions with asymmetric operations and special activities: the **Palace** (redistributive economy, scribes, chariots; wants to keep control and stores), **Sea Raiders** (mobile, coastal raids, settlement; want plunder and footholds), **Hill Pastoralists** (herds, seasonal movement, alliances; want grazing and autonomy), and **Merchant Houses** (trade routes, tin and copper, bribery; want wealth and routes open). Each turn an event card is revealed with the next card previewed; the two eligible factions in card order choose to execute the event or perform operations (with or without special activities); acting makes a faction ineligible next card. Harvest cards (shuffled into the deck by epoch) trigger scoring, a drought step, upkeep, and resets. The drought track worsens across the game and reduces yields. Victory conditions differ per faction and are checked at each Harvest.
- **Pillars:**
  1. **Asymmetry with clarity.** Each faction has four operations and three special activities, shown on its own mat.
  2. **Eligibility is the clock.** The sequence-of-play strip is always visible and teachable.
  3. **Bots worth playing against.** Non-player factions follow published flowcharts encoded as data, explainable step by step.
  4. **The collapse is the antagonist.** Drought, quakes, and famine pressure everyone.
- **Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Fresco plaster `#EADBC0`, Minoan red `#A8322D`, Egyptian blue `#2C5F8A`, ochre `#C88A2E`, olive `#6B6B3A`, charcoal `#2B2622`, sea `#3E7C99`, drought dust `#C9A97A`. Faction colours: Palace red, Sea Raiders blue-black `#1E2B3A`, Pastoralists ochre, Merchants green `#3F6F4F`. |
| Shapes | Fresco-style figures (dolphins, lilies, griffins) as decoration; clay-tablet panels for logs; Linear B-inspired signs used only as decoration with an explicit "decorative, not real text" note in HISTORY.md. |
| Typography | Display: a Greek-inspired serif (default: GFS Didot, OFL); body SF Pro. |
| Motion | Cards slide from the deck; pieces march along routes; drought spreads as cracks. |
| Music | Lyre, aulos, and frame drum, original compositions labelled as invented. |
| SFX | Tablet stylus scratch, oars, wind, hooves, quake rumble. |
| Haptics | Rumble on quake events; tick on eligibility changes. |

- **Inspirations:** GMT Games COIN series (Ruhnke's design notes and bot flowcharts); Cline, "1177 B.C."; Knapp and Manning on the Late Bronze Age collapse; Kaniewski et al. on drought evidence.

## 2. Tech Stack Decision

Per `_CONVENTIONS.md` §2, plus:
- **Bot flowcharts as data:** a small decision DSL (JSON) with node types `condition`, `action`, `selectTargets(priorities)`, and `fallback`, interpreted by `LDAI.FlowchartRunner`. Every bot decision records the path through the chart for an "Explain" panel.
- **Map:** region graph with typed edges (land, coast, sea lane).
- ADRs: ADR-0003 rules are original (no copied COIN text); ADR-0004 flowchart DSL; ADR-0005 event card effect DSL (closed set of effect primitives, composable).

## 3. Repository Structure (Game-Specific Additions)

```
Packages/LDCore/Sources/LDCore/
  Map/       Region.swift, Edge.swift, Control.swift
  Factions/  Faction.swift, Pieces.swift, Resources.swift, Operations/(Palace.swift, Raiders.swift, Pastoralists.swift, Merchants.swift), SpecialActivities.swift
  Cards/     Card.swift, Deck.swift, EventEffect.swift, EffectInterpreter.swift, Harvest.swift
  Sequence/  Eligibility.swift, SequenceOfPlay.swift
  Drought/   DroughtTrack.swift, Yields.swift
  Engine/    GameState.swift, Action.swift, Event.swift, Reducer.swift, Victory.swift
Packages/LDContent/  MapDef.swift, CardDef.swift, ScenarioDef.swift, FactionDef.swift, FlowchartDef.swift, Loader.swift, Validation.swift
Packages/LDAI/       FlowchartRunner.swift, Explain.swift, Priorities.swift, MCTSAdvisor.swift
Packages/LDRender/   MapScene.swift, PieceNode.swift, ControlOverlay.swift
Packages/LDMeta/     Scenarios.swift, Stats.swift, Tutorials.swift
Resources/Content/   map.json, cards.json, scenarios.json, factions.json, flowcharts/{palace,raiders,pastoralists,merchants}.json, balance.json, tutorial.json
```

## 4. Core Rules Specification

**Setup and map**
- R-1 Regions have type (palace, farmland, hill, coast), population 0–3, and edges. Scenario sets pieces, resources, drought level, and deck composition.
- R-2 Pieces: Palace (scribes, chariots, garrisons, store markers), Raiders (warbands, ships, camps), Pastoralists (herders, herds, shrines), Merchants (agents, caravans, warehouses).
- R-3 Control: a region is Palace-controlled if Palace pieces exceed all others combined; "Raider-held" if Raider pieces exceed all others combined; Pastoralists and Merchants never control but score through other measures.

**Sequence of play**
- R-4 Reveal the top card and preview the next. The first eligible faction in the card's faction order may: execute the event, perform operations with optional special activity (Op + SA), perform a limited operation (one region), or pass (gain 1 resource, or 3 for Merchants).
- R-5 The second eligible faction's options depend on the first's choice: if the first did Event, second may Op + SA; if first did Op only, second may do Limited Op; if first did Op + SA, second may Event or Limited Op. (Original table in `balance.json`, ADR-0003 documents differences from COIN.)
- R-6 Factions that acted become ineligible for the next card; passers remain eligible.

**Operations (summary; full spec in `docs/RULES.md` written in P1)**
- R-7 Palace: Levy (place garrisons in palaces, cost 1 per region), Patrol (move chariots up to 2 edges), Tax (gain resources from controlled farmland, adds stores), Assault (remove enemy pieces where chariots present). SAs: Redistribute (move stores to hungry regions to reduce unrest), Scribal Census (reveal Merchant agents), Fortify.
- R-8 Raiders: Land (place warbands at coast from ships), March, Raid (take stores or resources, add unrest), Settle (convert warbands to camp). SAs: Burn (destroy a store), Ambush, Recruit Mercenaries.
- R-9 Pastoralists: Migrate (move herds and herders with season restrictions), Graze (gain resources in hills), Rally (place herders at shrines), Ally (shift a region's alignment toward Pastoralists or Raiders). SAs: Raid Herds, Shelter, Pact.
- R-10 Merchants: Open Route (place caravan on a path between two warehouses), Trade (gain resources per open route, more if tin route complete), Bribe (move or remove another faction's piece for resources), Build Warehouse. SAs: Smuggle, Finance (give resources to another faction for a favour recorded as an obligation), Intelligence.

**Events**
- R-11 Each event card has dual effects (shaded and unshaded), a faction order, and an optional "capability" (persistent effect). Effects use the effect DSL (move, place, remove, shift, resources, drought, capability, momentum).

**Harvest**
- R-12 On a Harvest card: (a) victory check; (b) drought step: advance the drought track by the card's value plus 1 if total stores < threshold; (c) yields: farmland and hill regions produce per drought level; Palace collects into stores; (d) upkeep: each faction pays per piece category or removes pieces; (e) unrest resolution; (f) all factions become eligible.
- R-13 Final Harvest: if no faction met its victory, the highest margin wins.

**Victory (checked at Harvest)**
- R-14 Palace: controlled population + stores ≥ 18. Raiders: camps + plunder/2 ≥ 14. Pastoralists: herds in hills + allied regions ≥ 15. Merchants: open routes × 2 + resources/5 ≥ 16. Margins = value − threshold.

**Invariants**
- INV-1 Piece supply conservation per faction.
- INV-2 Eligibility state always matches the sequence-of-play table.
- INV-3 Every event effect validates against current state before applying; invalid parts are skipped per "do as much as you can" with an event log line.
- INV-4 Replay determinism including bot decisions.
- INV-5 Every bot decision has a non-empty explain path.

## 5. Data Schemas and Content Tables

```swift
struct CardDef: Codable, Sendable { var id: String; var title: String; var order: [FactionID]; var unshaded: [EffectStep]; var shaded: [EffectStep]; var capability: CapabilityDef?; var isHarvest: Bool; var droughtValue: Int; var label: HistoryLabel; var flavor: String }
indirect enum EffectStep: Codable, Sendable { case place(PieceSpec, RegionFilter, Int), remove(PieceSpec, RegionFilter, Int), move(PieceSpec, from: RegionFilter, to: RegionFilter, Int), resources(FactionID, Int), drought(Int), shift(RegionFilter, Alignment, Int), choice([[EffectStep]]), forEach(RegionFilter, [EffectStep]) }
struct FlowNode: Codable, Sendable { var id: String; var kind: FlowKind; var condition: Condition?; var action: BotAction?; var yes: String?; var no: String?; var priorities: [Priority]? }
enum Action: Codable, Hashable { case event(shaded: Bool, choices: [Choice]), operation(OpKind, regions: [RegionID], params: OpParams, special: SpecialActivity?), limitedOp(OpKind, RegionID, OpParams), pass }
```

| Table | G3 | G5 | Sample row |
| --- | --- | --- | --- |
| `cards.json` | 48 events + 4 Harvest | 72 + 6 | `{ "id": "c17_shardana", "title": "Shardana Mercenaries", "order": ["R","P","M","H"], "unshaded": [{"place": ["warband","coast", 2]}], "shaded": [{"resources": ["P", 4]}], "label": "Attested" }` |
| `scenarios.json` | 2 | 4 | `{ "id": "short_1190", "deck": "epochs:2", "drought": 2, "setup": [...] }` |
| `map.json` | 1 (20 regions) | 1 (24) | `{ "id": "pylos_hinterland", "type": "palace", "pop": 3, "edges": ["messenia_coast", "western_hills"] }` |
| `flowcharts/*.json` | 4 complete | 4 refined | nodes as above |

Card titles that name real peoples (Sea Peoples groups such as Shardana and Peleset) are labelled Attested with sources; card effects are Invented.

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| Victory thresholds | R-14 | ±4 | `balance.json` |
| Drought track | 0–8 | — | `balance.json` |
| Yield table by drought | data | — | `balance.json` |
| Upkeep costs | data | — | `balance.json` |
| Harvest positions | 1 per epoch of 12 cards | — | `scenarios.json` |

Targets (all-bot sims, 2,000 games per scenario): each faction wins 20–30%; ≥ 40% of games end by an early victory check; median full game 5–6 Harvests; average drought at final Harvest 5–6.

## 7. AI Approach

- **Flowchart bots:** one per faction, deterministic except seeded tie-breaks; decision explain panel.
- **Bot event choice:** each card row includes per-faction "bot instructions" (play event shaded/unshaded or op), as in COIN bot cards.
- **Optional advisor:** MCTS (500 rollouts with bot policies) suggests a move to humans in the tutorial "hint" button (not used by bots).
- **Difficulty:** bots get resource bonuses or extra eligibility tie-breaks per level (Easy, Standard, Hard), in data.

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7 and HIST0.1 (Attested: palace economies, Linear B tablets, Sea Peoples raids, drought evidence; Reconstructed: faction motives; Invented: rules, map details).
- LD-P0.1 ADR-0003 explicitly lists which COIN concepts are reused generically (eligibility, dual events) and states that no GMT text, cards, or art are copied.

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; HIST0.1 and ADR-0003 complete
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- LD-P1.1 `docs/RULES.md` full rules (all operations and SAs with costs, legality, and examples). This is the authoritative spec for the engine.
- LD-P1.2 Map, pieces, control (R-1 to R-3); sequence of play (R-4 to R-6).
- LD-P1.3 Operations and SAs for all factions (R-7 to R-10).
- LD-P1.4 Effect DSL and interpreter (R-11); Harvest (R-12, R-13); victory (R-14).

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-14 tagged tests; INV-1…INV-4 across 2,000 random games (random legal actions)
  [ ] Every card in the G3 subset has an effect test
  [ ] LDCore coverage ≥ 90%; make sim N=1000 deterministic
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5.
- LD-P2.1 Map scene; sequence-of-play strip; card display with preview; action builder (choose op, select regions, confirm); faction mats.
- LD-P2.2 First pass of all four flowcharts (simple) so a 1-human game can complete.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test completes a short scenario as Palace vs 3 bots on iPad and Mac
  [ ] Explain panel shows a path for every bot action
  [ ] `docs/SLICE_ASSESSMENT.md` written: self-assessment against the pillars, with every weakness turned into a P3 task (`_CONVENTIONS.md` §8.1)
Sign-off: GLM-SELF
```

### P3 Content and Systems
- LD-P3.1 G3 cards and scenarios; HIST3.1 labels and flavor text with sources.
- LD-P3.2 Tutorial scenario (scripted, 10 cards) plus faction primers.
- LD-P3.3 Save anywhere; pass-and-play with privacy for hidden choices (none hidden by rule, but hint use is private).

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts met; card lint validates every effect against schema
  [ ] 1,000 all-bot games complete with no stuck states
Sign-off: GLM-SELF
```

### P4 AI Opponents
- LD-P4.1 Complete flowcharts with priorities; difficulty levels; MCTS hint; `docs/BALANCE.md`.

```
GATE G4 — AI
Checks:
  [ ] Faction win share 20–30% each in all-bot sims (or ADR with plan)
  [ ] Bot decisions p95 ≤ 50 ms; hint p95 ≤ 1.5 s
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- LD-P5.1 G5 cards and scenarios; deck variability (epoch shuffles); stats; 24 achievements; HANDOFF.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Counts met; coverage thresholds; HANDOFF complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- LD-P6.1 Fresco card art (commissioned); map art; HIST6.1 fact-check of all flavor text.
- LD-P6.2 Music and SFX.

```
GATE G6 — Aesthetics
Checks:
  [ ] Snapshots approved; HIST6.1 report clean
Sign-off: GLM-SELF
```

### P7 Platform Features
- LD-P7.1 Async GameKit (2–4 humans plus bots); push notifications; iCloud.
- LD-P7.2 Mac: map and card windows; full keyboard.

```
GATE G7 — Platform
Checks:
  [ ] 4-player async game completes; match data within limits
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- LD-P8.1 Factions distinguished by shape and pattern; VoiceOver region rotor and card reader; text size options.

```
GATE G8 — Polish
Checks:
  [ ] VoiceOver completes the tutorial; budgets met
Sign-off: GLM-SELF
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard tasks; recruit COIN players for beta.

```
GATE G9 — Beta
Checks:
  [ ] Crash-free ≥ 99.5%; no rules S1/S2
Sign-off: GLM-SELF
GATE G10 — Release
Checks:
  [ ] Store assets; final CI green
Sign-off: GLM-SELF
```

## 9. Fragile Areas and Priorities

- **Fragile areas:** effect DSL edge cases ("do as much as you can"), R-5 sequence table, Harvest upkeep ordering.
- **Priorities for P6–P10:** action builder UX; async; faction balance; flowchart priorities.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| IP proximity to GMT COIN | Medium | High | ADR-0003; original rules and text | GLM |
| Rules size overwhelms GLM | High | High | RULES.md first; phased factions | GLM |
| Balance across four factions | High | High | Massive sims; data thresholds | GLM |
| UI complexity on iPad | High | Medium | Action builder; Mac windows | GLM |

## 11. Out of Scope

Licensed COIN titles; real-time; map editor; more than 4 factions.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 2–3 |
| P1 | GLM | 15–22 |
| P2 | GLM | 10–14 |
| P3 | GLM | 8–12 |
| P4 | GLM | 10–14 |
| P5 | GLM | 4–6 |
| P6 | GLM | 10–14 |
| P7 | GLM | 6–8 |
| P8 | GLM | 5–7 |
| P9 | GLM | 6–9 |
| P10 | GLM | 2–3 |
| **Total** | | **78–112** |

## 13. Open Questions

1. Real place names (Pylos, Mycenae, Ugarit) or fictionalised? Default: real names for regions with "fictionalised" note.
2. Should a human-vs-human online mode launch, or bots and pass-and-play only? Default: async included.

## 14. Sourcing Notes

- **Sources:** Cline, "1177 B.C." (2014, rev. 2021); Kaniewski et al. on drought (2013); Knapp and Manning, "Crisis in Context" (AJA 2016); Chadwick, "The Mycenaean World".
- **Historical labels:** collapse causes are debated; HISTORY.md presents the multi-causal view.

## Appendix A. Extended Specification (Depth Pass)

### A.1 Additional Rules

**Map and pieces**
- R-15 Regions also carry `alignment` (−2 Raider-aligned … +2 Palace-aligned, Pastoralist allied flag separate), `unrest` (0–3), and `stores` (Palace only, 0–6 per palace region).
- R-16 Stacking: at most 6 pieces of one faction per region; ships occupy sea zones adjacent to coasts (6 sea zones), not regions.
- R-17 Piece supply limits (data): Palace 12 garrisons, 6 chariots, 6 scribes, 12 store markers; Raiders 18 warbands, 6 ships, 6 camps; Pastoralists 12 herders, 12 herds, 4 shrines; Merchants 8 agents, 8 caravans, 4 warehouses.

**Operations detail**
- R-18 Operation costs: each region selected costs the faction 1 resource (Palace Levy and Tax cost 1 per region; Merchants' Trade costs 0). Limited Op = one region, no SA.
- R-19 Assault (Palace): in each selected region with chariots, remove 1 enemy piece per chariot (2 per chariot in farmland); camps and warehouses are removed only after all mobile pieces of that faction there.
- R-20 Raid (Raiders): in a coastal or adjacent-to-coast region with warbands ≥ garrisons: take 1 store (to plunder) or 2 resources from the region's controller; +1 unrest.
- R-21 Migrate (Pastoralists): herds move only along hill and farmland edges; during "dry season" cards (marked) herds may enter palace farmland, adding unrest there.
- R-22 Bribe (Merchants): pay 2 resources per piece moved or 3 per piece removed; cannot target camps, palaces, or shrines.
- R-23 Finance (Merchants SA) creates an `obligation` (creditor, debtor, amount); a debtor with an unpaid obligation at Harvest gives the creditor 1 victory-relevant resource or 1 alignment shift (debtor chooses).

**Unrest and drought**
- R-24 Unrest step (Harvest e): each region with unrest 3 loses 1 population (min 0) and removes 1 Palace garrison; regions with unrest ≥ 2 and no Palace control shift alignment 1 toward Raiders.
- R-25 Drought track 0–8. Yields by level: 0–2 full, 3–4 −1 per region, 5–6 −2, 7–8 none except coasts (fishing 1). Redistribute reduces unrest by 1 per store moved.
- R-26 Momentum events last until the next Harvest; capabilities last until the end of the game unless removed by an event.

**Deck**
- R-27 Deck: 60 event cards + 5 Harvest cards for the full scenario; deck built as 5 piles of 12 events with one Harvest shuffled into the bottom 4 of each pile (piles stacked in order), seeded.
- R-28 Short scenario: 36 events + 3 Harvests.

### A.2 Additional Invariants
- INV-6 Alignment and unrest stay within bounds after every effect.
- INV-7 Harvest positions in the deck satisfy R-27 for every seed (property test).
- INV-8 Obligations always reference existing factions and non-negative amounts; settled obligations are removed.
- INV-9 Bot flowcharts are total: every node has a successor for every state (static check over the flowchart graph).

### A.3 Complete Schemas and Sample Rows

```swift
struct RegionDef: Codable, Sendable { var id: String; var name: String; var type: RegionType; var population: Int; var edges: [String]; var seaZones: [String]; var label: HistoryLabel }
struct EventCardDef: Codable, Sendable { var id: Int; var title: String; var order: [Faction]; var unshaded: [EffectOp]; var shaded: [EffectOp]; var capability: Bool; var momentum: Bool; var bot: [Faction: BotEventChoice]; var label: HistoryLabel; var flavourKey: String }
enum EffectOp: Codable, Sendable { case place(Faction, PieceKind, count: Int, where: RegionFilter), remove(Faction?, PieceKind?, count: Int, where: RegionFilter), move(Faction, PieceKind, count: Int, from: RegionFilter, to: RegionFilter), shift(alignment: Int, where: RegionFilter), resources(Faction, Int), drought(Int), unrest(Int, where: RegionFilter), capability(String), momentum(String) }
struct BotNode: Codable, Sendable { var id: String; var test: BotTest; var yes: String; var no: String; var action: BotAction? }
struct Obligation: Codable, Hashable, Sendable { var creditor: Faction; var debtor: Faction; var amount: Int }
```

```json
{ "id": "pylos_west", "name": "Western Palace", "type": "palace", "population": 3, "edges": ["pylos_fields", "coast_sw"], "seaZones": ["ionian_s"], "label": "Invented" }
{ "id": 17, "title": "Tablets Record Rowers", "order": ["palace", "raiders", "merchants", "pastoralists"], "unshaded": [{"place": ["palace", "garrison", 2, {"type": "coast"}]}], "shaded": [{"remove": ["palace", "garrison", 2, {"type": "coast"}]}], "capability": false, "momentum": false, "bot": {"palace": "unshaded", "raiders": "shaded"}, "label": "Attested-type", "flavourKey": "ev17" }
{ "id": "pal_03", "test": {"kind": "anyRegion", "filter": {"unrest": 3, "controlledBy": "palace"}}, "yes": "pal_redistribute", "no": "pal_04" }
```

"Attested-type" means the card's subject is attested (Linear B tablets from Pylos record rowers), while its effect is Invented; HISTORY.md lists every such card.

### A.4 Balance Tables and Sim Targets

| Parameter | Default | Range | Sim Target |
| --- | --- | --- | --- |
| Victory thresholds (P/R/Pa/M) | 18/14/15/16 | ±3 | Each faction wins 20–30% with 4 standard bots |
| Drought increment per Harvest | card value 1–2 | 0–3 | Drought ends 5–7 in full games |
| Store threshold for +1 drought | 6 | 4–8 | Triggered in 40–60% of Harvests |
| Starting resources | 10/8/6/12 | ±4 | No faction passes > 35% of turns |
| Bribe costs | 2/3 | — | Bribes used 1–3 times per game |
| Final-Harvest win | margin | — | 40–60% of games end before final Harvest |

Protocol: 5,000 full and 5,000 short games with seeded bots; report win share with Wilson intervals, end timing, average drought, and the top 10 most-decisive events (by win-rate delta when played).

### A.5 AI Design in Detail
- **Flowcharts in data** (`bots/*.json` as `BotNode` graphs) interpreted by a small engine; each step appends an explain line ("Palace: region with unrest 3 → Redistribute").
- **Region priorities:** each flowchart has ordered priority lists (e.g., Palace Patrol: regions with Raider warbands > garrisons, then highest population, then random by seed).
- **Event choice:** card `bot` field first; fallback heuristic: play event if it advances own victory margin ≥ 2 more than the best Op estimate.
- **Hint MCTS (humans only):** 500 rollouts with bot policies as rollout policy, UCT c = 1.2, 0.8 s budget.
- **Difficulty:** Hard bots get +2 resources per Harvest and prefer Op + SA when tied; Easy bots pass more (pass when resources < 3).

### A.6 Granular Task Breakdown

| ID | Task | Acceptance Criteria |
| --- | --- | --- |
| LD-P0.1 | ADR-0003 sequence-of-play table and COIN differences | Table complete; original wording |
| LD-P0.2 | HISTORY.md multi-causal collapse summary | Cites Cline, Knapp and Manning |
| LD-P1.1 | Map, pieces, supply, stacking (R-1–R-3, R-15–R-17) | INV-1 |
| LD-P1.2 | Sequence of play and eligibility (R-4–R-6) | INV-2; 30 fixtures |
| LD-P1.3 | Palace ops and SAs (R-7, R-19) | 25 fixtures |
| LD-P1.4 | Raider ops and SAs (R-8, R-20) | 25 fixtures |
| LD-P1.5 | Pastoralist ops and SAs (R-9, R-21) | 20 fixtures |
| LD-P1.6 | Merchant ops, Bribe, Finance (R-10, R-22, R-23) | INV-8; 20 fixtures |
| LD-P1.7 | Effect DSL interpreter (R-11, R-26) | INV-3; every op kind tested |
| LD-P1.8 | Harvest, drought, unrest (R-12, R-24, R-25) | 20 fixtures |
| LD-P1.9 | Deck build (R-27, R-28) | INV-7 |
| LD-P2.1 | Map scene with region overlays | 60 fps at 24 regions |
| LD-P2.2 | Card panel with faction order and options table | Options match eligibility |
| LD-P2.3 | Bot explain panel | Every bot step shown |
| LD-P3.1 | 60 event cards with labels | Lint; HISTORY.md list matches |
| LD-P4.1 | Flowchart engine and 4 bots | INV-9; INV-5 |
| LD-P4.2 | Balance sims | Targets met |
| LD-P5.1 | Short scenario and tutorial scenario | UI tests |

### A.7 Sharpened Gate Checks
- G1 adds: every effect op kind has ≥ 3 fixtures; sequence-of-play table matches ADR-0003 exactly.
- G3 adds: HISTORY.md lists every card's label; no card claims a specific named historical event as cause of collapse.
- G4 adds: no faction above 32% or below 18% in 4-bot sims.

### A.8 Additional Risks

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Too close to COIN trade dress or rules text | Medium | High | Original wording; ADR-0003; no GMT terms ("COIN" only as genre in About) | GLM |
| "Sea Peoples" framing as villains | Medium | Medium | Raiders shown as displaced peoples with motives; HISTORY.md nuance | GLM |
| Card text overflow on iPhone | High | Medium | Iconic effect summary + detail sheet | GLM |

### A.9 Additional Open Questions (Defaults)
1. Use "Sea Peoples" anywhere? Default: only in HISTORY.md and About, never as a faction name.
2. Real place names? Default: as §13 (real names for regions, with a "fictionalised" note); Linear B signs only as decorative texture from public-domain tablets.
3. Multiplayer online? Default: post-launch; pass-and-play at launch.
