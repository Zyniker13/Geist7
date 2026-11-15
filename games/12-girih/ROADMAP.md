# 12 — Girih Roadmap

> Lay the five girih tiles that medieval Islamic artisans used, and claim the strapwork stars that bloom where your lines meet.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 in full before starting. Depth pass (15 Nov 2026): Appendix A extends §4–§13 and wins where they differ. This roadmap adds only what is specific to Girih.

Research: [`RESEARCH.md`](RESEARCH.md) (art direction, design lineage, cultural context, advisor institutions, verified glossary, and audio direction).

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 12 · `girih` |
| Code prefix | `GH` (packages `GHCore`, `GHContent`, `GHAI`, `GHRender`, `GHAudio`, `GHPlatform`, `GHMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Tile-laying pattern abstract with a shared market (two players; solo puzzles) |
| Difficulty tier | Deep |
| Scope | Solo-indie |
| Session length | 15–25 minutes |
| Renderer | SpriteKit with Metal shader for glazed tile surfaces; strapwork drawn as vector paths |
| Players | Solo vs AI; local pass-and-play; async online |
| Simulation | Turn-based, perfect information with a shared visible market (seeded draw) |
| Sourcing tier | `FULL` (Islamic geometric art, a living tradition in Iran, Central Asia, Turkey, Morocco, and beyond) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** see above.
- **Summary:** The five girih tiles (regular decagon, regular pentagon, rhombus, bowtie, and elongated hexagon) all have equal edge lengths and interior angles that are multiples of 36°. Each tile carries decorative lines (girih, "knots") that cross each edge's midpoint at 54°/126°; when tiles are joined, lines continue and form strapwork stars and polygons. Players take tiles from a shared market of 6 and place them edge-to-edge, with each edge-midpoint line continuing. When a closed strapwork figure (for example a 10-pointed star around a decagon centre or a pentagram) is completed, it is claimed by the player who contributed the most tile area to it, ties to the closer (the player who completed it). Once per game each player may "subdivide" one of their placed tiles into smaller girih tiles (self-similar subdivision, as seen at the Darb-i Imam shrine), which changes the line network. Most points from claimed figures wins.
- **Pillars:**
  1. **Exact geometry.** Tiles and lines are computed exactly (golden-ratio arithmetic), never approximated.
  2. **Beauty emerges.** The finished board is always a beautiful pattern; scoring rewards completed figures.
  3. **Shared market tension.** Taking a tile denies it to your rival.
  4. **Ornament, not scripture.** No religious inscriptions or calligraphy of sacred text.
- **Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Turquoise glaze `#1C8C9C`, lapis `#1F3F7A`, white slip `#F4F1EA`, ochre `#C99A3C`, aubergine `#5A2E45`, terracotta `#B5603E`, strapwork gold `#D8B35A`, grout `#3A3632`. Player 1 strap colour lapis, Player 2 terracotta. |
| Shapes | Exact girih polygons; strapwork as interlaced bands (over-under weaving computed). |
| Typography | Display: Aref Ruqaa or a humanist Latin serif for headings with Kufic-inspired ornamental borders (non-text); body SF Pro. |
| Motion | Tiles slide into place with a ceramic click; completed figures glow and interlace animates. |
| Music | Santur and ney textures (commissioned from musicians of the tradition by the maintainer through a `needs-maintainer` issue). |
| SFX | Ceramic tap, chisel, fountain. |
| Haptics | Click on edge-match; long pulse on figure completion. |

- **Inspirations:** Lu and Steinhardt, "Decagonal and Quasi-crystalline Tilings in Medieval Islamic Architecture" (Science, 2007); Bonner, "Islamic Geometric Patterns" (2017); Broug, "Islamic Geometric Design" (2013); Cromwell on girih subdivision.

## 2. Tech Stack Decision

Per `_CONVENTIONS.md` §2, plus:
- **Exact arithmetic:** coordinates in the ring Z[ζ₁₀] represented as integer vectors over the basis {1, ζ, ζ², ζ³} (cyclotomic integers for 10th roots of unity), so all vertices are exact; subdivision scales by φ (golden ratio) handled by representing scale as a power of φ with integer coefficients in Z[φ]. No floats in Core (ADR-0004).
- **Strapwork:** line segments defined per tile type as exact edge-midpoint pairs; figure detection by cycle finding on the strap graph.
- ADRs: ADR-0003 tile set and edge rules; ADR-0004 exact cyclotomic arithmetic; ADR-0005 claim and tie rule.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/GHCore/Sources/GHCore/
  Geometry/  Cyclo10.swift, ZPhi.swift, Vertex.swift, Polygon.swift, Placement.swift, Overlap.swift
  Tiles/     TileKind.swift, TileDef.swift, StrapSegments.swift, Subdivision.swift
  Strap/     StrapGraph.swift, FigureFinder.swift, FigureKind.swift, Claim.swift
  Engine/    GameState.swift, Market.swift, Action.swift, Event.swift, Reducer.swift, Score.swift, Zobrist.swift
Packages/GHContent/  FigureScoreDef.swift, MarketDef.swift, PuzzleDef.swift, Loader.swift
Packages/GHAI/       Search.swift, Eval.swift, PuzzleGen.swift
Packages/GHRender/   TableScene.swift, TileNode.swift, StrapRenderer.swift (interlace), GlazeShader.metal
Packages/GHMeta/     DailyPattern.swift, Puzzles.swift, Stats.swift
Resources/Content/   figures.json, market.json, puzzles.json, balance.json, tutorial.json, glossary.json, cultural_manifest.json
```

## 4. Core Rules Specification

**Tiles and placement**
- R-1 Five tile kinds with equal edges: decagon (10 edges, angles 144°), pentagon (108°), elongated hexagon (72°, 144°, 144°, 72°, 144°, 144°), bowtie (72°, 72°, 216°, 72°, 72°, 216°), rhombus (72°, 108°).
- R-2 Each edge midpoint carries two strap lines at 54° to the edge (the standard girih decoration). Strap segments inside each tile are fixed per kind (data).
- R-3 The first tile is a decagon at the centre. A placement must share at least one full edge with an existing tile, must not overlap any tile (exact polygon intersection), and every shared edge matches automatically since all edges are equal. Angles at vertices must not exceed 360° and must leave a gap fillable by some girih tile (pre-computed vertex-angle feasibility: remaining angle must be a sum of tile angles, i.e., a multiple of 36° that some combination fills).
- R-4 Rotation: tiles rotate in 36° steps.

**Market**
- R-5 Market of 6 face-up tiles drawn from a seeded bag (counts in `market.json`: decagon 8, pentagon 12, hexagon 16, bowtie 14, rhombus 16). On a turn a player takes one market tile and places it; the market refills.
- R-6 A player who cannot legally place any market tile may discard one to the bottom of the bag and draw (passes).

**Figures and claims**
- R-7 The strap graph joins segments across shared edges. A figure is a closed simple cycle of strap segments enclosing no other strap segment (a face of the strap arrangement), recognised by kind (10-star, 5-star, pentagon, hexagon, bowtie, and "kite" faces) from `figures.json`.
- R-8 When a placement closes a figure, it is claimed by the player who placed the greater area of the tiles the figure overlaps; ties go to the player who closed it. Figures score per kind (10-star 6, 5-star 3, others 1–2).
- R-9 Subdivision (once per player per game, as a full turn): replace one of your own tiles with its girih subdivision at scale 1/φ² (rules per Lu and Steinhardt's self-similar scheme); the subdivided tiles keep your ownership; any figures it created are claimed immediately by the subdivider; figures previously claimed that are destroyed by the subdivision remain scored.

**End**
- R-10 Game ends after both players have placed `tilesPerPlayer` (default 18) tiles or the bag is empty and the market is unplayable. Highest score wins; tie: more 10-stars, then Player 2.

**Invariants**
- INV-1 No overlapping tiles (exact test) after any action.
- INV-2 Vertex angle sums ≤ 360°; all completed vertices sum to exactly 360°.
- INV-3 Every strap segment endpoint is an edge midpoint or interior junction; the strap graph is consistent across shared edges.
- INV-4 Replay determinism.
- INV-5 Figure detection incremental equals full recompute.

## 5. Data Schemas and Content Tables

```swift
struct Cyclo10: Codable, Hashable, Sendable { var a: Int, b: Int, c: Int, d: Int }   // a + bζ + cζ² + dζ³
struct Placement: Codable, Hashable, Sendable { var kind: TileKind; var anchor: Cyclo10; var rotation: Int /*0..9*/; var scaleExp: Int; var owner: PlayerID }
struct GameState: Codable, Hashable, Sendable { var tiles: [Placement]; var market: [TileKind]; var bag: [TileKind]; var claimed: [FigureID: PlayerID]; var scores: [PlayerID: Int]; var subdivUsed: Set<PlayerID>; var toMove: PlayerID }
enum Action: Codable, Hashable { case take(marketIndex: Int, placement: Placement), subdivide(tileIndex: Int), discard(marketIndex: Int) }
```

| Table | G3 | G5 | Sample row |
| --- | --- | --- | --- |
| `figures.json` | 6 kinds | 8 | `{ "id": "star10", "points": 6, "signature": "<edge-angle sequence>" }` |
| `market.json` | 1 bag | 3 variants | `{ "id": "classic", "counts": {"decagon":8,"pentagon":12,"hexagon":16,"bowtie":14,"rhombus":16} }` |
| `puzzles.json` | 30 | 120 | `{ "id": "gh_p001", "start": "<state>", "goal": "complete_star10", "moves": 2 }` |
| `glossary.json` | 8 | 20 | girih (Persian, "knot"), gereh-sazi, strapwork, muqarnas (reference only), pending advisor |

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| Figure points | per row | 1–8 | `figures.json` |
| Market size | 6 | 4–8 | `balance.json` |
| Tiles per player | 18 | 12–24 | `balance.json` |
| Subdivision allowed | true | — | `balance.json` |

Targets: first-player win 47–53%; 10-stars claimed per game 2–5; subdivision used in ≥ 70% of games by AI and decisive in 10–25%; market discards < 5% of turns.

## 7. AI Approach

- **Search:** alpha-beta depth 2–3 with move generation pruned to top-k placements by heuristic (k = 24); positions hashed.
- **Evaluation:** score difference + potential figures (open figures × probability of closure weighted by area lead) + market denial.
- **Tiers:** Apprentice, Artisan, Master (1.0 s), Ustad (2.5 s).

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7, SRC0.1, SRC0.2, HIST0.1 (Attested: girih tiles and subdivision at Darb-i Imam (1453); Topkapı Scroll; Invented: scoring).
- GH-P0.1 `Cyclo10` and `ZPhi` with exhaustive arithmetic tests (associativity, ζ¹⁰ = 1, reduction by the cyclotomic polynomial).

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; SRC0.1, SRC0.2, HIST0.1; arithmetic tests pass
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- GH-P1.1 Tile geometry, placement legality, overlap, vertex feasibility (R-1 to R-4).
- GH-P1.2 Strap graph, figure finder, claims (R-7, R-8); subdivision (R-9).
- GH-P1.3 Market and end (R-5, R-6, R-10).

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-10 tests; INV-1…INV-5 over 3,000 seeds
  [ ] Placement legality < 1 ms average; GHCore coverage ≥ 90%; make sim N=2000 deterministic
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5, SRC2.1, SRC2.2.
- GH-P2.1 Table scene with pan and zoom; drag a market tile; it snaps to the nearest legal edge and rotation; ghost previews show figures that would close.
- GH-P2.2 Artisan AI.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test completes a game on iPad and Mac
  [ ] Snapping never offers an illegal placement (1,000 random drags)
  [ ] Manifest and deny-list (no sacred calligraphy, no mosque names) pass
  [ ] `docs/SLICE_ASSESSMENT.md` written: self-assessment against the pillars, with every weakness turned into a P3 task (`_CONVENTIONS.md` §8.1)
Sign-off: GLM-SELF
```

### P3 Content and Systems
- GH-P3.1 G3 content; About the Tradition (SRC3.1) with credits to the architectural sources; HIST3.1.
- GH-P3.2 Tutorial (5 lessons); pass-and-play.

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts met; lint clean; tutorial UI test
Sign-off: GLM-SELF
```

### P4 AI Opponents
- GH-P4.1 Tiers; puzzle generator; `docs/BALANCE.md`.

```
GATE G4 — AI
Checks:
  [ ] Each tier beats the one below ≥ 70%; p95 budgets; targets met or ADR
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- GH-P5.1 G5 counts; daily pattern; gallery (save finished boards as images); 20 achievements; SRC5.1; HANDOFF.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Counts met; daily deterministic; packet and HANDOFF complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- GH-P6.1 Glaze shader; interlaced strapwork; palettes per region (Isfahan, Bukhara, Fez) only if advisors approve regional naming.
- GH-P6.2 Music; SFX; SRC6.1 and SRC6.2 advisor review (a practitioner or scholar of Islamic geometric art).

```
GATE G6 — Aesthetics and Cultural Review
Checks:
  [ ] Advisor review filed as a `needs-maintainer` issue (SUBSTITUTED, `_SET2_ADDENDUM.md` §4); every entry still pending advisor review listed in that issue; 120 fps with 200 tiles
Sign-off: GLM-SELF
```

### P7 Platform Features
- GH-P7.1 Game Center, async, iCloud; Pencil precision placement; export board as vector PDF.

```
GATE G7 — Platform
Checks:
  [ ] Async completes; PDF export exact
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- GH-P8.1 Ownership by pattern (striped straps); VoiceOver placement list ("Pentagon at edge 4 of decagon 1, closes a 5-star"); zoom accessibility.

```
GATE G8 — Polish
Checks:
  [ ] VoiceOver completes a game; budgets met
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

## 9. Fragile Areas and Priorities

- **Fragile areas:** exact arithmetic overflow at deep subdivision (cap scaleExp ≥ −2), vertex feasibility table.
- **Priorities for P6–P10:** interlace renderer, snapping UX; figure points; cultural packet.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Geometry bugs | Medium | High | Exact arithmetic; invariants | GLM |
| Religious sensitivity | Low | High | Deny-list; advisors | GLM |
| Placement fiddly on touch | Medium | Medium | Snapping, Pencil | GLM |

## 11. Out of Scope

Free-form pattern editor (post-launch candidate); 3D muqarnas; calligraphy.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 2–3 |
| P1 | GLM | 8–11 |
| P2 | GLM | 5–7 |
| P3 | GLM | 3–5 |
| P4 | GLM | 4–6 |
| P5 | GLM | 3–5 |
| P6 | GLM | 7–10 |
| P7 | GLM | 3–5 |
| P8 | GLM | 3–4 |
| P9 | GLM | 4–6 |
| P10 | GLM | 2–3 |
| **Total** | | **44–65** |

## 13. Open Questions

1. Add a sandbox for free pattern-making? Default: post-launch.

## 14. Sourcing Notes

- **Sources:** Lu and Steinhardt, "Decagonal and Quasi-Crystalline Tilings in Medieval Islamic Architecture", Science 315:1106–1110 (2007); Bonner (2017); Broug (2013); Necipoğlu, "The Topkapı Scroll" (1995).
- **Disputed claims (state as such in About and HISTORY):** Lu and Steinhardt's reading of the Darb-i Imam shrine (Isfahan, 1453) as a near-quasicrystalline, self-similar girih pattern is debated (e.g., later papers in the Nexus Network Journal question how intentional the self-similarity was). R-9's subdivision is "inspired by" their scheme and labelled Reconstructed; the game does not claim medieval craftsmen knew quasicrystal mathematics.
- **Restricted elements:** no Qur'anic or other sacred inscriptions; no named mosques or shrines as boards without advisor approval; no figurative imagery in sacred contexts.
- **Glossary seeds (pending advisor):** girih, gereh-sazi, banna'i.

## Appendix A. Extended Specification (Depth Pass)

### A.1 Additional Rules

**Exact geometry**
- R-11 Coordinates are elements of `Z[ζ]` with ζ = e^{iπ/5} (Cyclo10, four integer coefficients, using ζ⁴ = ζ³ − ζ² + ζ − 1). All vertices of all tiles at all scale exponents are exact; no floating point in Core (rendering converts once).
- R-12 Scale exponent `s` multiplies edge length by φ^(−2s) (φ = golden ratio, itself in `Z[ζ]`); subdivision increments `s` by 1. Mixed scales may coexist only inside a subdivided region; placements must use `s = 0`.
- R-13 Overlap test (R-3) uses exact polygon intersection with orientation predicates evaluated in `Z[ζ]` by mapping to `Z[φ] × Z[φ]` real/imaginary parts and comparing signs via exact quadratic-integer sign tests.
- R-14 Vertex feasibility (R-3): the remaining angle at any vertex must be expressible as a sum of interior angles {72°, 108°, 144°, 216°} (precomputed table of feasible remainders in multiples of 36°: 0, 72, 108, 144, 180, 216, 252, 288, 324, 360 are feasible; 36° is never feasible).

**Placement extras**
- R-15 A placement that would create an enclosed hole (a region fully surrounded by tiles) that no tile combination can fill is illegal (hole check by tiling search up to 6 tiles; holes larger than that are allowed until enclosed).
- R-16 Placements off the visible board (radius 9 edges from centre) are illegal.

**Figures and scoring detail**
- R-17 Figure kinds and points (data): 10-point star 6, 5-point star 3, decagon rosette petal (kite) 1, pentagon 2, hexagon (elongated) 1, bowtie 1.
- R-18 A figure overlapping the board edge (strap leaves the tiled region) is open and cannot be claimed.
- R-19 Claimed figures are recorded with the ids of the tile set they overlap; if subdivision later changes those tiles, the claim is retained (R-9).
- R-20 Bonus: completing a 10-point star surrounded by ten 5-point petals (a full "rosette") scores +4 to the closer.

**Subdivision detail**
- R-21 Subdivision rules per tile kind are stored as exact templates (child kind, offset in `Z[ζ]`, rotation) in `subdivision.json`, derived from published schemes; a P1 test verifies templates by checking that children exactly cover the parent and strap lines match on the parent boundary.

### A.2 Additional Invariants
- INV-6 Cyclo10 arithmetic: ring axioms hold on 100,000 random triples; `ζ¹⁰ = 1`.
- INV-7 Subdivision templates cover the parent exactly (area equal; no overlap; boundary strap midpoints preserved).
- INV-8 Figure points equal the scoring table for every claimed figure (lint against data).
- INV-9 No placement leaves a 36° vertex remainder (R-14).

### A.3 Complete Schemas and Sample Rows

```swift
struct TileKindDef: Codable, Sendable { var id: TileKind; var vertices: [Cyclo10]; var straps: [StrapSegment]; var area: ZPhi }
struct StrapSegment: Codable, Hashable, Sendable { var a: Cyclo10; var b: Cyclo10 }
struct ZPhi: Codable, Hashable, Sendable { var a: Int; var b: Int }   // a + bφ
struct FigureKindDef: Codable, Sendable { var id: String; var points: Int; var signature: [Int]; var bonusRosette: Bool }
struct SubdivisionTemplate: Codable, Sendable { var parent: TileKind; var children: [ChildPlacement] }
struct ChildPlacement: Codable, Sendable { var kind: TileKind; var offset: Cyclo10; var rotation: Int }
```

```json
{ "id": "rhombus", "vertices": [[0,0,0,0],[1,0,0,0],[1,1,0,0],[0,1,0,0]], "area": [0, 1] }
{ "id": "star10", "points": 6, "signature": [36, 36, 36, 36, 36, 36, 36, 36, 36, 36], "bonusRosette": true }
{ "parent": "decagon", "children": [{"kind": "decagon", "offset": [0,0,0,0], "rotation": 0}, {"kind": "bowtie", "offset": [2,0,-1,0], "rotation": 1}] }
```

(Template rows are illustrative; P1 generates the real ones from the reference scheme and INV-7 verifies them.)

### A.4 Balance Tables and Sim Targets

| Parameter | Default | Range | Sim Target |
| --- | --- | --- | --- |
| Tiles per player | 18 | 14–22 | 10-point stars completed per game 2–5 |
| Market size | 6 | 4–8 | Discard-pass turns ≤ 5% |
| Bag mix (D/P/H/B/R) | 8/12/16/14/16 | — | Each kind placed ≥ 10% of placements |
| 10-star points | 6 | 4–8 | Star claims decide 30–50% of games |
| Rosette bonus | 4 | 2–6 | Rosettes in 10–30% of games |
| Subdivision | once per player | 0–2 | Used in 60–90% of Master games, adds 2–6 points |

P1 win 47–53% (Master vs Master, 2,000 games per bag variant).

### A.5 AI Design in Detail
- **Candidate placements:** for each market tile, every boundary edge × 10 rotations, filtered by exact overlap and feasibility; typical 50–300 candidates; top-k (24) by heuristic: immediate points + 0.6 × figures one tile from closure where area lead is ours − 0.6 × same for opponent.
- **Search:** alpha-beta depth 2 (Artisan), iterative deepening to time (Master and top tier) with chance ignored (market refill treated as unknown: evaluate after refill using expectation over the 5 kinds weighted by bag counts at depth 1 only).
- **Subdivision timing:** evaluated as a candidate each turn once ≥ 8 own tiles; take if gain ≥ 3.
- **Puzzles:** mine positions where a 2-move sequence completes a rosette; verify uniqueness.

### A.6 Granular Task Breakdown

| ID | Task | Acceptance Criteria |
| --- | --- | --- |
| GH-P0.1 | Cyclo10 and ZPhi exact arithmetic | INV-6 |
| GH-P0.2 | Tile kind geometry and straps | Snapshot of vertices; angles from data equal R-1 |
| GH-P1.1 | Exact overlap and edge sharing (R-3, R-13) | INV-1; 50 fixtures |
| GH-P1.2 | Vertex feasibility and holes (R-14, R-15) | INV-2, INV-9; 30 fixtures |
| GH-P1.3 | Strap graph and figure detection (R-7, R-17, R-18) | INV-3, INV-5 |
| GH-P1.4 | Claims and scoring (R-8, R-19, R-20) | INV-8 |
| GH-P1.5 | Subdivision templates (R-9, R-21) | INV-7 |
| GH-P2.1 | Metal renderer for tiles and straps (two styles: plain and banna'i-inspired) | 60 fps with 300 tiles |
| GH-P2.2 | Placement ghost with snap and rotation dial | Only legal placements commit |
| GH-P2.3 | Figure highlight and claim animation | Matches Core claims |
| GH-P3.1 | About: girih history, the disputed quasicrystal claim | Pending marks |
| GH-P4.1 | AI tiers | Gaps ≥ 75% |
| GH-P4.2 | Puzzle miner | 120 puzzles |
| GH-P5.1 | Bag variants and daily | 3 variants pass sims |

### A.7 Sharpened Gate Checks
- G1 adds: no Float in GHCore (import check) and INV-6/INV-7 green.
- G3 adds: About text states the Darb-i Imam interpretation is disputed.
- G5 adds: palette and patterns reviewed to avoid reproducing any specific monument's panel.

### A.8 Additional Risks

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Exact geometry bugs | Medium | High | Reference tests in a CAS (exported vertices checked offline) | GLM |
| Overclaiming medieval mathematics | Medium | Medium | Disputed-claim wording | GLM |
| Strap rendering aliasing at small scale | Medium | Medium | Signed-distance-field lines | GLM |

### A.9 Additional Open Questions (Defaults)
1. Name the top tier "Ustad"? Default: "Master"; use "ustad" only if advisors approve.
2. Show calligraphy borders? Default: never (no sacred text; secular calligraphy only with advisor approval).
3. Include a free-build sandbox? Default: post-launch (as §13).
