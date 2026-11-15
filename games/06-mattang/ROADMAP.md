# 06 — Mattang Roadmap

> Read the swells the way Marshallese navigators do: islands bend the waves, and where the waves cross, a canoe can find its way.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 in full before starting. Depth pass (15 Nov 2026): Appendix A extends §4–§13 and wins where they differ. This roadmap adds only what is specific to Mattang.

Research: [`RESEARCH.md`](RESEARCH.md) (art direction, design lineage, cultural context, advisor institutions, verified glossary, and audio direction).

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 06 · `mattang` |
| Code prefix | `MT` (packages `MTCore`, `MTContent`, `MTAI`, `MTRender`, `MTAudio`, `MTPlatform`, `MTMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Wave-field abstract (two players, perfect information) |
| Difficulty tier | Approachable |
| Scope | Solo-indie |
| Session length | 8–15 minutes |
| Renderer | Metal 4 compute for the wave-field visual (display only) inside SpriteKit; Core uses a discrete swell grid |
| Players | Solo vs AI; local pass-and-play; async online |
| Simulation | Turn-based, discrete ray-traced swells on a hex grid |
| Sourcing tier | `FULL` (Marshallese wave navigation and stick charts, a living and protected knowledge tradition) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** see above.
- **Summary:** The ocean is a 15 × 15 hex grid. Four swells enter from fixed sides (two dominant, two minor, per the chart). Players take turns placing islands (from a shared pool) or moving canoes. Each swell travels in straight rays; an island reflects rays striking its windward face and refracts (bends by one hex direction) rays passing beside it. Where two or more swells cross a cell, a node forms; node strength equals the number of distinct swells crossing. Canoes move only along cells of strength ≥ 1 and may jump along a chain of nodes. Each player launches canoes from a home atoll; the first to land 3 canoes at the rival's atoll wins. Placing an island reshapes the whole field, so every move is both a path for you and a wall for your opponent.
- **Pillars:**
  1. **The field is the board.** Players never draw paths; they shape the sea.
  2. **Always visible.** All rays and nodes recompute and render instantly after a preview.
  3. **Taught by the chart.** Tutorials resemble learning a stick chart: one island, one swell, then more.
  4. **Partnership, not borrowing.** The game ships only with Marshallese advisor approval and a revenue-share agreement.
- **Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Deep sea `#0F3B57`, open sea `#1F6C8C`, swell crests `#BFE3EE`, node glow `#F5D78E`, pandanus fibre `#C8A96B`, coconut rib `#8A6A3B`, cowrie shell `#EFE7D6`, atoll sand `#E9DDB9`, lagoon `#5FB3B3`, Player 1 sail `#B64A2E`, Player 2 sail `#2F4F2F`. |
| Shapes | Islands as cowrie shells tied to frames; swells as bent ribs. Chart frame UI echoes stick-chart construction without copying any specific chart. |
| Typography | SF Pro Rounded; Marshallese terms with correct diacritics (ā, ļ, m̧, n̄, o̧, ō, ū) verified in font. |
| Motion | Swells shimmer continuously (visual only); nodes pulse; canoes surf along. |
| Music | Ambient sea and wind; any Marshallese music only with advisor approval and licensing. |
| SFX | Surf, wood creak, shell clink on island placement. |
| Haptics | Rhythmic pulse when a canoe is on a strong node. |

- **Inspirations:** Genz et al. on Marshallese wave piloting and its contemporary revival; Ascher on stick-chart mathematics; Waan Aelõñ in Majel (WAM) canoe program.

## 2. Tech Stack Decision

Per `_CONVENTIONS.md` §2, plus:
- **Core field:** discrete rays on axial hex grid; up to 3 reflections per ray; integer only. No continuous physics in Core.
- **Visual field:** Metal compute shader approximating interference from Core's ray set (render only; never read back into Core).
- ADRs: ADR-0003 discrete swell model; ADR-0004 reflection and refraction table; ADR-0005 visual field decoupled from Core.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/MTCore/Sources/MTCore/
  Grid/    Hex.swift, Ocean.swift, Atoll.swift
  Swell/   Swell.swift, Ray.swift, Tracer.swift, InteractionTable.swift, NodeField.swift
  Pieces/  Island.swift, Canoe.swift
  Engine/  GameState.swift, Action.swift, Event.swift, Reducer.swift, Movement.swift, Victory.swift, Zobrist.swift
Packages/MTContent/  ChartDef.swift, SwellDef.swift, PuzzleDef.swift, Loader.swift, Validation.swift
Packages/MTAI/       Evaluator.swift, AlphaBeta.swift, PathDistance.swift, PuzzleGenerator.swift
Packages/MTRender/   SeaScene.swift, WaveField.metal, RayOverlay.swift, CanoeNode.swift
Packages/MTMeta/     DailyChart.swift, Voyages.swift, Stats.swift
Resources/Content/   charts.json, swells.json, puzzles.json, voyages.json, balance.json, tutorial.json, glossary.json, cultural_manifest.json
```

## 4. Core Rules Specification

**Setup**
- R-1 The ocean is a hex region (default radius 7, 169 cells). Each player has a home atoll (3 cells) on opposite edges. Swells from `charts.json`: each swell has an entry side, direction, and weight (dominant 2, minor 1).
- R-2 Shared island pool: 10 islands. Each player has 4 canoes in their home atoll.

**Swells**
- R-3 Each swell emits one ray from every edge cell on its entry side, travelling in its direction.
- R-4 Ray interaction with an island cell: if the ray enters the island cell, it reflects (direction reversed about the face normal per `InteractionTable`). If the ray passes a cell adjacent to an island on the island's leeward side, it refracts: direction turns one step toward the island. Atolls behave as islands.
- R-5 A ray terminates after leaving the ocean, after 3 reflections, or after 40 steps.
- R-6 A cell's swell set is the set of distinct swell ids whose rays pass through it. Strength = sum of the weights of distinct swells. A node is a cell with ≥ 2 distinct swells.

**Turn**
- R-7 On a turn, the player does one of: `placeIsland(cell)` (empty, not adjacent to an atoll, not adjacent to another island, pool not empty), `launch` (a canoe from home onto an adjacent cell of strength ≥ 1), or `sail(canoe, path)`.
- R-8 Sailing: a canoe moves up to `sailRange` (default 3) steps along cells of strength ≥ 1; entering a node ends movement unless the canoe continues along a "node chain" (a node adjacent to another node), which costs no range. A canoe cannot enter a cell holding another canoe.
- R-9 A canoe on a cell whose strength drops to 0 after an island placement is "becalmed": it cannot move until strength returns or it is towed (a friendly canoe adjacent spends its turn to move it 1 step).
- R-10 A canoe entering any cell of the rival atoll lands and is removed from the board; it scores 1.

**Victory**
- R-11 First to land 3 canoes wins. If the island pool is empty and neither player can move for two consecutive turns, the player with more landed canoes wins, then the player whose remaining canoes are closer by path distance, then Player 2.

**Invariants**
- INV-1 Tracing is deterministic and order-independent (rays traced in any order give the same field).
- INV-2 The field recomputed from scratch equals the incremental update after every action.
- INV-3 Canoe count conservation (home + sea + landed = 4).
- INV-4 Replay determinism.
- INV-5 Every ray terminates within 40 steps.

## 5. Data Schemas and Content Tables

```swift
struct SwellDef: Codable, Sendable { var id: String; var entrySide: Int; var direction: Int; var weight: Int; var name: GlossaryKey? }
struct GameState: Codable, Hashable, Sendable { var chartID: String; var islands: Set<Hex>; var poolRemaining: Int; var canoes: [CanoeID: CanoeState]; var landed: [PlayerID: Int]; var toMove: PlayerID; var stuckTurns: Int }
enum Action: Codable, Hashable { case placeIsland(Hex), launch(Hex), sail(CanoeID, [Hex]), tow(CanoeID, Hex), pass }
```

| Table | G3 | G5 | Sample row |
| --- | --- | --- | --- |
| `charts.json` | 4 | 10 | `{ "id": "two_swells_basic", "swells": ["east_dom","north_dom","west_min","south_min"], "preIslands": [], "cultural": false }` |
| `swells.json` | 4 | 8 | `{ "id": "east_dom", "entrySide": 0, "direction": 3, "weight": 2, "glossary": "pending_advisor" }` |
| `puzzles.json` | 30 | 120 | `{ "id": "mt_p001", "start": "<GameState>", "goal": "land_in", "plies": 2 }` |
| `voyages.json` (solo campaign) | 6 | 18 | `{ "id": "v01", "chart": "two_swells_basic", "opponent": "navigator", "lesson": "reflection" }` |
| `glossary.json` | 10 | 30 | All entries `"status": "pending"` until the maintainer records advisor answers in the advisor issue |

Swell names (Marshallese terms) are added only from advisor-approved glossary entries; until then, use neutral names ("East swell").

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| Ocean radius | 7 | 5–9 | `charts.json` |
| Island pool | 10 | 6–14 | `balance.json` |
| Canoes per player | 4 | 3–5 | `balance.json` |
| `sailRange` | 3 | 2–4 | `balance.json` |
| Refraction enabled | true | — | `balance.json` |
| Max reflections | 3 | 1–4 | `balance.json` |

Targets (Navigator vs Navigator, 2,000 games per chart): Player 1 win rate 46–54%; median length 24–40 plies; ≥ 85% of games end by 3 landings; island placements 30–55% of all actions.

## 7. AI Approach

- **Search:** alpha-beta with incremental field updates and Zobrist TT; quiescence on moves that becalm canoes.
- **Evaluation:** difference in shortest-path distances (over strength ≥ 1 cells, node chains free) of each player's best 3 canoes to the rival atoll, plus landed × 100, minus becalmed canoes × 8.
- **Tiers:** Paddler (depth 1, noise), Sailor (depth 2), Navigator (depth 4 or 1.0 s), Master Navigator name pending advisor input (depth 6 or 2.0 s); until approval the top tier is "Deep Water".
- **Puzzles:** generated by mining positions with forced landings within N plies.

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7, SRC0.1, SRC0.2, HIST0.1.
- MT-P0.1 `docs/SOURCING.md` §3 must state that the game does not teach or claim to teach actual navigation knowledge, and §5 restricts depictions of specific stick charts held by families or museums.

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; SRC0.1, SRC0.2, HIST0.1 complete
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- MT-P1.1 Tracer and interaction table (R-3 to R-6) with 50 fixtures, including multiple reflections and corner cases.
- MT-P1.2 Turn actions, becalming, towing, landing, victory (R-7 to R-11).
- MT-P1.3 Incremental field updates (INV-2).

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-11 tagged tests; INV-1…INV-5 over 5,000 seeds
  [ ] Field update < 0.5 ms; MTCore coverage ≥ 90%; make sim N=5000 deterministic
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5, SRC2.1, SRC2.2.
- MT-P2.1 Sea scene with ray overlay (toggle), node highlights, island placement preview that shows the field before committing.
- MT-P2.2 Canoe move with path preview; Sailor AI opponent.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test completes a game vs Sailor on iPad and Mac
  [ ] Preview and committed fields match in 100% of 500 random placements
  [ ] Manifest marks every swell name, glossary term, and canoe art as pending; deny-list passes
  [ ] `docs/SLICE_ASSESSMENT.md` written: self-assessment against the pillars, with every weakness turned into a P3 task (`_CONVENTIONS.md` §8.1)
Sign-off: GLM-SELF
```

### P3 Content and Systems
- MT-P3.1 G3 charts and puzzles; voyages campaign (6).
- MT-P3.2 Tutorial (5 lessons); About the Tradition (SRC3.1) drafted with placeholders for advisor-written text.
- MT-P3.3 Pass-and-play; undo for casual mode.

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts met; lint clean; tutorial UI test passes
Sign-off: GLM-SELF
```

### P4 AI Opponents
- MT-P4.1 Four tiers; puzzle generator; `docs/BALANCE.md`.

```
GATE G4 — AI
Checks:
  [ ] Each tier beats the one below ≥ 75% over 500 games; p95 within budgets
  [ ] Win-rate targets met per chart (or ADR)
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- MT-P5.1 G5 counts; daily chart; stats; 20 achievements; SRC5.1 packet; HANDOFF.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Daily identical for 30 dates; counts met; packet and HANDOFF complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- MT-P6.1 Metal wave field; chart-frame UI; canoe art (the walap or tipnōl forms only if advisors approve).
- MT-P6.2 SRC6.1 and SRC6.2: advisors (arranged by the maintainer through a `needs-maintainer` issue, for example through WAM or a Marshallese cultural organisation) review all names, art, text, and title.

```
GATE G6 — Aesthetics and Cultural Review
Checks:
  [ ] Advisor review filed as a `needs-maintainer` issue (SUBSTITUTED, `_SET2_ADDENDUM.md` §4); every entry still pending advisor review listed in that issue; revenue-share decision filed as a `needs-maintainer` issue
  [ ] 120 fps on iPad Pro
Sign-off: GLM-SELF
```

### P7 Platform Features
- MT-P7.1 Game Center, async matches, iCloud.
- MT-P7.2 Pencil hover previews island effect; Mac keyboard.

```
GATE G7 — Platform
Checks:
  [ ] Async match completes; hover fallback (long-press) verified
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- MT-P8.1 Strength shown by pattern and number, not colour alone; VoiceOver describes swell sets per cell.
- MT-P8.2 Reduce Motion freezes the shimmer.

```
GATE G8 — Polish
Checks:
  [ ] VoiceOver full game; budgets; color-blind review
Sign-off: GLM-SELF
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard tasks; SRC9.1 community playtest with Marshallese players and SRC10.1 credits and revenue share, each prepared locally and filed as a `needs-maintainer` issue.

```
GATE G9 — Beta
Checks:
  [ ] Crash-free ≥ 99.5%; community playtest filed as a `needs-maintainer` issue (SUBSTITUTED: scripted UI-test playthroughs and recordings, `_CONVENTIONS.md` §8.2)
Sign-off: GLM-SELF
GATE G10 — Release
Checks:
  [ ] SRC10.1 credits draft and store copy filed for maintainer and advisor review as `needs-maintainer` issues (SUBSTITUTED); final CI green
Sign-off: GLM-SELF
```

## 9. Fragile Areas and Priorities

- **Fragile areas:** interaction table corner cases (rays hitting island vertices), becalm and tow rules.
- **Priorities for P6–P10:** Metal field, VoiceOver; chart balance and the cultural packet.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Appropriation of protected knowledge | Medium | High | Advisors, revenue share, no claim of real navigation | GLM |
| Field too opaque | Medium | High | Overlay, previews, tutorial | GLM |
| Advisor process delays launch | Medium | Medium | Start outreach at P0 | GLM |

## 11. Out of Scope

Actual navigation training; real-world maps of the Marshall Islands; replicas of specific charts; real-time sailing.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 2 |
| P1 | GLM | 5–7 |
| P2 | GLM | 5–7 |
| P3 | GLM | 4–6 |
| P4 | GLM | 4–6 |
| P5 | GLM | 3–5 |
| P6 | GLM | 8–11 |
| P7 | GLM | 3–5 |
| P8 | GLM | 3–4 |
| P9 | GLM | 4–6 |
| P10 | GLM | 2–3 |
| **Total** | | **43–62** |

## 13. Open Questions

1. Title: "Mattang" names one kind of stick chart; advisors may prefer another title. Default: keep as working title until the maintainer answers the advisor issue; GLM continues with it.
2. Revenue-share partner and percentage. Default: none set by GLM; filed as a `needs-maintainer` issue.

## 14. Sourcing Notes

- **Tradition:** Marshallese wave piloting (stick charts: mattang, meddo, rebbelib).
- **Sources:** Genz, Aucan, Merrifield, Finney, Joel, and Kelen, "Wave Navigation in the Marshall Islands" (Oceanography, 2009); Ascher, "Models and Maps from the Marshall Islands" (1995); Smithsonian collections notes.
- **Restricted elements:** no replication of specific family charts; no claims of teaching navigation; no religious or chiefly titles.
- **Glossary seeds (verified against Genz et al. 2009 and Genz 2011; all still pending advisor confirmation of spelling):** booj ("knot"; the node where swells meet; also written boot or bōt), okar ("root"; a line of nodes), dilep ("backbone"; the wave path between islands), kaelep (western swell), and the chart types mattang, meddo, rebbelib, and wapepe. ri-meto ("person of the ocean") is a title conferred by an iroij and must not be used for tiers or ranks.
- **Context to state in About:** charts were memorised on land, not carried at sea; the game is an abstraction, not navigation training.
- **Historical labels:** stick charts as teaching tools are Attested; the scoring game is Invented.

## Appendix A. Extended Specification (Depth Pass)

### A.1 Additional Rules

**Field tracing**
- R-12 Hex directions are indexed 0–5 clockwise from east. Reflection off an island face: incoming direction `d` striking the face whose outward normal is `n` leaves in direction `(2n − d + 3) mod 6`; when a ray enters an island cell through a vertex (two faces equidistant), it reverses (`d + 3`).
- R-13 Refraction (R-4) occurs at most once per island per ray, and only when the ray's next cell is adjacent to the island and not itself an island. The turn is one step toward the island (clockwise or counter-clockwise, whichever reduces distance to the island centre; ties turn clockwise).
- R-14 A ray that would refract toward two islands at once refracts toward the one with the lower cell index (row-major order), so tracing is deterministic.
- R-15 Rays from the same swell do not interact with each other; a cell counts each swell id once regardless of how many rays of that swell pass.
- R-16 Rival atoll cells are islands for tracing; home atolls likewise.

**Canoes**
- R-17 Launch places a canoe on any empty cell adjacent to the home atoll with strength ≥ 1; launching does not consume sail range (the canoe cannot sail that turn).
- R-18 A sail path is a sequence of adjacent cells; each non-node step costs 1; a step from a node into an adjacent node costs 0 (node chain); the path ends on the first node that is not followed by a further node step, or when range is exhausted.
- R-19 Towing (R-9) moves a becalmed friendly canoe 1 step to any adjacent empty cell; the towed canoe may then move normally next turn.
- R-20 Canoes block other canoes but do not block rays.

**Islands**
- R-21 Islands cannot be placed on a cell holding a canoe, nor so that any canoe would have no adjacent cell at all (fully enclosed).
- R-22 Pre-placed chart islands (`preIslands`) are permanent and count toward the 3-reflection limit like any island.

**Draw handling**
- R-23 Threefold repetition of the full state (islands, canoes, side) ends the game by the R-11 tie-break.

### A.2 Additional Invariants
- INV-6 The field is symmetric under the chart's declared symmetry (mirror charts produce mirrored fields; property test).
- INV-7 No island placement creates a path-disconnected home atoll (every atoll keeps ≥ 1 adjacent cell reachable by strength ≥ 1 at chart start).
- INV-8 Becalmed status is a pure function of the field and canoe position.
- INV-9 Incremental tracing touches only rays whose path intersects the placed island's neighbourhood; recomputation equals full trace (INV-2) and is ≤ 2 ms on A15.

### A.3 Complete Schemas and Sample Rows

```swift
struct ChartDef: Codable, Sendable { var id: String; var radius: Int; var swells: [String]; var preIslands: [Hex]; var homeAtolls: [PlayerID: [Hex]]; var symmetry: ChartSymmetry; var cultural: Bool; var manifestKey: String? }
enum ChartSymmetry: String, Codable, Sendable { case none, mirror, rotate180 }
struct CanoeState: Codable, Hashable, Sendable { var owner: PlayerID; var location: CanoeLocation; var becalmed: Bool }
enum CanoeLocation: Codable, Hashable, Sendable { case home, sea(Hex), landed }
struct Field: Sendable { var swells: [Hex: SwellMask]; var strength: [Hex: Int]; var rays: [RayPath] }
struct RayPath: Sendable, Hashable { var swell: String; var cells: [Hex]; var reflections: Int; var termination: RayEnd }
enum RayEnd: String, Sendable { case leftOcean, maxReflections, maxSteps }
struct GlossaryEntry: Codable, Sendable { var key: String; var term: String; var gloss: String; var status: ReviewStatus; var source: String }
```

```json
{ "id": "lagoon_mirror", "radius": 7, "swells": ["east_dom", "north_dom", "west_min", "south_min"], "preIslands": [[0, 0]], "homeAtolls": {"p1": [[-7,3],[-7,4],[-6,3]], "p2": [[7,-3],[7,-4],[6,-3]]}, "symmetry": "rotate180", "cultural": false }
{ "key": "gl_booj", "term": "booj", "gloss": "knot; the place where swells meet", "status": "pending", "source": "Genz et al. 2009" }
{ "id": "v04", "chart": "lagoon_mirror", "opponent": "deep_water", "lesson": "node_chain" }
```

### A.4 Balance Tables and Sim Targets

| Parameter | Default | Range | Sim Target |
| --- | --- | --- | --- |
| `sailRange` | 3 | 2–4 | Median 24–40 plies |
| Island pool | 10 | 6–14 | Island placements 30–55% of actions |
| Max reflections | 3 | 1–4 | ≥ 60% of nodes created by reflection or refraction (not raw crossing) |
| Node-chain cost | 0 | 0–1 | Node chains used in ≥ 25% of landings |
| Canoes | 4 | 3–5 | Becalming occurs in 40–80% of games |
| Minor swell weight | 1 | 1 | — (fixed) |

Per-chart acceptance: P1 win 46–54% (Wilson 95% within 44–56%); no chart where the first island placement by Navigator is the same cell > 50% of games (diversity check).

### A.5 AI Design in Detail
- **Move generation:** islands on legal cells (pruned to cells within 2 of any ray of the current field that touches a canoe's shortest path); launches; sails (enumerate reachable end cells by BFS with node-chain cost 0, deduplicated by end cell); tows.
- **Evaluation:** `100·landed + Σ_best3 (30 − dist) − 8·becalmed + 4·(nodes adjacent to own canoes) − 4·(nodes adjacent to rival canoes) + 2·poolTempo`, where `dist` is BFS distance with node chains free and `poolTempo` rewards having the last island when the pool is odd.
- **Search:** alpha-beta with iterative deepening, TT 2¹⁹, history heuristic; quiescence on becalming placements (depth 2).
- **Explain:** after each AI island placement, highlight rays that changed and the canoe distances before/after.

### A.6 Granular Task Breakdown

| ID | Task | Acceptance Criteria |
| --- | --- | --- |
| MT-P0.1 | Hex, directions, and face normals | Reflection table matches 36-case hand table |
| MT-P0.2 | SOURCING.md, manifest, glossary pending states | Lint fails on unapproved Marshallese term in release |
| MT-P1.1 | Ray tracer with reflection (R-3–R-5, R-12) | 40 fixtures; INV-5 |
| MT-P1.2 | Refraction (R-13, R-14) | 30 fixtures incl. double-island ties |
| MT-P1.3 | Incremental tracing | INV-2 and INV-9 over 2,000 games |
| MT-P1.4 | Turns: place, launch, sail, tow (R-7–R-10, R-17–R-21) | 50 fixtures |
| MT-P1.5 | Victory and draws (R-11, R-23) | 15 fixtures |
| MT-P2.1 | Field renderer (Metal shader for crests) | 60 fps on A15 with 400 ray segments |
| MT-P2.2 | Preview: ghost island recomputes field | Preview equals Core in 500 cases |
| MT-P2.3 | Sail path drawing with node-chain highlight | Only legal paths can commit |
| MT-P3.1 | Charts (4) and tutorial "one island, one swell" sequence | UI test completes |
| MT-P3.2 | About the Tradition placeholders | All text keys pending |
| MT-P4.1 | Search and tiers | Tier gap ≥ 75% |
| MT-P4.2 | Puzzle miner | 120 puzzles verified unique |
| MT-P5.1 | Voyage campaign (18) | Each voyage beatable by Navigator |
| MT-P5.2 | Review packet including glossary and chart art | Every term and asset listed |

### A.7 Sharpened Gate Checks
- G1 adds: the 36-case reflection table and 30 refraction fixtures pass; tracing determinism on 10,000 random fields.
- G2 adds: a scripted UI test of the "one island, one swell" lesson shows the predicted node highlight matching Core; the human prediction check is SUBSTITUTED per `_CONVENTIONS.md` §8.2.
- G3 adds: no Marshallese term appears in any release string table (lint), only glossary keys.
- G5 adds: review packet states clearly which chart types (mattang, meddo, rebbelib) inspired which UI elements.

### A.8 Additional Risks

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Players think the game teaches real navigation | Medium | High | About screen states the game is an abstraction; charts were memorised, not carried at sea | GLM |
| Title "Mattang" names a specific chart type | High | High | Advisor approves title or rename (fallback "Swellmark") | GLM |
| Ray visuals noisy on small screens | Medium | Medium | Show only rays touching the selected canoe on iPhone | GLM |

### A.9 Additional Open Questions (Defaults)
1. Use "navigator" tier names at all? Default: neutral tier names (Paddler, Sailor, Deep Water); avoid ri-meto, which is a title bestowed by chiefs.
2. Add a wapepe-style wave-model view? Default: no, unless advisors suggest it.
3. Revenue share with a Marshallese organisation? Default: filed as a `needs-maintainer` issue in P6 (pillar 4); GLM continues.
