# 14 — Carceri Roadmap

> Lead three prisoners out of Piranesi's impossible prisons, where pulling a lever rewires which stair leads where.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 in full before starting. Depth pass (15 Nov 2026): Appendix A extends §4–§13 and wins where they differ. This roadmap adds only what is specific to Carceri.

Research: [`RESEARCH.md`](RESEARCH.md) (art direction, design lineage, cultural context, advisor institutions, verified glossary, and audio direction).

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 14 · `carceri` |
| Code prefix | `CC` (packages `CCCore`, `CCContent`, `CCAI`, `CCRender`, `CCAudio`, `CCPlatform`, `CCMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Turn-based stealth tactics on a mutable graph (puzzle-tactics) |
| Difficulty tier | Deep |
| Scope | Small team |
| Session length | 5–15 minutes per prison; campaign 8–12 hours |
| Renderer | SpriteKit 2.5D isometric-ish etching layers with a Metal cross-hatching post-process |
| Players | Solo |
| Simulation | Turn-based, deterministic guards (fully telegraphed) |
| Sourcing tier | `NONE` (Piranesi's "Carceri d'invenzione" is public-domain art; credit as inspiration) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** see above.
- **Summary:** Each prison is a graph of platforms (nodes) connected by stairs, bridges, and ropes (edges). Some edges are controlled by levers: pulling a lever swaps, connects, or severs edge sets, including "impossible" connections (a stair that leads from the bottom vault to the top gallery). Three prisoners, each with one skill (the Climber uses ropes, the Locksmith opens gates, the Talker distracts guards), act each turn (each prisoner gets 1 action: move along one edge, pull a lever, or use skill). Guards follow patrol scripts shown as glowing footprints for the next 2 turns; vision cones are along edges (a guard sees nodes connected by visible edges within range). If any prisoner is seen, they are caught (they return to the cell) and the alarm level rises; at alarm 3 the prison resets. Exit with all three prisoners to win; optional goals for par turns and no alarms.
- **Pillars:**
  1. **Perfect information puzzles.** Guards are deterministic and telegraphed; failure is always explainable.
  2. **Rewiring is the verb.** Levers change topology, not just doors.
  3. **Three bodies, one plan.** Prisoners' skills interlock.
  4. **Etched atmosphere.** Monochrome etching aesthetic with dramatic scale.
- **Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Paper `#EFE8DA`, etching black `#151515`, mid hatch `#5B5650`, shadow wash `#8A8378`, guard lamp `#E3A33B` (only colour), prisoner ribbon accents `#9E2A2B`, `#2E5A87`, `#3E6B3A`. |
| Shapes | Vaults, arches, stairs, chains, wheels; edges drawn as stairs/bridges with perspective tricks. |
| Typography | Bodoni-style display (Bodoni 72, system) and SF Pro. |
| Motion | Lever pulls redraw stairs with an "etching" wipe; guards step in time with a deep drum. |
| Music | Low strings and pipe organ drones (original). |
| SFX | Chains, echoing footsteps, lever clank, distant drip. |
| Haptics | Heavy clunk on lever; soft heartbeat when a guard's next-turn vision covers a prisoner's path. |

- **Inspirations:** Piranesi, "Carceri d'invenzione" (1750, 1761); Monument Valley; Into the Breach (telegraphing); Hitman GO and Deus Ex GO.

## 2. Tech Stack Decision

Per `_CONVENTIONS.md` §2, plus:
- **Graph model:** nodes with 2.5D positions (render only) and edges with types; levers map to edge-set operations (`enable`, `disable`, `swap(A,B)`).
- **Solver:** BFS/A* over the full state (prisoner positions, lever states, guard phase, alarm) with symmetry reduction, used to verify puzzles and compute par.
- ADRs: ADR-0003 graph and lever model; ADR-0004 guard scripts; ADR-0005 solver state encoding.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/CCCore/Sources/CCCore/
  Graph/   Node.swift, Edge.swift, EdgeKind.swift, Lever.swift, Topology.swift
  Actors/  Prisoner.swift, Skill.swift, Guard.swift, Patrol.swift, Vision.swift
  Engine/  GameState.swift, Action.swift, Event.swift, Reducer.swift, TurnOrder.swift, Alarm.swift, Victory.swift
Packages/CCContent/  PrisonDef.swift, PatrolDef.swift, ChapterDef.swift, Loader.swift, Validation.swift
Packages/CCAI/       Solver.swift, Par.swift, Hint.swift, Generator.swift (assisted level design)
Packages/CCRender/   PrisonScene.swift, EtchingPost.metal, StairNode.swift, VisionOverlay.swift, Footprints.swift
Packages/CCMeta/     Campaign.swift, Stats.swift
Tools/PrisonEditor/  (macOS SwiftUI editor for designers; not shipped)
Resources/Content/   prisons/*.json, chapters.json, balance.json, tutorial.json
```

## 4. Core Rules Specification

**Graph**
- R-1 A prison has nodes (platforms, cells, exit) and edges (stair, bridge, rope, gate). Edges may be enabled or disabled. Ropes are traversable only by the Climber; gates only after unlocking (Locksmith).
- R-2 Levers sit on nodes. Pulling a lever toggles its state and applies its operation set atomically.

**Turn**
- R-3 Player phase: each free prisoner takes up to 1 action in any order chosen by the player: `move(edge)`, `pull(lever)` (prisoner on lever node), `skill(target)`, or `wait`.
- R-4 Skills: Climber: traverse ropes; Locksmith: unlock an adjacent gate permanently; Talker: distract a guard within 2 edges, making it skip its next move and face toward the Talker.
- R-5 Guard phase: each guard advances its patrol script one step (move, turn, wait, or "react" to a distraction). Scripts are cyclic lists in data.
- R-6 Vision: a guard sees nodes reachable via enabled non-rope edges within `range` (default 2) in its facing direction set (data defines facing as a subset of edges at its node). Vision is computed after the guard phase and after each prisoner action.
- R-7 Caught: a prisoner on a seen node is caught: returns to the start cell; alarm +1.
- R-8 Alarm 3: prison resets to initial state; turn counter continues for par scoring.
- R-9 Victory: all three prisoners on the exit node(s). Some prisons require fewer prisoners (data).

**Invariants**
- INV-1 Telegraph: the footprints shown for the next 2 turns equal the guard positions after simulation without prisoner interference.
- INV-2 Every prison in content is solvable (solver), with par recorded.
- INV-3 Lever operations are involutions or explicitly flagged one-way.
- INV-4 Replay determinism.
- INV-5 Undo returns to the exact previous state (full-turn undo).

## 5. Data Schemas and Content Tables

```swift
struct PrisonDef: Codable, Sendable { var id: String; var nodes: [NodeDef]; var edges: [EdgeDef]; var levers: [LeverDef]; var guards: [GuardDef]; var prisoners: [PrisonerStart]; var exit: [NodeID]; var par: Int; var chapter: String }
struct LeverDef: Codable, Sendable { var id: String; var node: NodeID; var ops: [EdgeOp]; var oneWay: Bool }
struct GuardDef: Codable, Sendable { var id: String; var start: NodeID; var script: [PatrolStep]; var range: Int }
enum Action: Codable, Hashable { case move(PrisonerID, EdgeID), pull(PrisonerID, LeverID), skill(PrisonerID, Target), wait(PrisonerID), endTurn, undo }
```

| Table | G3 | G5 | Sample row |
| --- | --- | --- | --- |
| `prisons/*.json` | 25 | 80 | as schema; each ≤ 40 nodes |
| `chapters.json` | 3 | 8 | `{ "id": "ch2_wheel", "title": "The Wheel", "introduces": "swap_levers", "prisons": [...] }` |
| `tutorial.json` | 5 prisons | 6 | — |

Mechanic introductions per chapter: basics, gates, swap levers, ropes, distraction, one-way levers, multi-floor impossible loops, guards that use levers.

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| Guard range | 2 | 1–3 | per guard |
| Telegraph turns | 2 | 1–3 | `balance.json` |
| Alarm limit | 3 | 2–5 | `balance.json` |

Targets: solver solution length 8–40 turns; difficulty curve measured by solver branching factor and solution length rises monotonically per chapter (± 15%); hint usage expected 0.3–1.0 per prison in playtests.

## 7. AI Approach

- **Solver:** A* with heuristic = max over prisoners of graph distance to exit in the relaxed graph (all lever-enableable edges enabled; see Appendix A.5), which stays admissible when levers open shortcuts; state hashing; limit 10⁷ states; used offline in CI and on device for hints (time-limited 1.5 s).
- **Hints:** next optimal action from solver; three levels (highlight prisoner, highlight action, show full turn).
- **Generator:** assists designers by mutating authored prisons and checking solvability and novelty (not used at runtime).

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7.
- CC-P0.1 `Tools/PrisonEditor` skeleton (load, edit nodes/edges, save JSON).

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; editor saves a valid prison
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- CC-P1.1 Graph, levers, prisoners, skills (R-1 to R-4).
- CC-P1.2 Guards, vision, alarm, victory (R-5 to R-9); undo.
- CC-P1.3 Solver and par (INV-2).

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-9 tests; INV-1…INV-5
  [ ] Solver solves 10 fixture prisons with known optima; CCCore coverage ≥ 90%
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5.
- CC-P2.1 Prison scene with placeholder etching; tap prisoner, tap destination; lever animation; footprints and vision overlay; end turn; undo.
- CC-P2.2 Five tutorial prisons.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test solves tutorial prisons on iPad and Mac using solver-scripted inputs
  [ ] Overlay equals Core vision on 500 random states
  [ ] `docs/SLICE_ASSESSMENT.md` written: self-assessment against the pillars, with every weakness turned into a P3 task (`_CONVENTIONS.md` §8.1)
Sign-off: GLM-SELF
```

### P3 Content and Systems
- CC-P3.1 G3 prisons in 3 chapters, authored in the editor; every prison solver-verified in CI.
- CC-P3.2 Hint system; campaign map; save.

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts met; CI solvability job passes; difficulty curve report generated
Sign-off: GLM-SELF
```

### P4 Solver and Hints
- CC-P4.1 Optimise solver (symmetry, memory); on-device hint budget; `docs/BALANCE.md` with curve.

```
GATE G4 — Solver
Checks:
  [ ] All G3 prisons solved in CI < 60 s each; on-device hint p95 ≤ 1.5 s
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- CC-P5.1 G5 counts (GLM designs and delivers 80 prisons with solver proofs); challenge modes (par, no alarm, two prisoners); 30 achievements; HANDOFF.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Counts met; HANDOFF complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- CC-P6.1 Etching post-process; architectural tiles (commissioned etched assets); impossible-stair illusions.
- CC-P6.2 Music and SFX.

```
GATE G6 — Aesthetics
Checks:
  [ ] Snapshots approved; 120 fps on iPad Pro; 60 fps base iPad
Sign-off: GLM-SELF
```

### P7 Platform Features
- CC-P7.1 Game Center (par leaderboards per chapter); iCloud; Mac keyboard (number keys select prisoners).

```
GATE G7 — Platform
Checks:
  [ ] iCloud round-trip; leaderboards submit
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- CC-P8.1 VoiceOver graph navigation (node list with edges, guard warnings); high-contrast mode; Reduce Motion.

```
GATE G8 — Polish
Checks:
  [ ] VoiceOver completes chapter 1; budgets met
Sign-off: GLM-SELF
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard tasks.

```
GATE G9 — Beta
Checks:
  [ ] Crash-free ≥ 99.5%; difficulty spikes addressed
Sign-off: GLM-SELF
GATE G10 — Release
Checks:
  [ ] Store assets; final CI green
Sign-off: GLM-SELF
```

### Key Test Fixtures (GLM Writes These in P1)

1. Swap lever toggled twice restores the original edge set exactly.
2. One-way lever cannot be toggled back.
3. Rope edge traversable by the Climber only.
4. Gate opens permanently after the Locksmith's unlock.
5. Distracted guard skips one move and faces the Talker.
6. Vision through a newly enabled edge catches a prisoner in the same turn.
7. Alarm 3 resets prison state but keeps the turn counter.
8. Solver optimum on fixture `ch1_p03` equals the stored par of 11 turns.

## 9. Fragile Areas and Priorities

- **Fragile areas:** vision through swapped edges; solver memory on large prisons.
- **Priorities for P6–P10:** etching shader, VoiceOver graph; later chapters design.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Puzzle authoring bottleneck | High | High | Editor, generator, solver CI | GLM |
| Visual confusion of rewired edges | Medium | High | Highlight changed edges per lever | GLM |

## 11. Out of Scope

Real-time stealth; procedural campaign; multiplayer.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 3–4 |
| P1 | GLM | 6–8 |
| P2 | GLM | 6–8 |
| P3 | GLM | 8–12 |
| P4 | GLM | 3–5 |
| P5 | GLM | 8–12 |
| P6 | GLM | 9–12 |
| P7 | GLM | 2–4 |
| P8 | GLM | 3–5 |
| P9 | GLM | 4–6 |
| P10 | GLM | 2–3 |
| **Total** | | **54–79** |

## 13. Open Questions

1. A level editor for players? Default: no at launch.

## Appendix A. Extended Specification (Depth Pass)

### A.1 Additional Rules

**Graph detail**
- R-10 Nodes have `floor` (0–6, for rendering and impossible-loop presentation), `kind` (platform, cell, lever, exit, start), and `capacity` (default 2 prisoners; guards do not count).
- R-11 Edge kinds and who may traverse: stair and bridge (all prisoners and guards), rope (Climber only; guards never), gate (all, after unlock; guards always, as they hold keys).
- R-12 "Impossible" edges are ordinary edges whose rendered endpoints violate perspective (Penrose-stair style); the rules treat them like any other edge. Rendering marks them with a subtle glint so they are discoverable.
- R-13 Edge operations (lever ops): `enable(e)`, `disable(e)`, `toggle(e)`, `swap(e1, e2)` (exchange enabled states), `reroute(e, from, to)` (moves an endpoint between two named sockets). All ops in one pull apply atomically in listed order.

**Turn detail**
- R-14 Prisoners act in any order within the player phase; one action each; a prisoner moved onto a guard's current node is caught immediately.
- R-15 A guard moving onto a prisoner's node catches that prisoner (in addition to vision catches).
- R-16 Distraction (Talker) lasts exactly one guard phase; a distracted guard turns its facing set toward the Talker's node (shortest-path first edge) and then resumes its script from the same index next phase.
- R-17 Guards may pull levers if their script says so (chapter 8); guard pulls apply during the guard phase in guard id order.
- R-18 Vision is blocked by disabled edges, ropes, and closed gates (gates block vision until unlocked).
- R-19 Par = solver-optimal turn count; medals: gold ≤ par, silver ≤ par + 3, bronze = any completion.
- R-20 Alarm reset (R-8) restores lever states, gates, and guard script indices; unlocked gates also relock.

### A.2 Additional Invariants
- INV-6 Capacity never exceeded on any node.
- INV-7 Hint actions are always legal in the current state and lead to a solvable state (solver re-check).
- INV-8 Solver heuristic is admissible: verified against exact BFS optimum on all G3 prisons (heuristic ≤ true remaining turns at every visited state, sampled 10,000 states per prison).
- INV-9 Vision sets computed by two independent methods (BFS limited by facing, and matrix reachability) agree on all content.

### A.3 Complete Schemas and Sample Rows

```swift
struct NodeDef: Codable, Sendable { var id: NodeID; var kind: NodeKind; var floor: Int; var capacity: Int; var pos2D: [Int] /* layout hint */ }
struct EdgeDef: Codable, Sendable { var id: EdgeID; var a: NodeID; var b: NodeID; var kind: EdgeKind; var enabled: Bool; var impossible: Bool; var sockets: [NodeID]? }
enum EdgeOp: Codable, Sendable { case enable(EdgeID), disable(EdgeID), toggle(EdgeID), swap(EdgeID, EdgeID), reroute(EdgeID, from: NodeID, to: NodeID) }
enum PatrolStep: Codable, Sendable { case move(EdgeID), face([EdgeID]), wait, pull(LeverID) }
struct PrisonerStart: Codable, Sendable { var id: PrisonerID; var skill: Skill; var node: NodeID }
struct SolveResult: Codable, Sendable { var par: Int; var solution: [[Action]]; var statesExpanded: Int; var unique: Bool }
```

```json
{ "id": "e4", "a": "vault_0", "b": "gallery_5", "kind": "stair", "enabled": false, "impossible": true }
{ "id": "lv_wheel", "node": "n12", "ops": [{"swap": ["e4", "e9"]}, {"toggle": "e11"}], "oneWay": false }
{ "id": "g1", "start": "n7", "script": [{"move": "e2"}, {"face": ["e3", "e5"]}, "wait", {"move": "e2r"}], "range": 2 }
{ "id": "ch2_wheel", "title": "The Wheel", "introduces": "swap_levers", "prisons": ["p2_01", "p2_02", "p2_03"] }
```

### A.4 Balance Tables and Sim Targets (Puzzle Curve)

| Chapter | Mechanic Introduced | Prisons (G5) | Par Range | Solver States (p90) | Target First-Try Solve (Testers) |
| --- | --- | --- | --- | --- | --- |
| 1 | Basics, vision | 10 | 4–8 | ≤ 10³ | 90% |
| 2 | Gates (Locksmith) | 10 | 6–10 | ≤ 10⁴ | 80% |
| 3 | Swap levers | 10 | 8–14 | ≤ 10⁵ | 70% |
| 4 | Ropes (Climber) | 10 | 8–14 | ≤ 10⁵ | 65% |
| 5 | Distraction (Talker) | 10 | 10–16 | ≤ 10⁵ | 60% |
| 6 | One-way levers | 10 | 10–18 | ≤ 10⁶ | 55% |
| 7 | Impossible loops | 10 | 12–20 | ≤ 10⁶ | 50% |
| 8 | Guards using levers | 10 | 14–24 | ≤ 10⁷ | 40% |

Difficulty proxy (used before testers): `d = log10(statesExpanded) + 0.3·par + 2·(number of mechanics combined)`; within each chapter, prisons are ordered by `d` and adjacent prisons must differ by ≤ 1.5.

### A.5 AI Design in Detail
- **State:** prisoner positions, lever states, gate states, guard script indices, alarm, turn (alarm and turn excluded from the closed-set key except alarm < 3 boolean).
- **Successors:** a "turn" is the cartesian product of each free prisoner's actions (≤ 6 each, so ≤ 216 per turn) followed by the deterministic guard phase; prune actions that move into a guard-visible node (immediate catch) unless the alarm is used deliberately (never optimal, so pruned).
- **Heuristic (admissible):** max over prisoners of shortest-path distance to the nearest exit in a relaxed graph: every edge that any lever could enable is enabled, every gate counts as open, and ropes count only for the Climber. Relaxation can only shorten paths, so the heuristic never overestimates the remaining turns (INV-8). A tighter heuristic (adding 1 when a non-Locksmith's relaxed path crosses a locked gate) is not admissible in general, because another prisoner may unlock the gate in the same turn, so it is not used.
- **Uniqueness check:** count optimal solutions up to 2; prisons tagged unique or multi.
- **Hints at runtime:** cached solutions per prison state for the authored start; from arbitrary states, on-device A* capped at 1.5 s, falling back to "undo to a known state" hint.

### A.6 Granular Task Breakdown

| ID | Task | Acceptance Criteria |
| --- | --- | --- |
| CC-P0.1 | ADR on impossible-geometry rendering (2D isometric vs 3D) | Decision recorded |
| CC-P1.1 | Graph model and edge kinds (R-1, R-10, R-11) | 20 fixtures |
| CC-P1.2 | Lever ops incl. reroute (R-2, R-13) | INV-3; 25 fixtures |
| CC-P1.3 | Prisoner actions and skills (R-3, R-4, R-14, R-16) | 30 fixtures |
| CC-P1.4 | Guard scripts and lever-using guards (R-5, R-17) | 20 fixtures |
| CC-P1.5 | Vision and catches (R-6, R-7, R-15, R-18) | INV-9 |
| CC-P1.6 | Alarm, reset, undo, medals (R-8, R-19, R-20) | INV-5 |
| CC-P1.7 | Solver and heuristic | INV-2, INV-8 |
| CC-P2.1 | Etching-style renderer (cross-hatching shader) | 60 fps on A15 |
| CC-P2.2 | Footprint telegraphs | INV-1 |
| CC-P2.3 | Lever preview (ghost of edges after pull) | Matches Core ops |
| CC-P3.1 | Chapters 1–3 (25 prisons) | Curve table met |
| CC-P4.1 | Hints (3 levels) | INV-7 |
| CC-P4.2 | Designer generator tool (Mac) | Produces solvable variants |
| CC-P5.1 | Chapters 4–8 | 80 prisons total |

### A.7 Sharpened Gate Checks
- G1 adds: solver proves par for 10 hand-made prisons whose optimum was computed by exhaustive BFS.
- G2 adds: footprints and lever previews never disagree with outcomes in 1,000 random action sequences.
- G3 adds: chapter curve table (A.4) satisfied for chapters 1–3.

### A.8 Additional Risks

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Impossible edges confuse rather than delight | Medium | High | Glint marker; chapter 7 tutorial | GLM |
| Solver blow-up in chapter 8 | Medium | Medium | State cap; designer tool flags | GLM |
| Etching shader cost on iPhone | Medium | Medium | Baked hatching textures fallback | GLM |

### A.9 Additional Open Questions (Defaults)
1. Add a fourth prisoner? Default: no.
2. Daily puzzle? Default: yes, from generator variants of authored prisons, verified by solver.
3. Show turn-count leaderboards? Default: Game Center par leaderboards only.

### A.10 Prison Authoring Checklist (Each Prison, Before Merge)
1. Solver proves solvable; par recorded; `unique` flag recorded.
2. Difficulty proxy `d` within the chapter ordering rule (A.4).
3. Introduces at most one new mechanic; every earlier mechanic it uses was introduced ≥ 2 prisons earlier.
4. Every lever is used in at least one optimal solution, or the prison is tagged "red herring" (≤ 1 per chapter).
5. Every impossible edge is rendered with the glint marker and appears in ≤ 1 lever op per prison in chapters 1–6.
6. Footprint telegraph shows the next 2 guard steps for every guard (INV-1).
7. Layout hint positions produce no overlapping nodes at iPhone size (snapshot).
8. Plate title and number assigned (Roman numerals), with no reuse of Piranesi's own plate titles.

### A.11 Key Test Fixtures (Extended)
- **Swap op:** e4 disabled, e9 enabled; pull `lv_wheel` → e4 enabled, e9 disabled, e11 toggled; pull again → original (INV-3).
- **Reroute op:** rope e7 sockets [n3, n8]; reroute from n3 to n8 → endpoint moves; Climber on n3 can no longer traverse e7.
- **Distraction:** guard g1 facing e3 with Talker 2 edges away via e5 → g1 skips its move, faces e5, resumes the script at the same index next phase.
- **Gate vision:** guard behind a locked gate cannot see beyond it; after unlock, vision passes (R-18).
- **Simultaneous catch:** prisoner moves onto a node that a guard enters in the same guard phase → caught by R-15; alarm +1.
