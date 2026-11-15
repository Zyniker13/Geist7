# 11 — Vienna Method Roadmap

> Plan Red Vienna's welfare city in pictograms: every figure is a thousand people, and the chart is the city.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 in full before starting. Depth pass (15 Nov 2026): Appendix A extends §4–§13 and wins where they differ. This roadmap adds only what is specific to Vienna Method.

Research: [`RESEARCH.md`](RESEARCH.md) (art direction, design lineage, cultural context, advisor institutions, verified glossary, and audio direction).

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 11 · `vienna-method` |
| Code prefix | `VM` (packages `VMCore`, `VMContent`, `VMAI`, `VMRender`, `VMAudio`, `VMPlatform`, `VMMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Infographic city-planning puzzle-strategy |
| Difficulty tier | Intermediate |
| Scope | Solo-indie |
| Session length | 20–40 minutes per scenario; endless mode |
| Renderer | SwiftUI (Canvas) only; vector pictograms |
| Players | Solo |
| Simulation | Turn-based (yearly turns) deterministic model |
| Sourcing tier | `NONE` (Isotype is a design method; credit Otto Neurath, Marie Neurath (Reidemeister), and Gerd Arntz; Red Vienna history labelled where used) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** see above.
- **Summary:** The game board is an Isotype chart. Rows represent life domains (Housing, Work, Schooling, Health, and Leisure) and columns represent districts (8 to 12). Each figure stands for 1,000 people, coloured by need status (served, underserved, unserved). Each year the player builds institutions (housing blocks (Gemeindebauten-style), clinics, schools, baths, libraries, workshops) by placing them onto the chart; institutions convert unserved figures into served ones within their row and district, sometimes spilling to neighbours. Budget comes from a progressive tax lever (higher rates raise money but reduce "Work" figures in some districts). Events (influenza, unemployment, migration) add or shift figures. Score is served figures per year with a final audit chart; scenarios target specific goals (for example "house 60,000 within 8 years"). The chart is all there is: no 3D city, no map; the visualisation is the gameplay, and it remains fully accessible to VoiceOver as data.
- **Pillars:**
  1. **The chart is the world.** Every rule is visible as figures moving in rows.
  2. **Count, don't guess.** Figures are countable; there are no hidden numbers.
  3. **Accessible by design.** Every chart is a data table under VoiceOver and audio graph.
  4. **Credit the method.** Isotype rules (one figure equals a fixed quantity; more is more figures, never bigger figures) are followed and credited.
- **Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Paper `#F2EEE3`, ink black `#1B1B1B`, Isotype red `#C33C2E`, blue `#2D5D8C`, green `#4E7D46`, ochre `#D2A23A`, grey `#8D8D8D`. Served figures solid ink, underserved outlined, unserved red. |
| Shapes | Pictograms in the Arntz tradition: flat silhouettes, no perspective, consistent stroke; all original drawings. |
| Typography | Futura (system) as in Isotype charts; SF Mono for numbers. |
| Motion | Figures slide between status columns in grid steps; no easing flourish. |
| Music | Light Viennese chamber pieces (public-domain repertoire, new recordings or licensed) or silence. |
| SFX | Rubber stamp, typewriter, chart pin. |
| Haptics | Tick per 10 figures converted. |

- **Inspirations:** Neurath, "International Picture Language" (1936); Arntz pictogram archive; Isotype Revisited (University of Reading); Blau, "The Architecture of Red Vienna 1919–1934".

## 2. Tech Stack Decision

Per `_CONVENTIONS.md` §2, plus:
- **SwiftUI Canvas** only (no SpriteKit) for a crisp vector chart; Audio Graphs (`AXChart`) for accessibility.
- **Model:** integer people counts (figures = floor(count / 1000) with a remainder shown as a partial figure, a cut figure as Isotype allowed).
- ADRs: ADR-0003 SwiftUI-only rendering; ADR-0004 model equations; ADR-0005 Isotype rules as lint (no scaled figures).

## 3. Repository Structure (Game-Specific Additions)

```
Packages/VMCore/Sources/VMCore/
  Model/   District.swift, Domain.swift, Population.swift, Need.swift, Institution.swift, Coverage.swift, Budget.swift, Tax.swift
  Engine/  GameState.swift, Action.swift, Event.swift, Reducer.swift, Year.swift, Score.swift, Audit.swift
Packages/VMContent/  ScenarioDef.swift, InstitutionDef.swift, EventDef.swift, PictogramDef.swift, Loader.swift
Packages/VMAI/       Planner.swift (greedy and beam search for scenario solvability), Advisor.swift
Packages/VMRender/   ChartView.swift, Figure.swift, Pictograms/ (SVG paths compiled to Swift Paths), AudioGraph.swift
Packages/VMMeta/     Scenarios.swift, Endless.swift, Stats.swift
Resources/Content/   scenarios.json, institutions.json, events.json, pictograms.json, balance.json, tutorial.json
```

## 4. Core Rules Specification

**Model**
- R-1 Each district d has population counts per domain row: `need[d][row]` split into served, underserved, and unserved.
- R-2 Institutions have type, row, capacity (people served), cost, upkeep, build time (years), and spill (fraction of capacity applied to adjacent districts, adjacency in data).
- R-3 Coverage each year: for each row and district, served = min(need, capacity in district + spill from neighbours); underserved = up to 50% of remaining if a lesser institution exists; rest unserved.

**Year turn**
- R-4 Phase order: (1) Event draw (seeded deck of events); (2) Player actions: set tax rate (0–5 steps), build institutions (cost paid now, completed after build time), close institutions (refund 0); (3) Upkeep; (4) Growth and migration: each district grows by its rate; unserved Housing figures cause migration outward to districts with spare housing; (5) Coverage (R-3); (6) Score.
- R-5 Budget: revenue = Σ taxable Work figures × tax rate × base; negative budget not allowed (actions blocked).
- R-6 Tax side effect: tax steps above 3 reduce Work by 1% per step in districts tagged "industrial".
- R-7 Score per year: Σ served figures + 0.5 × underserved; final scenario score adds scenario goal bonuses.

**Scenarios**
- R-8 Each scenario defines districts, starting population, budget, event deck, years, and goals (threshold goals per row or district).

**Invariants**
- INV-1 Population counts never negative; conservation under migration.
- INV-2 Coverage is order-independent across districts.
- INV-3 Every rendered figure count equals floor(count/1000) (rendering test reads the model).
- INV-4 Replay determinism.
- INV-5 Every scenario is solvable by the planner at its "bronze" goal.

## 5. Data Schemas and Content Tables

```swift
struct InstitutionDef: Codable, Sendable { var id: String; var row: Domain; var capacity: Int; var cost: Int; var upkeep: Int; var buildYears: Int; var spill: Int /* percent */; var pictogram: String; var label: HistoryLabel? }
struct ScenarioDef: Codable, Sendable { var id: String; var districts: [DistrictDef]; var years: Int; var budget: Int; var events: [String]; var goals: [GoalDef]; var label: HistoryLabel? }
enum Action: Codable, Hashable { case setTax(Int), build(InstitutionID, district: Int), close(BuildingID), endYear }
```

| Table | G3 | G5 | Sample row |
| --- | --- | --- | --- |
| `institutions.json` | 10 | 18 | `{ "id": "gemeindebau", "row": "housing", "capacity": 4000, "cost": 9, "upkeep": 1, "buildYears": 2, "spill": 0, "pictogram": "block" }` |
| `scenarios.json` | 6 | 16 | `{ "id": "housing_drive", "years": 8, "goals": [{"row":"housing","served":60000,"tier":"bronze"}], "label": "Reconstructed" }` |
| `events.json` | 12 | 30 | `{ "id": "influenza", "effect": {"row":"health","unserved":"+3000"}, "label": "Attested" }` |
| `pictograms.json` | 20 | 40 | original vector paths |

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| People per figure | 1000 | fixed | `balance.json` |
| Tax base | 1 per 10 Work figures per step | — | `balance.json` |
| Growth rate | 1% per year | 0–3% | `scenarios.json` |
| Underserved credit | 0.5 | 0.25–0.75 | `balance.json` |

Targets: planner beam (width 32) achieves gold on 50–70% of scenarios; greedy bot achieves bronze on ≥ 90% and gold on ≤ 20%; median scenario 20–40 minutes for humans (estimated 8–12 years × 2–3 minutes).

## 7. AI Approach

- No opponent. The planner verifies solvability and tunes goals (bronze, silver, gold) from its results.
- The Advisor button suggests the action with the best one-year marginal score (greedy), with a short explanation.

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7; HIST0.1 (optional here but required because scenarios reference Red Vienna: Attested: Gemeindebauten programme, Karl-Marx-Hof, Isotype; Invented: numbers and rules).
- VM-P0.1 Credit page drafted: Otto Neurath, Marie Neurath, Gerd Arntz, Isotype Institute; pictograms are original and not traced.

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; HIST0.1 and credit page complete
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- VM-P1.1 Model and year turn (R-1 to R-8); INV-1 to INV-4.

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-8 tests; invariants over 5,000 seeds
  [ ] VMCore coverage ≥ 90%; make sim N=1000 deterministic
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5.
- VM-P2.1 Chart view with figures; drag institution cards onto row × district cells; tax lever; End Year animation; audit chart.
- VM-P2.2 VoiceOver data table and Audio Graph from day one.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test completes a scenario on iPad and Mac
  [ ] VoiceOver UI test reads every cell's counts correctly
  [ ] Isotype lint: no figure scaled; fixed figure unit
  [ ] `docs/SLICE_ASSESSMENT.md` written: self-assessment against the pillars, with every weakness turned into a P3 task (`_CONVENTIONS.md` §8.1)
Sign-off: GLM-SELF
```

### P3 Content and Systems
- VM-P3.1 G3 scenarios, institutions, events; HIST3.1 labels.
- VM-P3.2 Tutorial (4 lessons); Advisor.

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts met; lint clean; every scenario passes INV-5
Sign-off: GLM-SELF
```

### P4 AI (Planner)
- VM-P4.1 Beam planner; goal tiers auto-tuned; `docs/BALANCE.md`.

```
GATE G4 — Planner
Checks:
  [ ] Targets in §6 met; planner run per scenario < 30 s on CI
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- VM-P5.1 G5 counts; endless mode (seeded districts); daily scenario; 20 achievements; HANDOFF.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Counts met; daily deterministic; HANDOFF complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- VM-P6.1 Full pictogram set (commissioned illustrator, Isotype style, original); print-like paper texture; HIST6.1.
- VM-P6.2 Music (public-domain works, licensed recordings) and SFX.

```
GATE G6 — Aesthetics
Checks:
  [ ] Snapshots approved; pictogram originality statement from illustrator; HIST6.1 clean
Sign-off: GLM-SELF
```

### P7 Platform Features
- VM-P7.1 Game Center (scenario scores), iCloud; export an audit chart as image or PDF.
- VM-P7.2 Mac keyboard and menu commands.

```
GATE G7 — Platform
Checks:
  [ ] Export works; iCloud round-trip
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- VM-P8.1 Served, underserved, and unserved shown by fill and outline, not colour alone; Dynamic Type; Switch Control.

```
GATE G8 — Polish
Checks:
  [ ] VoiceOver completes a scenario; Switch Control completes tutorial; budgets met
Sign-off: GLM-SELF
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard tasks; prepare a VoiceOver-only scripted playthrough and file a `needs-maintainer` issue for testing with blind and low-vision players.

```
GATE G9 — Beta
Checks:
  [ ] Crash-free ≥ 99.5%; accessibility feedback addressed
Sign-off: GLM-SELF
GATE G10 — Release
Checks:
  [ ] Store assets; final CI green
Sign-off: GLM-SELF
```

### Key Test Fixtures (GLM Writes These in P1)

1. Coverage with zero institutions: all need is unserved.
2. A clinic with capacity 3,000 in district 2 serves exactly 3,000 Health need there; spill of 20% serves 600 in each adjacent district.
3. Migration: 4,000 unserved Housing in district 1 with 2,000 spare housing in district 3 moves 2,000 people.
4. Budget block: building with insufficient funds is rejected with reason `insufficientFunds`.
5. Tax step 5 reduces Work by 2% in industrial districts only.
6. Figure rendering: 12,500 people renders 12 full figures and one half figure.
7. Scenario `housing_drive` is solvable at bronze by the greedy planner.
8. VoiceOver table: cell labels match model counts for every row and district.

## 9. Fragile Areas and Priorities

- **Fragile areas:** migration ordering, spill adjacency.
- **Priorities for P6–P10:** chart rendering performance at 12 districts × 5 rows, Audio Graphs; scenario goals and history labels.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Too dry | Medium | High | Events, goals, satisfying figure motion | GLM |
| Political reading of Red Vienna | Medium | Medium | Neutral history text, labels | GLM |
| Pictogram too close to Arntz originals | Low | High | Commissioned originals; statement | GLM |

## 11. Out of Scope

Map-based city view; multiplayer; real census data import.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 1–2 |
| P1 | GLM | 4–6 |
| P2 | GLM | 5–7 |
| P3 | GLM | 4–6 |
| P4 | GLM | 3–4 |
| P5 | GLM | 3–4 |
| P6 | GLM | 5–8 |
| P7 | GLM | 2–4 |
| P8 | GLM | 3–5 |
| P9 | GLM | 3–5 |
| P10 | GLM | 2–3 |
| **Total** | | **35–54** |

## 13. Open Questions

1. Set scenarios explicitly in 1920s Vienna, or a generic interwar city? Default: Vienna with labelled history.
2. Add German localisation at launch? Default: yes.

## Appendix A. Extended Specification (Depth Pass)

### A.1 Additional Rules

**Population model**
- R-9 Each district holds integer `people[d][row]` for the need in that row (housing, work, schooling, health, leisure). Housing need equals population; work need equals working-age population (60% of population, data); schooling need equals 15%; health need equals population × health factor (default 20%); leisure need equals 40%.
- R-10 All counts are integers (people); figures are `people / 1000` rounded down for display (INV-3). Half figures display as a half-width pictogram when the remainder is ≥ 500 (Isotype practice of partial symbols), never other fractions.
- R-11 Growth (R-4 step 4): `pop' = pop + floor(pop × rate / 100)`; deterministic, no RNG.
- R-12 Migration: for each district with unserved housing `u > 0`, move `floor(u / 2)` people to neighbours with spare housing capacity, split in proportion to spare capacity (largest remainder method for integers, ties by district index).

**Institutions**
- R-13 Lesser institutions (for underserved, R-3): each row has a "lesser" type (e.g., tenement repair for housing, outpatient post for health). Underserved credit only arises from lesser types.
- R-14 Spill (R-2): `spill%` of capacity applies to each neighbouring district, but total served from spill per district ≤ 30% of that district's need.
- R-15 Build queue: at most 3 builds started per year (data per scenario); builds in progress cost upkeep 0 until complete.
- R-16 Closure refunds nothing and takes effect at the start of the next year (served counts drop then).

**Budget and taxes**
- R-17 Revenue (R-5) uses Fixed Q32.32 for the base and rounds down to whole budget units each year.
- R-18 Loans: a scenario may allow one loan of up to 2 years' revenue; repaid at 10% per year starting the year after; a loan cannot be taken if one is outstanding.

**Events and goals**
- R-19 Events draw from the seeded deck at year start; each event effect uses a closed DSL (`needDelta`, `budgetDelta`, `growthDelta`, `capacityDelta`, `blockBuild`).
- R-20 Goal tiers: bronze, silver, gold; scenario score counts the highest tier met for each goal (bronze 1, silver 2, gold 3).
- R-21 Chart mode: the player may switch the board between "Isotype chart" (rows × districts) and "map" (districts only); actions are identical.

### A.2 Additional Invariants
- INV-6 Migration conserves total population (INV-1 extended).
- INV-7 Spill never serves more than 30% of a district's need (R-14).
- INV-8 Figure rendering uses only whole and half pictograms (R-10).
- INV-9 Goal tiers are monotonic: gold thresholds ≥ silver ≥ bronze (lint).

### A.3 Complete Schemas and Sample Rows

```swift
struct DistrictDef: Codable, Sendable { var id: Int; var name: String; var population: Int; var tags: [String]; var neighbours: [Int]; var growth: Int }
struct GoalDef: Codable, Sendable { var row: Domain?; var district: Int?; var metric: GoalMetric; var bronze: Int; var silver: Int; var gold: Int }
enum GoalMetric: String, Codable, Sendable { case servedPeople, servedShare, budgetEnd, unservedMax }
struct EventDef: Codable, Sendable { var id: String; var effects: [EventEffect]; var weight: Int; var label: HistoryLabel?; var textKey: String }
enum EventEffect: Codable, Sendable { case needDelta(Domain, Int, district: Int?), budgetDelta(Int), growthDelta(Int, years: Int), capacityDelta(String, Int), blockBuild(Domain, years: Int) }
struct YearReport: Codable, Sendable { var year: Int; var served: [Domain: Int]; var underserved: [Domain: Int]; var unserved: [Domain: Int]; var budget: Int; var score: Int }
```

```json
{ "id": 4, "name": "Riverside", "population": 38000, "tags": ["industrial"], "neighbours": [3, 5, 9], "growth": 2 }
{ "row": "housing", "metric": "servedShare", "bronze": 50, "silver": 65, "gold": 80 }
{ "id": "flu_wave", "effects": [{"needDelta": ["health", 3000, null]}], "weight": 2, "label": "Attested", "textKey": "ev.flu_wave" }
{ "id": "outpatient_post", "row": "health", "capacity": 1500, "cost": 2, "upkeep": 1, "buildYears": 0, "spill": 10, "pictogram": "cross_small", "lesser": true }
```

`label: Attested` on an event means the type of event (an influenza wave) is attested for interwar cities, not that the game's numbers are historical.

### A.4 Balance Tables and Sim Targets

| Parameter | Default | Range | Sim Target |
| --- | --- | --- | --- |
| Builds per year | 3 | 2–4 | Players hit build cap in 40–70% of years |
| Health factor | 20% | 10–30% | Health row is binding in ≥ 2 scenarios |
| Spill cap | 30% | 20–40% | Spill provides 5–20% of total served |
| Migration factor | 1/2 | 1/3–2/3 | Migration changes ≥ 1 district's ranking in 50% of games |
| Loan size | 2× revenue | 1–3× | Loans taken in 20–40% of planner gold runs |
| Underserved credit | 0.5 | 0.25–0.75 | Lesser institutions ≤ 35% of builds in gold runs |

Planner protocol: beam width 32 over full action sets per year with 200 seeds per scenario; record bronze/silver/gold rates; set tiers so gold is reached in 50–70% of planner runs and silver in 85–95%.

### A.5 AI Design in Detail
- **Planner:** beam search over years; per year, candidates are combinations of ≤ 3 builds (pruned to top 12 single builds by marginal score) plus tax settings {current −1, current, +1}; state value = cumulative score + heuristic (unserved housing × −0.3 + budget × 0.1).
- **Advisor (greedy):** evaluates every single build and tax step by simulating one year; shows the top choice with "why": the rows and districts that change, in figures.
- **Goal tuner:** runs the planner and greedy bot, then sets bronze = greedy p50, silver = planner p25, gold = planner p60, rounded to the nearest 1,000 or 5% (stored and recorded in `docs/BALANCE.md`).

### A.6 Granular Task Breakdown

| ID | Task | Acceptance Criteria |
| --- | --- | --- |
| VM-P0.1 | Pictogram style guide (Isotype rules: same size, repeat for quantity, no perspective) | Checklist self-check by GLM recorded in `docs/STATUS.md` |
| VM-P1.1 | Population and needs (R-1, R-9, R-10) | INV-1, INV-3 |
| VM-P1.2 | Coverage, lesser institutions, spill (R-3, R-13, R-14) | INV-2, INV-7; 30 fixtures |
| VM-P1.3 | Growth and migration (R-11, R-12) | INV-6; 20 fixtures |
| VM-P1.4 | Budget, taxes, loans (R-5, R-6, R-17, R-18) | 20 fixtures |
| VM-P1.5 | Build queue and closure (R-15, R-16) | 15 fixtures |
| VM-P1.6 | Events DSL and goals (R-19, R-20) | INV-9 |
| VM-P2.1 | Isotype chart renderer (whole and half figures) | INV-8; snapshot tests |
| VM-P2.2 | Map mode toggle (R-21) | Same model, two views |
| VM-P2.3 | Year report as an Isotype sheet | Matches YearReport |
| VM-P3.1 | 6 scenarios, 10 institutions, 12 events | Lint; INV-5 |
| VM-P3.2 | Tutorial: reading an Isotype chart | UI test |
| VM-P4.1 | Planner and goal tuner | Tier rules above |
| VM-P4.2 | Advisor explanations | Every suggestion shows changed rows |
| VM-P5.1 | Scenario editor (Mac) | Exports valid scenarios |

### A.7 Sharpened Gate Checks
- G1 adds: 1,000 random years conserve population exactly; coverage order-independence property test.
- G2 adds: VoiceOver and the value inspector read three chart values that match the model (UI test); the human reading-speed check is SUBSTITUTED per `_CONVENTIONS.md` §8.2.
- G3 adds: all pictograms original (no copies from Isotype archives); style guide compliance checklist.

### A.8 Additional Risks

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Pictograms too close to Arntz originals | Medium | High | Original drawing; side-by-side review | GLM |
| Political reading of "Red Vienna" | Medium | Medium | Labelled history; About explains Isotype's civic-education origins without partisan framing | GLM |
| Spreadsheet feel | Medium | Medium | Strong chart animation and year-end sheets | GLM |

### A.9 Additional Open Questions (Defaults)
1. Name the city? Default: as §13 (1920s Vienna with labelled history); districts may be simplified, and the simplification is stated in About.
2. Allow custom pictogram colours? Default: no; fixed Isotype-like palette for legibility.
3. Include an Isotype history gallery? Default: links only, with University of Reading credit.

### A.10 Scenario Catalogue (G3 Six, G5 Sixteen)

| ID | Title | Years | Districts | Binding Constraint | Gold Goal (Placeholder Until Tuner) | Teaches |
| --- | --- | --- | --- | --- | --- | --- |
| first_chart | Reading the Chart | 3 | 4 | none | 70% housing served | Rows, columns, figures |
| housing_drive | The Housing Drive | 8 | 8 | housing and budget | 80% housing served | Build queue, taxes |
| baths_and_schools | Baths and Schools | 8 | 8 | health and schooling | 75% in both rows | Lesser institutions |
| river_works | River Works | 10 | 10 | migration | ≤ 5,000 unserved housing in any district | Migration and spill |
| lean_years | Lean Years | 10 | 10 | budget shocks | budget ≥ 0 every year and 60% overall | Loans and event risk |
| twelve_districts | Twelve Districts | 12 | 12 | all rows | 70% in every row | Whole system |

### A.11 Institution Catalogue (G3)

| ID | Row | Capacity | Cost | Upkeep | Build Years | Spill | Lesser |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| housing_block | housing | 4,000 | 9 | 1 | 2 | 0% | no |
| tenement_repair | housing | 1,500 | 2 | 0 | 0 | 0% | yes |
| clinic | health | 5,000 | 6 | 2 | 1 | 15% | no |
| outpatient_post | health | 1,500 | 2 | 1 | 0 | 10% | yes |
| school | schooling | 2,000 | 5 | 1 | 1 | 10% | no |
| reading_room | schooling | 800 | 1 | 0 | 0 | 20% | yes |
| workshop | work | 3,000 | 5 | 0 | 1 | 0% | no |
| baths | leisure | 6,000 | 4 | 1 | 1 | 25% | no |
| library | leisure | 4,000 | 3 | 1 | 1 | 20% | no |
| park | leisure | 3,000 | 2 | 0 | 0 | 30% | yes |

### A.12 Key Test Fixtures (Extended)
- **Spill cap:** district need 10,000 health, own capacity 0, two neighbours each with a 5,000 clinic at 15% spill → spill offered 1,500, capped at 3,000 total; served = 1,500.
- **Migration split:** unserved housing 4,000 → 2,000 move; neighbours with spare 3,000 and 1,000 receive 1,500 and 500.
- **Half figure:** 12,600 people → 12 whole figures and 1 half figure; 12,400 → 12 whole figures.
- **Tax side effect:** tax step 5 in an industrial district with 30,000 work → work reduced by 2% (steps 4 and 5) to 29,400.
