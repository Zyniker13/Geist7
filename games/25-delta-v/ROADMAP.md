# 25 — Delta-v Roadmap

> Run a space agency on a budget: stage rockets, plan burns with the Pencil, park fuel in orbit, and beat a rival agency to the Moon and beyond.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 in full before starting. Depth pass (15 Nov 2026): Appendix A extends §4–§13 and wins where they differ. This roadmap adds only what is specific to Delta-v.

Research: [`RESEARCH.md`](RESEARCH.md) (art direction, design lineage, cultural context, advisor institutions, verified glossary, and audio direction).

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 25 · `delta-v` |
| Code prefix | `DV` (packages `DVCore`, `DVContent`, `DVAI`, `DVRender`, `DVAudio`, `DVPlatform`, `DVMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Orbital logistics and agency-management strategy |
| Difficulty tier | Hardcore |
| Scope | Larger team |
| Session length | 1–3 hours per campaign chapter; saves anywhere |
| Renderer | Metal 4 for orbit plots and blueprint shading; SwiftUI panels (VAB, budget, mission planner) |
| Players | Solo vs rival agency AI |
| Simulation | Patched-conic two-body orbital mechanics in fixed point; turn-based in months with time-warp mission execution |
| Sourcing tier | `NONE` (fictional agencies; real physics; HIST labels optional for space-race flavour) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** see above.
- **Summary:** The player directs a fictional space agency from the first orbit to crewed landings and outer-planet probes in a simplified solar system (Sun, Earth, Moon, Mars and moons, Venus, an asteroid belt, Jupiter system). Rockets are assembled from stages (engines with thrust and specific impulse, tanks, payloads) in the vehicle assembly view; the rocket equation gives delta-v per stage. Missions are planned on an orbit map using maneuver nodes: place a node on an orbit and set prograde, normal, and radial components; the Pencil Pro's barrel roll rotates the burn direction, and squeeze toggles node types. Transfers (Hohmann, bi-elliptic, gravity assists) emerge from the physics. Orbital depots let later missions refuel, the core logistics puzzle: building infrastructure that makes future missions cheaper. Each year the budget arrives based on prestige and public interest; failures cost both. A rival agency pursues milestones (first satellite, first crew, first lunar landing); being first earns prestige bonuses.
- **Pillars:**
  1. **Real orbital mechanics, gentle on-ramp.** Patched conics, exact enough to teach real intuition; assist tools for beginners.
  2. **Logistics is strategy.** Depots, reusable stages, and launch windows decide the race.
  3. **Plan, then commit.** Missions are planned in full, then executed with time warp and contingencies.
  4. **Blueprint beauty.** Diazo blueprint aesthetic with crisp orbit lines.
- **Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Diazo blue `#1F3F77`, blueprint line `#E8F0FA`, cyan highlights `#7FD3F7`, warning amber `#F2B33D`, failure red `#E0533D`, success green `#6CCB8A`, paper white for panels `#F4F6F8`, graphite `#2B2F36`. |
| Shapes | Technical drawings: rocket elevations with dimension lines, orbit ellipses with annotated apsides, mission timelines as Gantt bars. |
| Typography | DIN-like (D-DIN, OFL) and SF Mono for numbers. |
| Motion | Orbits draw as pen strokes; time warp blurs; staging separation animations. |
| Music | Analog-synth ambient (original). |
| SFX | Teletype, countdown voice (generic), engine rumble, relay clicks. |
| Haptics | Countdown ticks; heavy rumble at liftoff; precise detents while adjusting nodes. |

- **Inspirations:** Kerbal Space Program; Bate, Mueller, and White, "Fundamentals of Astrodynamics" (1971); Curtis, "Orbital Mechanics for Engineering Students"; NASA Technical Reports on propellant depots; High Frontier (Eklund) for logistics abstraction.

## 2. Tech Stack Decision

Per `_CONVENTIONS.md` §2, plus:
- **Orbital model:** patched conics in fixed point (Q32.32 insufficient for solar-system scales; use `Fixed128` (Q64.64) for positions and velocities; ADR-0004); Kepler's equation solved by Newton iterations with fixed iteration counts (deterministic); sphere-of-influence transitions computed by root finding with fixed steps.
- **Maneuvers:** impulsive burns (instantaneous Δv) at nodes; finite-burn losses approximated by a gravity-loss table for launches only.
- **Launch model:** ascent abstracted: Δv to low orbit from a table by launch site and vehicle thrust-to-weight.
- **Performance:** trajectory prediction for 10 bodies × 5 patches ≤ 8 ms on iPad (base).
- ADRs: ADR-0003 patched conics scope; ADR-0004 Fixed128 numeric format; ADR-0005 Pencil interaction model; ADR-0006 budget and prestige model.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/DVCore/Sources/DVCore/
  Math/       Fixed128.swift, Vec3F.swift, TrigTables.swift, Kepler.swift
  Orbits/     Body.swift, Orbit.swift (elements), StateVector.swift, Propagate.swift, SOI.swift, Patch.swift, Transfer.swift
  Vehicles/   Part.swift, Engine.swift, Tank.swift, Stage.swift, Vehicle.swift, RocketEquation.swift
  Missions/   Mission.swift, ManeuverNode.swift, Plan.swift, Execution.swift, Contingency.swift, Depot.swift, Docking.swift
  Agency/     Budget.swift, Prestige.swift, Research.swift, Facilities.swift, Crew.swift, Milestone.swift, Rival.swift
  Engine/     GameState.swift, Action.swift, Event.swift, Reducer.swift, Month.swift, Score.swift
Packages/DVContent/  BodyDef.swift, PartDef.swift, TechDef.swift, MilestoneDef.swift, ChapterDef.swift, Loader.swift, Validation.swift
Packages/DVAI/       RivalAgency.swift, MissionPlannerAssist.swift (Lambert solver, porkchop), Autoplay.swift
Packages/DVRender/   OrbitMap.metal, OrbitMapView.swift, VABView.swift, PorkchopView.swift, TimelineView.swift
Packages/DVMeta/     Campaign.swift, Sandbox.swift, Stats.swift
Resources/Content/   bodies.json, parts.json, tech.json, milestones.json, chapters.json, balance.json, tutorial.json
```

## 4. Core Rules Specification

**Physics**
- R-1 Bodies follow fixed Keplerian orbits (on-rails) with elements from `bodies.json` (simplified real values).
- R-2 Spacecraft follow two-body orbits around the current primary; at SOI boundaries, state is converted to the new primary (patched conics).
- R-3 A maneuver node applies Δv instantly at its time: components prograde, normal, radial. Fuel consumed per the rocket equation: m₁ = m₀ · exp(−Δv / (Isp · g₀)) using fixed-point exp table.
- R-4 Launch: Δv to orbit from table (site latitude, target inclination, TWR class) plus gravity losses; failure chance per engine reliability (seeded).

**Vehicles**
- R-5 A vehicle is a stack of stages; each stage has engines and tanks; staging is explicit in the plan. Total Δv computed per stage with payload above.

**Missions**
- R-6 Plan = launch + sequence of nodes + events (dock, refuel, land, return). Validation: Δv sufficient for each stage, landings require Δv ≥ table value for body, return windows exist.
- R-7 Execution: missions execute in time-warp across months; contingencies (engine failure, leak) trigger with reliability-based chance; the player can respond with replanning if Δv margin exists.
- R-8 Depots: stationary orbital tanks; docking requires matching orbits (plan includes rendezvous node); refuel transfers propellant subject to boil-off per month for cryogenic fuels.

**Agency**
- R-9 Budget per year = base + prestige × factor; spending: parts R&D, facilities, crew, missions.
- R-10 Prestige from milestones (first-ever doubles), science returned, and depot infrastructure; lost by failures (crew loss heavy).
- R-11 Rival agency pursues the milestone list on its own budget; milestones taken by the rival first give the player reduced prestige.

**Invariants**
- INV-1 Energy and angular momentum are conserved along coast arcs within fixed-point tolerance (relative error ≤ 1e-9 over one orbit).
- INV-2 SOI transitions continuous in position (≤ 1 m) and velocity (≤ 1 mm/s) after frame conversion.
- INV-3 Fuel never negative; rocket equation consistent across plan and execution.
- INV-4 Replay determinism (including contingencies).
- INV-5 Lambert solver results validated by propagation to target within tolerance.

## 5. Data Schemas and Content Tables

```swift
struct BodyDef: Codable, Sendable { var id: String; var mu: Fixed128; var radius: Fixed128; var soi: Fixed128; var parent: String?; var elements: OrbitalElements; var landingDV: Int; var atmosphere: Bool }
struct PartDef: Codable, Sendable { var id: String; var kind: PartKind; var mass: Int; var thrust: Int?; var isp: Int?; var capacity: Int?; var reliability: Int; var cost: Int; var tech: String; var cryogenic: Bool }
struct ManeuverNode: Codable, Hashable, Sendable { var time: Int64; var prograde: Fixed128; var normal: Fixed128; var radial: Fixed128 }
enum Action: Codable, Hashable { case designVehicle(VehicleDesign), research(TechID), buildFacility(FacilityID), planMission(MissionPlan), launch(MissionID), replan(MissionID, MissionPlan), buildDepot(DepotPlan), advanceMonth }
```

| Table | G3 | G5 | Sample row |
| --- | --- | --- | --- |
| `bodies.json` | 4 (Sun, Earth, Moon, Mars) | 12 | `{ "id": "moon", "mu": "4.9048695e12", "radius": "1737400", "soi": "66100000", "parent": "earth", "landingDV": 1730 }` |
| `parts.json` | 30 | 80 | `{ "id": "eng_hypergolic_s", "kind": "engine", "mass": 900, "thrust": 120000, "isp": 311, "reliability": 97, "cost": 8, "tech": "t_hypergolics" }` |
| `tech.json` | 20 | 50 | tech tree nodes |
| `milestones.json` | 12 | 30 | `{ "id": "first_lunar_landing", "prestige": 40, "firstBonus": 2.0 }` |
| `chapters.json` | 2 | 5 | campaign chapters (Orbit, Moon, Depots, Mars, Outer System) |

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| Base budget | 100 | 60–150 | `balance.json` |
| Prestige factor | 1.0 | 0.5–2 | `balance.json` |
| Boil-off per month | 1% | 0–3% | `balance.json` |
| Rival aggression | data | — | `balance.json` |
| Engine reliability ranges | 90–99% | — | `parts.json` |

Targets: autoplay "competent" reaches first lunar landing in 6–10 game years; rival takes 30–60% of "first" milestones against median play; depots reduce Mars mission cost by 25–40%; mission failure rate 5–15% for competent designs.

## 7. AI Approach

- **Rival agency:** milestone-driven planner with data-defined budgets and research priorities; uses the same physics and planner tools (Lambert solver, porkchop search) to schedule missions at launch windows.
- **Mission planner assist:** Lambert solver for transfers, porkchop plots, auto-circularise, and "suggest node" helpers (players can rely on assists at Easy).
- **Autoplay:** competent and naive policies for balance sims.

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7.
- DV-P0.1 `Fixed128` type with arithmetic, sqrt, sin/cos, exp, ln tables (high-precision), and exhaustive tests against Decimal references in tests only.

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; Fixed128 tests pass
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- DV-P1.1 Kepler propagation, elements, state vectors, SOI patches (R-1, R-2; INV-1, INV-2).
- DV-P1.2 Maneuvers, rocket equation, vehicles, staging (R-3, R-5; INV-3).
- DV-P1.3 Missions, execution, contingencies, depots (R-4, R-6 to R-8).
- DV-P1.4 Agency: budget, prestige, research, rival hooks (R-9 to R-11).

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-11 tests; INV-1…INV-5
  [ ] Hohmann Earth→Moon fixture within 0.5% of analytic Δv; Earth→Mars transfer time within 1% of textbook value
  [ ] Prediction ≤ 8 ms; DVCore coverage ≥ 90%; make sim N=200 deterministic
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5.
- DV-P2.1 Orbit map (Metal) with zoom across scales, node placement and drag handles; Pencil Pro barrel roll rotates burn direction and squeeze toggles node palette (with finger fallbacks).
- DV-P2.2 VAB: stage stacking with Δv readout; launch; time warp; mission timeline.
- DV-P2.3 Chapter 1 slice: first orbit and first lunar flyby.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test completes chapter 1 slice on iPad and Mac
  [ ] Plan Δv equals executed Δv (no drift) on 100 scripted missions
  [ ] `docs/SLICE_ASSESSMENT.md` written: self-assessment against the pillars, with every weakness turned into a P3 task (`_CONVENTIONS.md` §8.1)
Sign-off: GLM-SELF
```

### P3 Content and Systems
- DV-P3.1 G3 content; tech tree; facilities; crew.
- DV-P3.2 Tutorial (8 lessons: orbits, prograde and retrograde, inclination, transfers, staging, rendezvous, depots, windows).
- DV-P3.3 Save anywhere; sandbox mode.

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts met; lint clean; 200 autoplay campaigns complete
Sign-off: GLM-SELF
```

### P4 AI (Rival and Assists)
- DV-P4.1 Rival agency; Lambert solver; porkchop; assists; `docs/BALANCE.md`.

```
GATE G4 — AI
Checks:
  [ ] Targets in §6 met; porkchop 64×64 grid ≤ 1.5 s
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- DV-P5.1 G5 counts (5 chapters, 12 bodies); challenge missions; stats; 30 achievements; HANDOFF.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Counts met; coverage thresholds; HANDOFF complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- DV-P6.1 Blueprint shader; rocket elevation drawings generated from part data; planet line-art.
- DV-P6.2 Music and SFX.

```
GATE G6 — Aesthetics
Checks:
  [ ] Snapshots approved; 120 fps orbit map on iPad Pro
Sign-off: GLM-SELF
```

### P7 Platform Features
- DV-P7.1 Pencil Pro and Apple Pencil hover for node previews; Mac precision controls (scroll to adjust node components, modifier keys for fine steps); multiple windows (VAB, map, timeline).
- DV-P7.2 iCloud; Game Center (challenge leaderboards: least Δv).

```
GATE G7 — Platform
Checks:
  [ ] Pencil interactions and fallbacks checklist; multi-window verified; iCloud round-trip
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- DV-P8.1 VoiceOver mission planner (numeric entry for nodes, spoken orbit parameters); colour-independent status; Dynamic Type for panels.
- DV-P8.2 Battery and thermal budgets during long time warps.

```
GATE G8 — Polish
Checks:
  [ ] VoiceOver completes tutorial lessons 1–3; budgets met
Sign-off: GLM-SELF
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard tasks; beta with space-sim players.

```
GATE G9 — Beta
Checks:
  [ ] Crash-free ≥ 99.5%; physics bug reports triaged
Sign-off: GLM-SELF
GATE G10 — Release
Checks:
  [ ] Store assets; final CI green
Sign-off: GLM-SELF
```

## 9. Fragile Areas and Priorities

- **Fragile areas:** Fixed128 performance; SOI transitions near boundaries; Lambert edge cases (180° transfers).
- **Priorities for P6–P10:** orbit map renderer, Pencil interaction; campaign pacing, rival tuning.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Compared unfavourably with KSP | High | Medium | Logistics and agency focus; iPad-native planning | GLM |
| Numeric precision bugs | Medium | High | Fixed128, invariants, fixtures | GLM |
| Steep learning curve | High | High | Assists, tutorials, Easy mode | GLM |
| Scope | High | High | Chapter gating, strict GLM stop | GLM |

## 11. Out of Scope

N-body physics; atmospheric flight simulation; real agencies; multiplayer.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 3–4 |
| P1 | GLM | 16–22 |
| P2 | GLM | 12–16 |
| P3 | GLM | 9–12 |
| P4 | GLM | 8–11 |
| P5 | GLM | 6–8 |
| P6 | GLM | 9–12 |
| P7 | GLM | 7–10 |
| P8 | GLM | 5–7 |
| P9 | GLM | 6–9 |
| P10 | GLM | 2–3 |
| **Total** | | **83–114** |

## 13. Open Questions

1. Include a historical space-race scenario with labelled history? Default: post-launch.
2. Real solar system values or a slightly scaled system? Default: real values with simplified elements.

## Appendix A. Extended Specification (Depth Pass)

### A.1 Additional Rules

**Physics detail**
- R-12 Units: metres, seconds, kilograms; positions stored as Fixed Q32.32 metres relative to the current primary only (heliocentric distances exceed Q32.32 integer range at metre resolution, so heliocentric states use a scaled frame of 1 unit = 1 km, ADR-0004).
- R-13 Kepler's equation is solved by Newton iteration in fixed point with a fixed iteration count (8) and a starting guess table; hyperbolic orbits use the hyperbolic form.
- R-14 SOI radius r_SOI = a · (m/M)^(2/5) precomputed per body (stored in `bodies.json`).
- R-15 Maneuver burns are impulsive; a "finite burn" warning appears when burn time at current thrust exceeds 5% of orbital period (cosmetic at launch).
- R-16 Landing Δv table per body (from surface to low orbit and back), plus atmospheric landing via heat shield for Earth, Mars, and Venus (no Δv needed for descent, mass penalty for shield).

**Vehicles detail**
- R-17 Stage Δv = Isp · g₀ · ln(m_wet / m_dry) with payload above included; TWR = thrust / (m · g_body) checked for launch and landing stages (≥ 1.2 launch, ≥ 1.5 landing at the target body).
- R-18 Engine reliability (percent per burn, data) improves with flights (+1% per successful flight up to the part's max).
- R-19 Boil-off for cryogenic propellants (data: LH2 2%/month, LOX 0.5%/month in depots; 0 for storable propellants).

**Agency detail**
- R-20 Calendar starts at a fictional year 0; launch windows computed from real-like synodic periods (Earth–Mars about 26 months).
- R-21 Milestones (data): first orbit, first crewed orbit, first lunar flyby, first lunar landing, first Mars flyby, first Mars landing, first sample return, first depot, first Jupiter probe; first-ever doubles prestige (R-10).
- R-22 Crew: each crew member has experience; crew loss ends that crew member's career and costs prestige heavily; crew rescue missions are possible if Δv and windows allow.
- R-23 Research: part unlocks by spending budget on research lines (propulsion, structures, life support, avionics); each line has 6 tiers.

### A.2 Additional Invariants
- INV-6 Stage Δv computed in the editor equals Δv consumed by execution for the same burns (± 0.1 m/s).
- INV-7 Launch windows recomputed from elements equal the porkchop minimum within 1 day.
- INV-8 Boil-off never makes propellant negative; storable propellants never boil off.
- INV-9 No milestone is awarded twice to the same agency.

### A.3 Complete Schemas and Sample Rows

```swift
struct BodyDef: Codable, Sendable { var id: String; var parent: String?; var mu: String /* m^3/s^2 as decimal string */; var radiusM: Int; var soiM: Int?; var elements: OrbitalElements; var landingDv: Int?; var atmosphere: Bool }
struct OrbitalElements: Codable, Sendable { var a: String; var e: String; var i: String; var raan: String; var argp: String; var m0: String; var epoch: Int }
struct EngineDef: Codable, Sendable { var id: String; var thrustN: Int; var ispS: Int; var massKg: Int; var propellant: Propellant; var reliability: Int; var maxReliability: Int; var tier: Int }
struct TankDef: Codable, Sendable { var id: String; var propellant: Propellant; var capacityKg: Int; var dryKg: Int }
struct MilestoneDef: Codable, Sendable { var id: String; var prestige: Int; var requires: [String] }
struct MissionPlan: Codable, Sendable { var vehicle: String; var launch: LaunchSpec; var nodes: [ManeuverNode]; var events: [MissionEvent] }
```

```json
{ "id": "moon", "parent": "earth", "mu": "4.9048695e12", "radiusM": 1737400, "soiM": 66100000, "elements": {"a": "384400000", "e": "0.0549", "i": "0.0898", "raan": "0", "argp": "0", "m0": "0", "epoch": 0}, "landingDv": 1870, "atmosphere": false }
{ "id": "eng_kerolox_t2", "thrustN": 900000, "ispS": 311, "massKg": 1500, "propellant": "kerolox", "reliability": 92, "maxReliability": 99, "tier": 2 }
{ "id": "first_lunar_landing", "prestige": 60, "requires": ["first_lunar_flyby"] }
```

Decimal strings are parsed into Fixed at load (no Float in Core).

### A.4 Balance Tables and Sim Targets

| Parameter | Default | Range | Target |
| --- | --- | --- | --- |
| Base budget per year | 100 | 70–140 | Competent autoplay reaches first lunar landing in years 8–12 |
| Prestige factor | 0.5 | 0.3–0.8 | Budget doubles by year 15 for competent play |
| Research tier cost | 20 × tier | — | All tier-3 lines by year 10 |
| Engine reliability start | 85–95% | — | Mission failures 5–15% early, < 5% late |
| Rival budget | 0.9× player base | 0.7–1.2 | Rival takes 30–50% of milestones vs competent play |

### A.5 AI Design in Detail
- **Lambert solver:** universal-variable formulation in fixed point with Stumpff-function series (fixed term count), validated by propagation (INV-5).
- **Porkchop search:** grid over departure dates (2-day steps) and flight times (5-day steps) within the window; refine best cell by golden-section search (fixed iterations).
- **Rival planner:** milestone priority list; designs vehicles by greedy staging (choose engines meeting TWR and Δv with minimum cost); launches at porkchop minima.
- **Assists:** circularise, Hohmann transfer, plane change at node, and "rendezvous with depot" helpers that emit maneuver nodes.

### A.6 Granular Task Breakdown

| ID | Task | Acceptance Criteria |
| --- | --- | --- |
| DV-P1.1 | Fixed-point vector math, scaled frames (R-12) | 10,000-op error bounds |
| DV-P1.2 | Kepler propagation (R-1, R-13) | INV-1 |
| DV-P1.3 | Patched conics, SOI (R-2, R-14) | INV-2 |
| DV-P1.4 | Maneuvers and rocket equation (R-3, R-15, R-17) | INV-3, INV-6 |
| DV-P1.5 | Launch and landing tables (R-4, R-16) | 15 fixtures |
| DV-P1.6 | Depots, docking, boil-off (R-8, R-19) | INV-8 |
| DV-P1.7 | Agency, milestones, crew, research (R-9–R-11, R-18, R-20–R-23) | INV-9 |
| DV-P1.8 | Lambert and porkchop (R-6) | INV-5, INV-7 |
| DV-P2.1 | Orbit view (Metal) with conic rendering | 60 fps with 200 conics |
| DV-P2.2 | Vehicle assembly building UI | Δv readout equals Core |
| DV-P2.3 | Maneuver node handles | Node edits update conics in < 16 ms |
| DV-P3.1 | Solar system data, 30 parts, 9 milestones | Lint; sources cited |
| DV-P4.1 | Rival planner and autoplay | Targets met |
| DV-P5.1 | Campaign and sandbox | 30-year autoplay without errors |

### A.7 Sharpened Gate Checks
- G1 adds: INV-1 and INV-2 with stated tolerances; Lambert test against 20 reference transfers.
- G3 adds: body data cites sources (NASA JPL planetary fact sheets) with simplifications listed.
- G5 adds: 30-year autoplay determinism across simulator runtimes.

### A.8 Additional Risks

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Fixed-point range and precision | High | High | Scaled frames per primary (ADR-0004) | GLM |
| Too similar to Kerbal Space Program | Medium | Medium | Agency-level planning focus, no flight-control physics | GLM |
| Orbit UI hard on iPhone | High | Medium | iPad-first; simplified iPhone planner | GLM |

### A.9 Additional Open Questions (Defaults)
1. Real agencies or rockets? Default: fictional agency and parts with real physics.
2. N-body Lagrange points? Default: out of scope.
3. Sandbox with unlimited budget? Default: yes, after campaign tutorial.
