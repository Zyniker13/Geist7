# 23 — Stratum Roadmap

> Every site is a history written in layers, and digging destroys the page as you read it. Deduce the past before a rival team does.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 in full before starting. Depth pass (15 Nov 2026): Appendix A extends §4–§13 and wins where they differ. This roadmap adds only what is specific to Stratum.

Research: [`RESEARCH.md`](RESEARCH.md) (art direction, design lineage, cultural context, advisor institutions, verified glossary, and audio direction).

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 23 · `stratum` |
| Code prefix | `ST` (packages `STCore`, `STContent`, `STAI`, `STRender`, `STAudio`, `STPlatform`, `STMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Stratigraphic deduction strategy (solo, with a rival dig AI) |
| Difficulty tier | Intermediate |
| Scope | Solo-indie |
| Session length | 20–40 minutes per site |
| Renderer | SpriteKit section-view (cross-section) and plan-view grid; SwiftUI Harris matrix editor |
| Players | Solo vs rival dig AI; daily site |
| Simulation | Procedural site histories (seeded); turn-based excavation |
| Sourcing tier | `NONE` (fictional sites; archaeological method credited; HIST labels on any cultural material types) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** see above.
- **Summary:** A generator simulates a site's history over centuries: deposition events (floors, fills, collapses, flood silts), cuts (pits, postholes, trenches, robber trenches), and artefacts with type-dated ranges (pottery styles, coins). The result is a 3D voxel volume (e.g., 12 × 12 × 20). The player has a limited number of excavation actions per season: open a trench (plan area), take down a context (remove one stratigraphic unit within the trench), section (reveal a vertical face), sample (radiocarbon or flotation at a cost), and record. Removed material is gone; recording captures it. The player builds a Harris matrix (a directed graph of "above/below/cuts") from observations and assigns phases and dates. At the end of the season, the player submits an interpretation: phase sequence, dates, and site function per phase. Score compares with the true history (graph edit distance on the matrix, date accuracy, function correctness). A rival team works another part of the site and publishes first if faster; their findings can be used (but may be wrong).
- **Pillars:**
  1. **Deduction under destruction.** Every dig action is irreversible; plan before you dig.
  2. **Real method.** Harris matrix, law of superposition, terminus post quem, residuality.
  3. **Generated histories, fair puzzles.** Every site is solvable from observable evidence.
  4. **Calm intellectual tension.** Soft palette, field-notebook UI.
- **Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Soils: topsoil `#4A3B2C`, clay `#9C6B44`, silt `#B9A07A`, sand `#D8C49A`, ash `#8E8A84`, charcoal `#2E2B28`, chalk `#E6E0D2`; notebook paper `#F5F0E3`, pencil `#3A3A3A`, label red `#B03A2E`. |
| Shapes | Section drawings with hatching conventions; context sheets; matrix boxes and lines. |
| Typography | SF Pro; handwritten-style labels (Noteworthy, system). |
| Motion | Trowel scraping animations; layers lift away; matrix edges snap. |
| Music | Light acoustic guitar and field ambience (original). |
| SFX | Trowel scrape, sieve shake, bird song, wind. |
| Haptics | Scrape texture; tap when a find appears. |

- **Inspirations:** Harris, "Principles of Archaeological Stratigraphy" (2nd ed., 1989); MoLAS "Archaeological Site Manual" (1994); Renfrew and Bahn, "Archaeology: Theories, Methods and Practice"; Return of the Obra Dinn (deduction structure).

## 2. Tech Stack Decision

Per `_CONVENTIONS.md` §2, plus:
- **Generator:** event-driven history producing a voxel grid of context IDs plus a truth Harris matrix; validation ensures each true relationship is observable through at least one sequence of legal digs.
- **Matrix editor:** SwiftUI graph editor with auto-layout (layered, Sugiyama-style) and cycle detection.
- ADRs: ADR-0003 site generator; ADR-0004 scoring (graph edit distance with weights); ADR-0005 observability guarantee.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/STCore/Sources/STCore/
  Site/      Voxel.swift, Context.swift, ContextKind.swift, Artefact.swift, Volume.swift
  History/   Event.swift, Generator.swift, TruthMatrix.swift, Observability.swift
  Dig/       Trench.swift, TakeDown.swift, Section.swift, Sample.swift, Record.swift, Season.swift
  Interpret/ Matrix.swift, Phase.swift, Dating.swift, Interpretation.swift, Scoring.swift
  Rival/     RivalDig.swift, Publication.swift
  Engine/    GameState.swift, PlayerView.swift, Action.swift, EventLog.swift, Reducer.swift
Packages/STContent/  ContextKindDef.swift, ArtefactTypeDef.swift, SiteTemplateDef.swift, Loader.swift
Packages/STAI/       RivalPolicy.swift, Hint.swift, AutoSolver.swift (for validation)
Packages/STRender/   SectionScene.swift, PlanScene.swift, MatrixEditor.swift, SoilShader.fsh
Packages/STMeta/     Career.swift, DailySite.swift, Stats.swift
Resources/Content/   contexts.json, artefacts.json, templates.json, balance.json, tutorial.json
```

## 4. Core Rules Specification

**Site generation**
- R-1 A template sets period range, event mix (settlement, abandonment, flood, burial ground excluded (see §11), industry), and size.
- R-2 Events in chronological order deposit layers (covering existing surfaces) or cut features (removing material, later filled). Artefacts are assigned to contexts with type date ranges; residual artefacts (older, redeposited) and intrusive ones (younger, via cuts) occur per data.

**Excavation**
- R-3 Season budget: action points (default 40).
- R-4 Open trench (cost by area); only inside trenches can contexts be taken down.
- R-5 Take down: remove the uppermost exposed context within the trench footprint (the topmost voxel set of a single context); reveals finds within it and the surfaces beneath. If the player takes down a context that is actually lower than an unexcavated cut fill (mis-identified), the generator still enforces physical order: only exposed contexts can be removed.
- R-6 Section: reveal a vertical face along a trench edge (cost), showing context boundaries in that plane.
- R-7 Sample: radiocarbon gives a date range with calibrated uncertainty (seeded); flotation reveals function hints (seeds, slag).
- R-8 Record: free; stores observations of contexts (colour, composition, finds, relationships seen).

**Interpretation and scoring**
- R-9 The player builds a matrix of recorded contexts with relations (above, below, cuts, same-as) and groups into phases with date ranges and functions.
- R-10 Score = 100 − weighted graph edit distance to the truth (restricted to excavated contexts) + date accuracy + function points + coverage bonus − rival priority penalty.

**Rival**
- R-11 The rival digs adjacent areas with a policy; at season end, publishes a matrix fragment and dates (possibly wrong). If the rival publishes a correct phase before you, your score for that phase halves.

**Invariants**
- INV-1 Generated sites satisfy observability (ADR-0005): every true relation among contexts within the default dig area is inferable from some legal sequence of actions within 1.5× the budget.
- INV-2 Physical order: only exposed contexts can be removed.
- INV-3 PlayerView reveals only recorded or currently exposed information.
- INV-4 Replay determinism.
- INV-5 Truth matrix is acyclic; player matrix editor prevents cycles.

## 5. Data Schemas and Content Tables

```swift
struct Context: Codable, Hashable, Sendable { var id: Int; var kind: ContextKind; var soil: SoilType; var period: ClosedRange<Int>; var finds: [ArtefactID] }
struct Relation: Codable, Hashable, Sendable { var upper: Int; var lower: Int; var kind: RelationKind }
enum Action: Codable, Hashable { case openTrench(Rect), takeDown(TrenchID), section(TrenchID, Edge), sample(ContextID, SampleKind), record(ContextID, Observation), addRelation(Relation), removeRelation(Relation), setPhase(ContextID, PhaseID), submit }
```

| Table | G3 | G5 | Sample row |
| --- | --- | --- | --- |
| `contexts.json` | 14 kinds | 24 | `{ "id": "posthole_fill", "soil": "dark_silt", "cutBy": "posthole_cut" }` |
| `artefacts.json` | 30 types | 70 | `{ "id": "ware_redslip_b", "date": [120, 260], "residualRate": 10, "label": "Invented" }` |
| `templates.json` | 5 | 14 | `{ "id": "riverside_farm", "periods": [0, 900], "events": {"floor": 6, "pit": 4, "flood": 2} }` |

Artefact types are invented wares with plausible features (labelled Invented) to avoid misrepresenting real cultures.

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| Action points per season | 40 | 30–60 | `balance.json` |
| Radiocarbon σ | 40 years | 20–80 | `balance.json` |
| Residual rate | 10% | 0–25% | `artefacts.json` |
| Rival speed | 1.0 | 0.6–1.4 | `balance.json` |

Targets: AutoSolver (optimal-ish policy) scores 85–95; random-dig bot ≤ 40; median human 60–80 (playtest estimate); rival publishes first on 20–40% of phases for median play.

## 7. AI Approach

- **Rival policy:** greedy information gain per action (expected relations revealed) with noise.
- **AutoSolver:** for validation only; information-gain planner plus exact matrix inference.
- **Hints:** suggest the next most informative action.

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7; HIST0.1 optional (method Attested; sites Invented).

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- ST-P1.1 Generator, truth matrix, observability (R-1, R-2; INV-1, INV-5).
- ST-P1.2 Excavation actions (R-3 to R-8); PlayerView.
- ST-P1.3 Interpretation and scoring (R-9, R-10); rival (R-11).

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-11 tests; INV-1…INV-5 over 5,000 generated sites
  [ ] Generation ≤ 200 ms; STCore coverage ≥ 90%
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5.
- ST-P2.1 Plan view grid and section view; trench drawing; take-down; context sheet; matrix editor with auto-layout; submit and score report comparing with truth.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test completes a site on iPad and Mac
  [ ] Score report matches Core scoring
  [ ] `docs/SLICE_ASSESSMENT.md` written: self-assessment against the pillars, with every weakness turned into a P3 task (`_CONVENTIONS.md` §8.1)
Sign-off: GLM-SELF
```

### P3 Content and Systems
- ST-P3.1 G3 content; tutorial (5 sites teaching superposition, cuts, residuality, dating, phasing).

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts met; lint clean; tutorial UI test
Sign-off: GLM-SELF
```

### P4 AI (Rival and Hints)
- ST-P4.1 Rival policy; AutoSolver; hints; `docs/BALANCE.md`.

```
GATE G4 — AI
Checks:
  [ ] Targets in §6 met; hint ≤ 500 ms
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- ST-P5.1 G5 counts; career (multi-season sites, reputation); daily site; 20 achievements; HANDOFF.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Counts met; daily deterministic; HANDOFF complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- ST-P6.1 Soil shaders; section drawing style; finds art (invented wares).
- ST-P6.2 Music and SFX; archaeologist review of method (optional consultant).

```
GATE G6 — Aesthetics
Checks:
  [ ] Snapshots approved; method review notes addressed
Sign-off: GLM-SELF
```

### P7 Platform Features
- ST-P7.1 Game Center (daily site leaderboard), iCloud; Pencil sketching notes on the context sheet.

```
GATE G7 — Platform
Checks:
  [ ] iCloud round-trip; daily leaderboard submits
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- ST-P8.1 Soils distinguished by texture pattern and label; VoiceOver matrix editor (list of relations); section view descriptions.

```
GATE G8 — Polish
Checks:
  [ ] VoiceOver completes tutorial site 1; budgets met
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

### Key Test Fixtures (GLM Writes These in P1)

1. Take-down removes only the uppermost exposed context in the trench.
2. A cut feature's fill cannot be removed before the layers above it.
3. Section reveals boundaries only along the chosen trench edge.
4. Residual artefact in a later context does not change the truth date of that context.
5. Matrix editor rejects an edge that creates a cycle.
6. Perfect interpretation scores 100 before rival penalties.
7. Observability check passes for 5,000 generated sites.
8. PlayerView never includes unexcavated context IDs.

## 9. Fragile Areas and Priorities

- **Fragile areas:** observability validation; scoring weights.
- **Priorities for P6–P10:** matrix editor UX; generator variety, method accuracy.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Unfair generated sites | Medium | High | Observability guarantee; AutoSolver CI | GLM |
| Matrix editor intimidating | High | Medium | Auto-relations from records; tutorial | GLM |

## 11. Out of Scope

Human burials (ethical choice: no excavation of human remains); real archaeological sites; multiplayer.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 2 |
| P1 | GLM | 7–9 |
| P2 | GLM | 6–8 |
| P3 | GLM | 4–6 |
| P4 | GLM | 3–5 |
| P5 | GLM | 3–5 |
| P6 | GLM | 6–8 |
| P7 | GLM | 2–4 |
| P8 | GLM | 3–5 |
| P9 | GLM | 4–6 |
| P10 | GLM | 2–3 |
| **Total** | | **42–61** |

## 13. Open Questions

1. Keep sites fully fictional, or add real-period flavour (Roman Britain)? Default: fictional.

## Appendix A. Extended Specification (Depth Pass)

### A.1 Additional Rules

**Generator detail**
- R-12 Time runs in years from the template's start; events are drawn from a seeded Poisson-like schedule per event kind (integer rates per century).
- R-13 Deposition: a layer event covers every exposed surface voxel within its footprint (polygon) to a thickness of 1–3 voxels, sloping with an optional gradient; flood silts cover all low areas below a level.
- R-14 Cuts: a cut removes voxels within a shape (pit: cylinder; posthole: small cylinder; trench: linear; robber trench: follows a former wall) and is immediately or later filled by 1–3 fill contexts. Each cut is itself a context (the interface) with relations "cuts" to every context it truncates.
- R-15 Artefacts: each context receives finds from the period's assemblage with type date ranges (`artefacts.json`); residual finds (5–20%, data) come from earlier periods; intrusive finds arise only in contexts cut by later features (contamination at cut edges, 2–5%).
- R-16 Radiocarbon samples exist only in contexts with organics; the result is a calibrated range (±40–120 years at 95%, seeded) around the true date of the organic material, which may be older than the context (old-wood effect, data).

**Excavation detail**
- R-17 Trench costs: 1 action point per 4 m² (at 1 voxel = 0.5 m); extending a trench costs the area added.
- R-18 Take down (R-5) costs 1 point per 8 voxels removed (min 1).
- R-19 Sections cost 2 points per trench edge; reveal boundaries in that plane only for contexts already exposed or adjacent to the trench.
- R-20 Misidentification: if the player declares two contexts "same as" incorrectly, the matrix records it; the truth checker counts it as an error but the physical model is unaffected.
- R-21 Season end: unexcavated areas are backfilled; next season (campaign) re-opening costs half.

**Interpretation detail**
- R-22 Graph edit distance (R-10): relation edges inserted, deleted, or mislabelled cost 1; mis-grouped phases cost 2 per context; computed on the transitive reduction of both matrices (the Harris matrix convention).
- R-23 Date accuracy: phase date range overlaps the true range by Jaccard index ≥ 0.5 → full points; scaled below.

### A.2 Additional Invariants
- INV-6 The truth matrix equals the transitive reduction of the generator's physical order (property test).
- INV-7 Every cut context truncates at least one earlier context or the natural (lint).
- INV-8 Intrusive finds only appear in contexts physically adjacent to a later cut.
- INV-9 Radiocarbon ranges always contain the true organic date at the stated probability in 10,000-sample tests (coverage 93–97%).

### A.3 Complete Schemas and Sample Rows

```swift
struct TemplateDef: Codable, Sendable { var id: String; var startYear: Int; var endYear: Int; var size: [Int]; var eventRates: [EventKind: Int]; var assemblage: [String]; var label: HistoryLabel }
struct ContextTruth: Sendable { var id: Int; var kind: ContextKind; var voxels: Set<Voxel>; var dateRange: ClosedRange<Int>; var function: String; var colour: Int; var composition: String }
struct ArtefactDef: Codable, Sendable { var id: String; var type: String; var from: Int; var to: Int; var label: HistoryLabel }
struct Relation: Codable, Hashable, Sendable { var a: Int; var b: Int; var kind: RelationKind /* above, cuts, sameAs */ }
struct PlayerMatrix: Codable, Sendable { var contexts: [Int: ContextRecord]; var relations: Set<Relation>; var phases: [PhaseRecord] }
struct C14Result: Codable, Sendable { var context: Int; var from: Int; var to: Int; var confidence: Int }
```

```json
{ "id": "river_town", "startYear": 100, "endYear": 1500, "size": [12, 12, 20], "eventRates": {"floor": 6, "fill": 8, "pit": 10, "posthole": 14, "flood": 2, "collapse": 1}, "assemblage": ["greyware", "redslip", "glazed_a", "coin_b"], "label": "Invented" }
{ "id": "glazed_a", "type": "pottery", "from": 1150, "to": 1350, "label": "Invented" }
{ "a": 14, "b": 9, "kind": "cuts" }
{ "context": 22, "from": 1180, "to": 1290, "confidence": 95 }
```

### A.4 Balance Tables and Sim Targets

| Parameter | Default | Range | Target |
| --- | --- | --- | --- |
| Season action points | 40 | 30–60 | AutoSolver recovers ≥ 90% of relations in the dig area with 1.5× budget (INV-1) |
| Residual finds | 10% | 5–20% | Naive dating by latest find errs in 20–40% of contexts |
| Intrusive finds | 3% | 2–5% | ≥ 1 intrusive find per site in 60–90% of sites |
| C14 uncertainty | ±40–120 | — | C14 used 2–4 times per season by AutoSolver |
| Rival speed | 0.8× player budget | 0.5–1.2 | Rival scoops ≥ 1 phase in 20–40% of naive games |

### A.5 AI Design in Detail
- **Information gain:** for each candidate action (take down, section, sample), estimate expected number of unknown relations resolved using the posterior over possible matrices consistent with observations (sampled via 200 random consistent orders).
- **Rival:** greedy on information gain with noise; publishes phases when its confidence ≥ 70%; sometimes wrong (by design).
- **AutoSolver:** full information-gain planner with exact inference; used in CI to verify INV-1 for every template and 1,000 seeds.
- **Hints:** top action by information gain with a one-line rationale.

### A.6 Granular Task Breakdown

| ID | Task | Acceptance Criteria |
| --- | --- | --- |
| ST-P1.1 | Voxel volume and generator events (R-1, R-2, R-12–R-14) | INV-6, INV-7 |
| ST-P1.2 | Artefacts, residual, intrusive (R-15) | INV-8 |
| ST-P1.3 | Radiocarbon model (R-7, R-16) | INV-9 |
| ST-P1.4 | Trenches, take down, sections (R-3–R-6, R-17–R-19) | INV-2, INV-3 |
| ST-P1.5 | Matrix editor model and scoring (R-9, R-10, R-20, R-22, R-23) | INV-5; 20 fixtures |
| ST-P1.6 | Rival and seasons (R-11, R-21) | 10 fixtures |
| ST-P2.1 | Voxel renderer with section cutaways | 60 fps at 12 × 12 × 20 |
| ST-P2.2 | Harris matrix editor (drag relations) | Cycles prevented |
| ST-P2.3 | Finds tray and recording sheets | Matches PlayerView |
| ST-P3.1 | 3 templates, 40 artefact types | Lint; INV-1 sims |
| ST-P4.1 | AutoSolver and hints | INV-1 for all templates |
| ST-P5.1 | Campaign of 6 sites | Seeds verified |

### A.7 Sharpened Gate Checks
- G1 adds: INV-1 verified on 1,000 seeds per template; INV-9 coverage.
- G3 adds: no human remains in any template (lint against §11 exclusion).
- G5 adds: tutorial teaches the Harris matrix with a 6-context example.

### A.8 Additional Risks

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Generator creates unobservable relations | Medium | High | INV-1 CI check | GLM |
| Matrix editor is hard on iPhone | High | Medium | iPad-first; iPhone list view | GLM |
| Archaeologists object to simplifications | Low | Low | About lists simplifications | GLM |

### A.9 Additional Open Questions (Defaults)
1. Real periods (Roman, medieval)? Default: invented assemblages with plausible date spans.
2. Show "context sheets" in the style of a real recording system? Default: generic sheets, credited as inspired by single-context recording.
3. Multiplayer race mode? Default: post-launch.
