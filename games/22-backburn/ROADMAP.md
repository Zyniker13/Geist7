# 22 — Backburn Roadmap

> Read the wind, the slope, and the fuel, then fight fire with fire. A real-time-with-pause wildfire strategy game about crews, risk, and learning from the people who have managed fire for millennia.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 in full before starting. Depth pass (15 Nov 2026): Appendix A extends §4–§13 and wins where they differ. This roadmap adds only what is specific to Backburn.

Research: [`RESEARCH.md`](RESEARCH.md) (art direction, design lineage, cultural context, advisor institutions, verified glossary, and audio direction).

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 22 · `backburn` |
| Code prefix | `BB` (packages `BBCore`, `BBContent`, `BBAI`, `BBRender`, `BBAudio`, `BBPlatform`, `BBMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Real-time-with-pause wildfire management and campaign |
| Difficulty tier | Intermediate |
| Scope | Small team |
| Session length | 10–25 minutes per incident; multi-year campaign 6–10 hours |
| Renderer | Metal 4 (fire cellular automaton visualised on a topographic map; Core is a discrete grid) with SpriteKit units |
| Players | Solo |
| Simulation | Fixed 30 Hz tick, deterministic cellular automaton (integer), pausable |
| Sourcing tier | `FULL` (Indigenous cultural burning practices, for example Aboriginal Australian and Native American fire stewardship) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** see above.
- **Summary:** Each incident takes place on a 256 × 256 cell landscape with elevation, fuel type and load, moisture, and assets (homes, roads, water). A fire starts (lightning, sparks); the player commands crews (hand crews, engines, dozers, aircraft) to build control lines, wet lines, and to light backburns that consume fuel ahead of the main front. Fire spread follows a Rothermel-inspired integer cellular automaton: spread rate depends on fuel model, moisture, wind (direction and speed, which shifts on a forecast with uncertainty), and slope. Backburns can escape if lit with the wrong wind or too late. Spotting (embers ahead of the front) happens probabilistically on seeded RNG. Between incidents, the campaign spans years: the player plans prescribed burns and supports community-led cultural burns in partnership with Indigenous fire practitioners (as story and mechanics: mosaic burning reduces fuel loads and fire severity next season). Budget, crew fatigue, and community trust are the campaign resources.
- **Pillars:**
  1. **Fire is a system.** Predictable from physics, surprising from wind shifts.
  2. **Pause to plan.** Real time with pause and slow-motion; commands queue.
  3. **Prevention beats suppression.** The campaign rewards landscape care over heroics.
  4. **Indigenous knowledge respected.** Cultural burning is led by practitioners in story and credited partners in development; never a "power-up".
- **Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Topo paper `#F1EDE0`, contour brown `#9A7B55`, forest green `#4D6B3C`, grass `#B9B26A`, scrub `#7E8A55`, water `#5C8FB0`, fire orange `#F07A21`, flame yellow `#FFC93C`, ember red `#B3261E`, ash grey `#7D7A74`, retardant red `#C2345A`, crew yellow `#F2C200`. |
| Shapes | USGS-style topo map with contour lines; units as map symbols; fire front as animated line. |
| Typography | SF Pro and a map typeface (Avenir Next Condensed) for labels. |
| Motion | Fire spreads with flicker; smoke plume drifts with wind; time controls. |
| Music | Ambient tension (original); silent at pause. |
| SFX | Radio chatter (generic), crackle, aircraft, chainsaws. |
| Haptics | Rumble scaled to fire intensity near assets; tick on command confirmations. |

- **Inspirations:** Rothermel, "A Mathematical Model for Predicting Fire Spread" (USDA, 1972); Scott and Burgan fuel models (2005); FARSITE; Steffensen, "Fire Country" (2020); Firesticks Alliance; Lake and Christianson on Indigenous fire stewardship.

## 2. Tech Stack Decision

Per `_CONVENTIONS.md` §2, plus:
- **Simulation:** integer cellular automaton at 30 Hz; spread uses precomputed rate tables (fuel × moisture × wind class × slope class) in `Fixed`; elliptical spread approximated by 8-neighbour weighted ignition probabilities with deterministic accumulators (no RNG for basic spread; RNG only for spotting and wind gusts).
- **Determinism across devices:** all math in integers; Metal is used only for visuals (fire texture from Core grid).
- ADRs: ADR-0003 fire model; ADR-0004 tick and pause semantics; ADR-0005 cultural burning representation (advisor-led).

## 3. Repository Structure (Game-Specific Additions)

```
Packages/BBCore/Sources/BBCore/
  Landscape/  Grid.swift, Elevation.swift, Fuel.swift, Moisture.swift, Asset.swift
  Weather/    Wind.swift, Forecast.swift, Humidity.swift
  Fire/       FireCell.swift, Spread.swift, RateTables.swift, Spotting.swift, Intensity.swift
  Crews/      Unit.swift, UnitKind.swift, Orders.swift, Lines.swift, Backburn.swift, Fatigue.swift, Pathing.swift
  Campaign/   Season.swift, Budget.swift, Trust.swift, PrescribedBurn.swift, CulturalBurn.swift, Recovery.swift
  Engine/     GameState.swift, Action.swift, Event.swift, Reducer.swift, Tick.swift, Outcome.swift
Packages/BBContent/  MapDef.swift, FuelModelDef.swift, UnitDef.swift, IncidentDef.swift, CampaignDef.swift, Loader.swift
Packages/BBAI/       Advisor.swift (suggested lines), ForecastModel.swift, Autoplay.swift
Packages/BBRender/   TopoScene.swift, FireField.metal, SmokePlume.swift, UnitNode.swift, LineNode.swift
Packages/BBMeta/     Campaign.swift, Stats.swift, Replays.swift
Tools/MapBake/       (macOS tool: converts DEM and fuel rasters into map JSON + binary)
Resources/Content/   maps/*, fuels.json, units.json, incidents.json, campaigns.json, balance.json, tutorial.json, cultural_manifest.json
```

## 4. Core Rules Specification

**Landscape and fire**
- R-1 Each cell: elevation (m), fuel model (data, Scott and Burgan-like 13 classes), fuel load, moisture (%), state (unburned, burning(intensity, time), burned, fireline, wet).
- R-2 Spread per tick: each burning cell adds ignition progress to each neighbour = rate(fuel, moisture, wind component along direction, slope along direction) × tick; a neighbour ignites when progress ≥ threshold. Diagonal neighbours scale by 1/√2 via fixed table.
- R-3 Burnout: a cell burns for `residence(fuel)` ticks then becomes burned.
- R-4 Spotting: cells with intensity ≥ threshold emit embers with probability p per tick (seeded); landing distance sampled downwind; ignition if receptive.
- R-5 Wind: forecast for each hour with stated uncertainty; actual wind drawn from forecast distribution at incident start (seeded) and evolves.

**Crews and orders**
- R-6 Units have speed by terrain, line production rate, fatigue, and capabilities (hand crew: fireline; engine: wet line and protect asset; dozer: fast fireline in low fuel; air tanker: retardant drop with reload time).
- R-7 Orders: move, build line along path, protect asset, light backburn along line (requires an anchored line), drop retardant, rest. Orders queue and execute in ticks.
- R-8 Backburn: ignites a line of cells; behaves as fire; can escape if wind pushes it across the anchor line.
- R-9 Safety: units in cells adjacent to intensity ≥ threshold take danger; if danger accumulates, the unit is lost (campaign consequence); retreat orders automatic below threshold (toggle).

**Incident outcome**
- R-10 Incident ends when no burning cells remain or time limit; score: assets saved, area burned, unit losses, cost.

**Campaign**
- R-11 Years have seasons; off-season decisions: prescribed burns (place within weather windows), support cultural burns (with community partners; increases trust and reduces fuel in mosaic patterns), fuel reduction, crew training.
- R-12 Fuel regrowth each year by fuel model; burned areas recover over years.

**Invariants**
- INV-1 Fire simulation is deterministic and identical across 1,000 runs per seed.
- INV-2 Burned cells never reignite in the same incident.
- INV-3 Pause does not change outcomes (ticks identical with or without pausing).
- INV-4 Replay determinism.
- INV-5 Rate tables: spread rate monotonic in wind speed and slope (tests across all fuels).

## 5. Data Schemas and Content Tables

```swift
struct FuelModelDef: Codable, Sendable { var id: String; var baseRate: Fixed; var moistureExtinction: Int; var residence: Int; var regrowthYears: Int }
struct UnitDef: Codable, Sendable { var id: String; var speed: [Terrain: Fixed]; var lineRate: Fixed; var capacity: Int?; var reload: Int?; var cost: Int }
struct IncidentDef: Codable, Sendable { var id: String; var map: String; var ignition: [CellIndex]; var forecast: [WindForecast]; var assets: [AssetDef]; var timeLimit: Int; var units: [String] }
enum Action: Codable, Hashable { case order(UnitID, Order), cancel(UnitID), setSpeed(Int), pause, resume, planPrescribedBurn(Region), supportCulturalBurn(PartnerID, Region), endSeason }
```

| Table | G3 | G5 | Sample row |
| --- | --- | --- | --- |
| `maps/*` | 3 | 10 | baked from public DEM data (USGS 3DEP, Geoscience Australia) |
| `fuels.json` | 8 | 13 | `{ "id": "gr2", "baseRate": "0.35", "moistureExtinction": 15, "residence": 30, "regrowthYears": 1 }` |
| `units.json` | 5 | 8 | `{ "id": "hand_crew", "lineRate": "0.8", "cost": 3 }` |
| `incidents.json` | 12 | 40 | as schema |
| `campaigns.json` | 1 | 3 | regions inspired by California and southeastern Australia (fictionalised) |

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| Tick rate | 30 Hz | fixed | — |
| Spotting threshold and p | data | — | `balance.json` |
| Backburn escape sensitivity | data | — | `balance.json` |
| Crew fatigue rate | data | — | `units.json` |
| Fuel regrowth | per fuel | — | `fuels.json` |

Targets: autoplay "competent" saves ≥ 80% of assets on standard incidents; "naive" (no backburns) ≤ 50%; backburn escape in 10–20% of poorly timed burns and < 3% of well-timed; campaign with prescribed and cultural burns reduces average incident area by 30–50% versus suppression only.

## 7. AI Approach

- **Advisor:** proposes control lines by computing fire arrival time maps (Dijkstra on spread rates) and selecting lines that intercept before arrival with crew capacity; shown as suggestions.
- **Autoplay:** competent and naive policies for balance sims.

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7, SRC0.1, SRC0.2, HIST0.1 (Attested: Indigenous fire stewardship history; Rothermel model; Invented: scenarios).
- BB-P0.1 `Tools/MapBake` reads a small DEM and fuel raster and writes map files.

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; SRC0.1, SRC0.2, HIST0.1; MapBake produces a valid test map
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- BB-P1.1 Landscape, fire spread, burnout, spotting, wind (R-1 to R-5).
- BB-P1.2 Units, orders, lines, backburns, safety (R-6 to R-9); outcome (R-10).

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-10 tests; INV-1…INV-5
  [ ] 256×256 tick ≤ 4 ms on iPad (base) (≤ 12% of a 33 ms frame); BBCore coverage ≥ 90%
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5, SRC2.1, SRC2.2.
- BB-P2.1 Topo map scene with fire visualisation; unit selection; draw-a-line orders; pause and speed controls; forecast panel.
- BB-P2.2 Three incidents.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test completes an incident on iPad and Mac
  [ ] Pause invariance (INV-3) validated through UI-driven replays
  [ ] Manifest marks cultural burning content pending; deny-list passes
  [ ] `docs/SLICE_ASSESSMENT.md` written: self-assessment against the pillars, with every weakness turned into a P3 task (`_CONVENTIONS.md` §8.1)
Sign-off: GLM-SELF
```

### P3 Content and Systems
- BB-P3.1 G3 content; campaign years (R-11, R-12); About the Tradition (SRC3.1) with partner-written placeholders.
- BB-P3.2 Tutorial (6 incidents).

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts met; lint clean; 500 autoplay campaigns
Sign-off: GLM-SELF
```

### P4 AI (Advisor)
- BB-P4.1 Advisor; autoplay; `docs/BALANCE.md`.

```
GATE G4 — Advisor
Checks:
  [ ] Targets in §6 met; advisor suggestion ≤ 300 ms
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- BB-P5.1 G5 counts; replays; daily incident; 24 achievements; SRC5.1; HANDOFF.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Counts met; packet and HANDOFF complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- BB-P6.1 Metal fire field, smoke, topo art; SRC6.1 and SRC6.2 with Indigenous fire practitioners (for example via Firesticks Alliance or tribal fire programmes, arranged and paid by the maintainer through a `needs-maintainer` issue) and a fire scientist.
- BB-P6.2 Music and SFX.

```
GATE G6 — Aesthetics and Cultural Review
Checks:
  [ ] Advisor review filed as a `needs-maintainer` issue (SUBSTITUTED, `_SET2_ADDENDUM.md` §4); every entry still pending advisor review listed in that issue; 60 fps on base iPad with a large fire
Sign-off: GLM-SELF
```

### P7 Platform Features
- BB-P7.1 Game Center, iCloud; Pencil line drawing; Mac mouse and keyboard RTS controls.

```
GATE G7 — Platform
Checks:
  [ ] iCloud round-trip; Mac controls checklist
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- BB-P8.1 Fire intensity by pattern; slow-motion mode; VoiceOver incident summary and unit orders list; thermal budget tests.

```
GATE G8 — Polish
Checks:
  [ ] VoiceOver completes tutorial 1–2; thermal state stays ≤ fair over 20 minutes
Sign-off: GLM-SELF
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard tasks; SRC9.1 community playtest and SRC10.1 credits, each prepared locally and filed as a `needs-maintainer` issue; content warning for wildfire themes.

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

- **Fragile areas:** spotting distribution; backburn escape; performance at large fires.
- **Priorities for P6–P10:** Metal visuals, thermal budget; model realism review; cultural packet.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Trivialising real disasters | Medium | High | Respectful tone; no real named fires; content note | GLM |
| Tokenising Indigenous practice | Medium | High | Advisors and paid partners; practitioner-led framing | GLM |
| Performance | Medium | High | Integer CA, budgets | GLM |

## 11. Out of Scope

Real named fires; multiplayer; 3D terrain.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 3 |
| P1 | GLM | 9–12 |
| P2 | GLM | 7–10 |
| P3 | GLM | 7–10 |
| P4 | GLM | 4–6 |
| P5 | GLM | 4–6 |
| P6 | GLM | 10–13 |
| P7 | GLM | 3–5 |
| P8 | GLM | 4–6 |
| P9 | GLM | 5–7 |
| P10 | GLM | 2–3 |
| **Total** | | **58–81** |

## 13. Open Questions

1. Which regions for campaigns (Australia, California, both)? Default: both, fictionalised.

## 14. Sourcing Notes

- **Sources:** Rothermel (1972); Scott and Burgan, "Standard Fire Behavior Fuel Models" (RMRS-GTR-153, 2005); Steffensen, "Fire Country" (2020); Lake and Christianson, "Indigenous Fire Stewardship" (2019); Firesticks Alliance materials.
- **Restricted elements:** no sacred sites or ceremonies depicted; cultural burns shown as led by communities, with partner-written text.

## Appendix A. Extended Specification (Depth Pass)

### A.1 Additional Rules

**Spread model detail**
- R-13 Rate of spread per fuel model is precomputed offline from the Rothermel (1972) surface fire spread equations using Scott and Burgan (2005) fuel-model parameters, for a grid of (dead fuel moisture 2–30%, midflame wind 0–20 m/s, slope 0–100%), and stored as integer tables (cm/min) in `spread_tables.bin`. Core interpolates bilinearly in Fixed; no floating point at runtime.
- R-14 Wind and slope components along each of 8 directions use the "effective wind" vector sum (wind + slope-equivalent wind), with the elliptical spread shape approximated by a direction factor table (head 1.0, flanks per length-to-breadth ratio, back ≥ 0.05).
- R-15 Intensity (kW/m, Byram) per cell = heat content × fuel consumed × rate (table); used for crew danger, spotting, and suppression effectiveness bands (≤ 350 hand line holds; ≤ 1,700 engines and dozers; ≤ 3,500 aircraft only; above, indirect attack only — bands from common fire-behaviour guidance, labelled Reconstructed).
- R-16 Moisture changes hourly with the forecast (temperature and humidity drive dead fuel moisture via a lookup table); night recovery slows spread.
- R-17 Spotting distance: downwind distance sampled from a table by intensity and wind (max 1.5 km at launch), lateral spread ±15°; receptivity probability falls with moisture.

**Suppression detail**
- R-18 Fireline: a cell converted to `fireline` has fuel 0; fire cannot spread into it, but spotting can jump it; width 1 cell (8 m at default scale) — wider lines take more production.
- R-19 Wet line: blocks spread for `wetDuration` ticks, then reverts to moisture-boosted fuel.
- R-20 Retardant: reduces spread rate in covered cells by 80% for 2 hours; drop footprint 2 × 8 cells along flight path.
- R-21 Anchor: a backburn may be lit only from a line connected to a non-burnable anchor (road, water, rock, burned area) at one end.
- R-22 Unit fatigue: +1 per hour worked; at 12, the unit must rest 8 hours; work-rest ratios enforced (2:1 guidance, labelled Reconstructed).

**Campaign detail**
- R-23 Prescribed burn windows: allowed only when forecast wind ≤ 5 m/s and dead fuel moisture within the plan's band; escape chance evaluated by running the simulation (not a dice roll).
- R-24 Cultural burning partnership: community partners (fictional, written with advisor input) propose cool-burn mosaics in early dry season; the player chooses to support (resources, permits) — the game never lets the player direct cultural burns; partners decide where and when.
- R-25 Trust with partners rises when support is consistent and falls when the player overrides or delays; higher trust yields larger mosaic programmes.

### A.2 Additional Invariants
- INV-6 Spread tables monotonic in wind and slope and inversely in moisture (test across all entries).
- INV-7 Backburns never ignite without an anchored line (R-21).
- INV-8 Fireline cells never ignite by surface spread (spotting allowed).
- INV-9 The engine reproduces the reference spread rates of 5 fuel models within ±5% of values computed offline from the published equations (golden table).

### A.3 Complete Schemas and Sample Rows

```swift
struct FuelModelDef: Codable, Sendable { var code: String; var name: String; var loadTonsPerHa: [Int]; var depthCm: Int; var extinctionMoisture: Int; var residenceTicks: Int; var heatContent: Int; var label: HistoryLabel }
struct UnitDef: Codable, Sendable { var id: String; var kind: UnitKind; var speed: [Terrain: Int]; var lineRate: [String: Int] /* cells per hour by fuel group */; var capabilities: [Capability]; var cost: Int }
struct WeatherForecast: Codable, Sendable { var hours: [HourForecast] }
struct HourForecast: Codable, Sendable { var windDir: Int; var windSpeed: Int; var windSpread: Int; var tempC: Int; var rh: Int }
struct IncidentDef: Codable, Sendable { var id: String; var map: String; var ignition: [CellRef]; var forecast: String; var timeLimitHours: Int; var assets: [AssetDef]; var units: [String] }
struct PartnerDef: Codable, Sendable { var id: String; var name: String; var region: String; var trust: Int; var textKey: String; var reviewed: Bool }
```

```json
{ "code": "GR2", "name": "Low load, dry climate grass", "loadTonsPerHa": [2, 0, 0, 2, 0], "depthCm": 30, "extinctionMoisture": 15, "residenceTicks": 2, "heatContent": 18600, "label": "Attested" }
{ "id": "engine_t3", "kind": "engine", "speed": {"road": 12, "grass": 4, "shrub": 2}, "lineRate": {"grass": 20, "shrub": 8}, "capabilities": ["wetLine", "protectAsset"], "cost": 6 }
{ "windDir": 270, "windSpeed": 7, "windSpread": 2, "tempC": 34, "rh": 12 }
{ "id": "partner_ridge", "name": "(fictional) Ridge Country Rangers", "region": "north", "trust": 40, "textKey": "partner.ridge", "reviewed": false }
```

GR2 parameters above are placeholders shaped like Scott and Burgan entries; P1 copies the real values from RMRS-GTR-153 Table 7 and cites them.

### A.4 Balance Tables and Sim Targets

| Parameter | Default | Range | Target |
| --- | --- | --- | --- |
| Cell size | 8 m | 5–15 m | 256² map covers ~4 km² |
| Tick | 1 min | — | Full incident 2–12 game hours |
| Spotting probability scale | 1.0 | 0.5–1.5 | Spot fires in 30–60% of high-wind incidents |
| Crew line rate (hand, grass) | 6 cells/h | — | Competent policy contains moderate incidents ≥ 80% |
| Backburn escape | emergent | — | Naive backburns escape in 20–40% of high-wind attempts |
| Mosaic programme effect | emergent | — | 10-year campaign with partner support reduces large-fire area 30–60% vs none |

### A.5 AI Design in Detail
- **Arrival-time map:** Dijkstra over 8-neighbour grid with travel time = cell size / directional spread rate at forecast wind; recomputed every 10 game minutes.
- **Line planner:** candidate lines are iso-arrival contours at T + safety margin, clipped to anchors; choose the contour whose required production (sum of cell costs by fuel) ≤ available crew production before arrival; propose the plan with expected assets saved.
- **Competent autoplay:** follow planner, protect assets with engines, backburn only with anchors and wind ≤ 6 m/s toward the main fire.
- **Naive autoplay:** direct attack at the head regardless of intensity.

### A.6 Granular Task Breakdown

| ID | Task | Acceptance Criteria |
| --- | --- | --- |
| BB-P0.1 | Offline tool: spread tables from published equations | INV-9 golden table |
| BB-P1.1 | Landscape loader (elevation, fuel, assets) | 3 test maps load |
| BB-P1.2 | Spread, burnout, wind and slope (R-2, R-3, R-13, R-14) | INV-1, INV-5, INV-6 |
| BB-P1.3 | Intensity bands and spotting (R-4, R-15, R-17) | 15 fixtures |
| BB-P1.4 | Moisture and weather (R-5, R-16) | 10 fixtures |
| BB-P1.5 | Units, orders, fatigue (R-6, R-7, R-22) | 20 fixtures |
| BB-P1.6 | Lines, wet lines, retardant, backburn (R-8, R-18–R-21) | INV-7, INV-8 |
| BB-P1.7 | Safety and outcome (R-9, R-10) | 10 fixtures |
| BB-P1.8 | Campaign: regrowth, prescribed burns, partners (R-11, R-12, R-23–R-25) | 10-year replay test |
| BB-P2.1 | Metal fire renderer with ember particles | 60 fps on 256² |
| BB-P2.2 | Order drawing (paths) and arrival-time overlay | Matches Core |
| BB-P3.1 | 8 incidents, 13 fuel models, 6 unit kinds | Lint; citations |
| BB-P3.2 | Partner text placeholders, marked unreviewed | needs-maintainer issue filed for advisor review |
| BB-P4.1 | Planner and autoplay | Targets met |
| BB-P5.1 | Campaign mode | 10-year sims in range |

### A.7 Sharpened Gate Checks
- G1 adds: INV-9 golden-table agreement; 1,000-run determinism per seed.
- G3 adds: partner text flagged unreviewed in data; a needs-maintainer issue exists for advisor review.
- G5 adds: About screen credits sources and states the model is simplified and not for operational use.

### A.8 Additional Risks

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Players treat the game as operational guidance | Low | High | Disclaimer; simplified-model labels | GLM |
| Cultural burning shown as a player tool | Medium | High | Partner-led framing (R-24); advisor review issue | GLM |
| Simulation cost on older devices | Medium | Medium | Active-region updates only | GLM |

### A.9 Additional Open Questions (Defaults)
1. Real places? Default: fictional landscapes inspired by Australian and Californian fire regimes.
2. Show casualties? Default: units are "withdrawn injured", never killed on screen.
3. Name partners after real organisations? Default: no; fictional, with real organisations credited in About only with permission.
