# 24 — Patang Roadmap

> Uttarayan rooftops, a sky full of kites, and a duel of string and wind: cut your rival's line without harming a single bird.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 in full before starting. Depth pass (15 Nov 2026): Appendix A extends §4–§13 and wins where they differ. This roadmap adds only what is specific to Patang.

Research: [`RESEARCH.md`](RESEARCH.md) (art direction, design lineage, cultural context, advisor institutions, verified glossary, and audio direction).

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 24 · `patang` |
| Code prefix | `PT` (packages `PTCore`, `PTContent`, `PTAI`, `PTRender`, `PTAudio`, `PTPlatform`, `PTMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Real-time kite-fighting duel with tactical wind reading |
| Difficulty tier | Approachable |
| Scope | Solo-indie |
| Session length | 3–8 minute bouts; festival day 20–30 minutes |
| Renderer | SpriteKit 2D sky with parallax rooftops; string rendered as verlet rope (render) over Core's discrete rope |
| Players | Solo vs AI; local two-player split control on iPad; online friends duels (GameKit real-time, ADR) |
| Simulation | Fixed 60 Hz deterministic integer physics (rope segments, kite aerodynamics simplified) |
| Sourcing tier | `FULL` (Uttarayan / Makar Sankranti kite festival in Gujarat; a living tradition) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** see above.
- **Summary:** Each player flies a fighter kite (patang) from a rooftop. The kite steers by tension: pull (tighten) to make it dart in the direction it points; release (slacken) to let it spin and drift. Wind has layers (low, mid, high) with different speeds and directions and gusts. A cut (pech) happens when two strings cross and slide: the string that moves faster across the other (sawing) with higher tension and better angle wins; the loser's kite drifts free. The game uses bird-safe cotton thread only (no glass-coated manja, which harms birds and people; this is a stated design value). Birds cross the sky; touching a bird ends the bout as a loss for the toucher and starts a short rescue mini-game (carefully freeing a tangled bird, modelled on festival bird-rescue camps). Modes: festival day (a series of duels across Ahmedabad-like rooftops), practice, one-handed mode, and slow-motion assist.
- **Pillars:**
  1. **One-finger mastery.** Pull and release are the whole control scheme; skill is timing and reading wind.
  2. **Readable physics.** Strings, tension, and crossings are visible; slow-motion replays show why a cut happened.
  3. **Kindness built in.** Bird-safe string, bird rescue, no glass manja.
  4. **Festival joy.** Colour, music, rooftop community, advisor-reviewed.
- **Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | January sky `#9CCBE8` to dusk `#F2A65A`, kite colours: marigold `#F4A300`, magenta `#D4237A`, emerald `#1E9E6A`, turquoise `#21A4B5`, royal blue `#2D4FA3`, white `#FAF7F0`; rooftops terracotta `#B5603E`, whitewash `#EDE7DA`; string cotton `#F1E6CF`. |
| Shapes | Diamond fighter kites with tails absent (fighter style), paper patterns; pols (old-city row houses) with terraces. |
| Typography | SF Pro Rounded; Gujarati script for festival terms (Noto Sans Gujarati), advisor-verified. |
| Motion | Kites flutter; string sags with slack; cut snaps with a whip and a cheer. |
| Music | Festival soundscape with dhol and film-song-inspired instrumentals (commissioned; no unlicensed songs). |
| SFX | Rooftop shouts "Kapyo chhe!" (commonly written "kai po che"; text-only until advisor review, then recorded with Gujarati voice talent), string hiss, wind. |
| Haptics | Tension mapped to continuous haptic intensity; sharp transient on cut. |

- **Inspirations:** International Kite Festival, Ahmedabad (Gujarat Tourism); Karuna Abhiyan bird-rescue campaign; studies of bird injuries from manja; fighter-kite physics notes from kite clubs.

## 2. Tech Stack Decision

Per `_CONVENTIONS.md` §2, plus:
- **Physics:** Core uses a discrete rope of 24 segments per string with integer verlet integration in `Fixed`, kite as a rigid body with simplified lift and drag from tables; fixed 60 Hz; deterministic.
- **Online:** GameKit real-time matches with lockstep inputs (input delay 3 ticks; rollback not used at launch, ADR-0006).
- ADRs: ADR-0003 kite model; ADR-0004 cut model; ADR-0005 bird model and rescue; ADR-0006 netcode.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/PTCore/Sources/PTCore/
  Physics/   Rope.swift, Kite.swift, Aero.swift, Wind.swift, Gusts.swift, Integrator.swift
  Duel/      Crossing.swift, Cut.swift, Bout.swift, Rules.swift
  Birds/     Bird.swift, Flock.swift, Collision.swift, Rescue.swift
  Engine/    GameState.swift, Input.swift, Event.swift, Reducer.swift, Tick.swift
Packages/PTContent/  KiteDef.swift, StringDef.swift, RooftopDef.swift, OpponentDef.swift, FestivalDef.swift, Loader.swift
Packages/PTAI/       Pilot.swift (controller), Planner.swift (crossing tactics), Personalities.swift
Packages/PTRender/   SkyScene.swift, KiteNode.swift, StringRenderer.swift, ReplayView.swift
Packages/PTMeta/     Festival.swift, Collection.swift (kite designs), Stats.swift
Resources/Content/   kites.json, strings.json, rooftops.json, opponents.json, festivals.json, balance.json, tutorial.json, glossary.json, cultural_manifest.json
```

## 4. Core Rules Specification

**Flight**
- R-1 Input per tick: pull strength 0–100 (finger hold or pressure; one-handed mode maps tap-hold), or release.
- R-2 Kite orientation spins at a rate when slack; pulling accelerates the kite along its current heading with force proportional to pull and wind speed at its altitude layer.
- R-3 Wind: 3 layers with base vectors and seeded gusts; shown by flags, smoke, and clouds.

**Duel**
- R-4 A crossing occurs when string segments of two players intersect (segment intersection in fixed point).
- R-5 During a crossing, each tick computes saw advantage = relative string speed along the contact × tension × angle factor × string quality. Cumulative advantage beyond threshold cuts the weaker string at the contact.
- R-6 A player may deliberately pull (khench) or release (dheel) during a crossing; both are valid tactics: release-cutting relies on letting out string fast while the kite pulls.
- R-7 Bout ends on a cut (winner = surviving kite), on a bird strike (striker loses), or on time (higher altitude-dominance score wins).

**Birds**
- R-8 Birds fly through on seeded paths; a string or kite contact with a bird triggers a strike: the bout ends and the rescue mini-game starts (untangle by tracing the string path without pulling hard; success frees the bird and grants a "kindness" badge, never a gameplay power).

**Invariants**
- INV-1 Physics determinism across devices (identical state hashes for 10,000 ticks on CI simulator and device).
- INV-2 Rope segment lengths remain within ±2% (constraint satisfaction).
- INV-3 Cuts only occur during crossings.
- INV-4 Replay determinism from input logs.
- INV-5 No glass-manja string exists in content (lint rule).

## 5. Data Schemas and Content Tables

```swift
struct KiteDef: Codable, Sendable { var id: String; var size: Int; var spinRate: Fixed; var liftTable: [Fixed]; var dragTable: [Fixed]; var pattern: String; var cultural: Bool }
struct StringDef: Codable, Sendable { var id: String; var quality: Int; var birdSafe: Bool /* must be true */; var label: HistoryLabel? }
struct OpponentDef: Codable, Sendable { var id: String; var name: String; var style: PilotStyle; var reaction: Int; var aggression: Int }
enum Input: Codable, Hashable { case pull(Int), release, none }
```

| Table | G3 | G5 | Sample row |
| --- | --- | --- | --- |
| `kites.json` | 6 | 20 | `{ "id": "chil_small", "size": 2, "spinRate": "1.2", "pattern": "two_tone_diag" }` |
| `strings.json` | 3 | 5 | `{ "id": "cotton_9ply", "quality": 6, "birdSafe": true }` |
| `rooftops.json` | 4 | 10 | fictional pol neighbourhoods |
| `opponents.json` | 8 | 20 | `{ "id": "uncle_ramesh", "style": "release_cutter", "reaction": 6, "aggression": 4 }` |
| `festivals.json` | 1 day | 3 days | sequence of bouts |

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| Cut threshold | data | — | `balance.json` |
| Gust frequency | 1 per 8 s | 1/4–1/15 s | `balance.json` |
| Bird density | 0.5 per minute | 0–2 | `balance.json` |
| AI reaction delay | 120–400 ms | — | `opponents.json` |

Targets: AI-vs-AI bouts average 2–5 minutes; release-cutting and pull-cutting each win 35–65% of cuts (both viable); bird strikes ≤ 5% of bouts for competent AI; new players win the first festival bout ≥ 70% at Easy.

## 7. AI Approach

- **Pilot controller:** PD-style tracking of a target point in Fixed math with reaction delay; planner chooses tactics (climb for altitude, approach angle, initiate crossing, pull vs release) by evaluating short rollouts (0.5 s, 8 samples) of the deterministic physics.
- **Personalities:** release-cutter, puller, climber, trickster (feints).
- **Difficulty:** reaction delay and rollout count.

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7, SRC0.1, SRC0.2, HIST0.1 (Attested: Uttarayan, kite fighting terms, bird injuries from manja and rescue campaigns; Invented: physics tuning, opponents).

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; SRC0.1, SRC0.2, HIST0.1 complete
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- PT-P1.1 Rope, kite, wind physics (R-1 to R-3).
- PT-P1.2 Crossings and cuts (R-4 to R-7); birds (R-8).

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-8 tests; INV-1…INV-5
  [ ] Physics tick ≤ 1 ms for 2 kites + 10 birds; PTCore coverage ≥ 90%
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5, SRC2.1, SRC2.2.
- PT-P2.1 Sky scene; one-finger control; tension haptics; crossing highlight; cut replay in slow motion.
- PT-P2.2 One opponent; one rooftop.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test plays a full bout on iPad and Mac (scripted inputs)
  [ ] Manifest marks Gujarati terms, music, and voice pending; deny-list passes
  [ ] `docs/SLICE_ASSESSMENT.md` written: self-assessment against the pillars, with every weakness turned into a P3 task (`_CONVENTIONS.md` §8.1)
Sign-off: GLM-SELF
```

### P3 Content and Systems
- PT-P3.1 G3 content; festival day; bird rescue mini-game; About the Tradition (SRC3.1).
- PT-P3.2 Tutorial (4 lessons); one-handed and slow-motion modes.

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts met; lint clean (INV-5); tutorial UI test
Sign-off: GLM-SELF
```

### P4 AI Opponents
- PT-P4.1 Pilot and planner; personalities; `docs/BALANCE.md`.

```
GATE G4 — AI
Checks:
  [ ] Targets in §6 met; AI per-tick cost ≤ 0.5 ms
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- PT-P5.1 G5 counts; kite collection; 20 achievements; SRC5.1; HANDOFF.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Counts met; packet and HANDOFF complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- PT-P6.1 Kite patterns (commissioned from Gujarati artists where possible), rooftops, crowds; SRC6.1 and SRC6.2 with Gujarati cultural advisors and a bird-welfare advisor.
- PT-P6.2 Music and voice (Gujarati voice talent).

```
GATE G6 — Aesthetics and Cultural Review
Checks:
  [ ] Advisor review filed as a `needs-maintainer` issue (SUBSTITUTED, `_SET2_ADDENDUM.md` §4); every entry still pending advisor review listed in that issue; 120 fps on iPad Pro
Sign-off: GLM-SELF
```

### P7 Platform Features
- PT-P7.1 Local split-control two-player on iPad; online friends duels (lockstep); Game Center; iCloud; Gujarati and Hindi localisation (a maintainer decision filed as an issue; GLM ships String Catalogs ready for translation).

```
GATE G7 — Platform
Checks:
  [ ] Online duel stays in sync for 10 minutes (hash checks); local two-player verified
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- PT-P8.1 One-handed mode; switch control mapping (single switch for pull); audio cues for wind and crossing; Reduce Motion.

```
GATE G8 — Polish
Checks:
  [ ] Switch Control completes tutorial; budgets met
Sign-off: GLM-SELF
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard tasks; SRC9.1 community playtest and SRC10.1 credits, each prepared locally and filed as a `needs-maintainer` issue; consider a launch around Uttarayan (14 January).

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

### Key Test Fixtures (GLM Writes These in P1)

1. Constant wind and no input: the kite reaches a stable hover state within 5 s.
2. Pulling with heading 90° accelerates the kite along +y.
3. Two strings crossing at 90° with equal tension: the faster-sawing string wins.
4. No crossing: no cut can occur (INV-3) over 10,000 random ticks.
5. Bird contact ends the bout with a loss for the striker and starts rescue.
6. Replay from the input log reproduces the same state hash at tick 18,000.
7. Lint fails if any string has `birdSafe: false`.
8. One-handed mode maps tap-hold to pull 100 and release to slack.

## 9. Fragile Areas and Priorities

- **Fragile areas:** cut model tuning; online lockstep drift.
- **Priorities for P6–P10:** haptics, netcode; feel tuning; cultural packet.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Glorifying harmful manja | Low | High | Bird-safe string only; rescue; messaging | GLM |
| Physics feels floaty | Medium | High | Early feel prototype at G2 | GLM |
| Netcode desync | Medium | Medium | Integer physics, hash checks | GLM |

## 11. Out of Scope

Glass manja; free-for-all multi-kite skies beyond 4 kites; real-money items.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 2 |
| P1 | GLM | 7–9 |
| P2 | GLM | 5–7 |
| P3 | GLM | 5–7 |
| P4 | GLM | 4–6 |
| P5 | GLM | 3–4 |
| P6 | GLM | 8–11 |
| P7 | GLM | 5–7 |
| P8 | GLM | 3–4 |
| P9 | GLM | 4–6 |
| P10 | GLM | 2–3 |
| **Total** | | **48–66** |

## 13. Open Questions

1. Ship online duels at launch? Default: yes, friends only.

## 14. Sourcing Notes

- **Sources:** Gujarat Tourism materials on the International Kite Festival; Karuna Abhiyan (Gujarat Forest Department bird-rescue campaign, launched 2017; reporting in 2026 counted 16,380 birds treated and 14,690 survived); reporting on manja injuries to birds; kite-flying community references (see the research file for URLs).
- **Restricted elements:** religious imagery of Makar Sankranti rituals as gameplay objects; caricatured accents.
- **Glossary seeds (verified against published sources; pending advisor):** patang (kite), manjo (Gujarati) / manja or manjha (Hindi) (glass-coated string; never used in game), dori (plain string), firki (reel), pech (string crossing), kapyo chhe (કાપ્યો છે, commonly written "kai po che", "I have cut it"), lapet ("wind it in"), dheel ("dheel de", give slack), khench/khainch (pull), dhabu (terrace), tukkal (lantern kite), panjo (set of five kites), kamaan (the kite's bow). Uttarayan falls on 14 January, followed by Vasi Uttarayan on 15 January.
- **Bird safety (state in About):** Karuna Abhiyan advice includes not flying 8–10 am and 4–6 pm when birds move, never using Chinese/plastic or glass-coated string, and never pulling string off an injured bird (call trained rescuers). Do not print helpline numbers in-game; link to official Gujarat Forest Department pages only after verification.

## Appendix A. Extended Specification (Depth Pass)

### A.1 Additional Rules

**Kite physics detail**
- R-9 Simulation runs at 120 Hz fixed step in Fixed Q32.32; rendering interpolates. The string is a chain of 24 segments (position-based dynamics, 4 constraint iterations per step); the kite is a rigid body with heading, angular velocity, and a lift/drag table by angle of attack (8 entries, data).
- R-10 Slack spin: when tension < spinThreshold, heading rotates at spinRate (default 360°/s, data) in the kite's spin direction; when pull resumes, the kite darts along its heading at that instant — the core skill.
- R-11 Reel (firki): the player's string length changes by `releaseRate` when releasing (max 6 m/s) and by `windRate` when winding in (lapet); total string length capped at 300 m.
- R-12 Altitude layers: low (< 40 m), mid (40–120 m), high (> 120 m); wind vector per layer plus gusts (seeded, 2–6 s duration, ±40% speed).

**Duel detail**
- R-13 Contact point slides along both strings according to relative velocity; saw advantage accumulates at the contact (R-5). String quality (all bird-safe cotton grades) affects only the cut threshold (±10%).
- R-14 Angle factor peaks when strings cross at 60–90° (data curve); near-parallel contacts (< 15°) do not saw.
- R-15 A cut separates the string at the contact; the cut kite drifts away (cosmetic loose-kite chase in rooftop mode, never with a bird present).
- R-16 Time limit 90 s per bout; altitude-dominance score = seconds with higher kite altitude than the rival.

**Birds detail**
- R-17 Bird density follows time-of-day: peaks in early morning and late afternoon (in-game clock), which teaches the real advice not to fly at those times; Festival mode warns before peak times.
- R-18 Rescue mini-game: trace the string coil from bird to free end without exceeding a tension threshold; failure calls a rescue team (bird still saved, no badge).

### A.2 Additional Invariants
- INV-6 String length conservation: Σ segment lengths = current reel length ± 2%.
- INV-7 No cut without contact angle ≥ 15° (property test).
- INV-8 Bird strikes always end the bout and never reward the striker.
- INV-9 All string types in content carry `birdSafe: true` (lint, complements INV-5).

### A.3 Complete Schemas and Sample Rows

```swift
struct KiteDef: Codable, Sendable { var id: String; var name: String; var mass: Fixed; var liftTable: [Fixed]; var dragTable: [Fixed]; var spinRate: Int; var art: String; var cultural: Bool }
struct StringDef: Codable, Sendable { var id: String; var name: String; var cutThreshold: Int; var birdSafe: Bool; var label: HistoryLabel }
struct WindProfile: Codable, Sendable { var layers: [LayerWind]; var gustRate: Int; var gustAmp: Int }
struct LayerWind: Codable, Sendable { var dir: Int; var speed: Int }
struct OpponentDef: Codable, Sendable { var id: String; var name: String; var personality: Personality; var reactionMs: Int; var rollouts: Int; var rooftop: String }
struct BoutLog: Codable, Sendable { var seed: UInt64; var inputs: [InputFrame]; var result: BoutResult }
```

```json
{ "id": "patang_classic", "name": "Classic Fighter", "mass": "0.025", "spinRate": 360, "art": "kite_classic_01", "cultural": true }
{ "id": "cotton_soft", "name": "Soft Cotton", "cutThreshold": 100, "birdSafe": true, "label": "Invented" }
{ "layers": [{"dir": 200, "speed": 3}, {"dir": 220, "speed": 5}, {"dir": 250, "speed": 8}], "gustRate": 10, "gustAmp": 40 }
{ "id": "op_release", "name": "The Old Pol Uncle", "personality": "releaseCutter", "reactionMs": 220, "rollouts": 8, "rooftop": "pol_house" }
```

Opponent names are fictional and reviewed for caricature (no accents or stereotypes).

### A.4 Balance Tables and Sim Targets

| Parameter | Default | Range | Target |
| --- | --- | --- | --- |
| spinRate | 360°/s | 240–480 | Skilled testers dart to a target within 1 s in ≥ 70% of tries (scripted bot proxy) |
| Release rate | 6 m/s | 4–8 | Release-cutting wins 40–60% vs pulling (bot vs bot) |
| Cut threshold | 100 | 80–120 | Median crossing 2–6 s |
| Gust amplitude | 40% | 20–60% | Bouts decided by cut 70–85% |
| Bird density peak | ×3 | ×2–×5 | Bird strikes ≤ 5% of bouts outside peak times |

### A.5 AI Design in Detail
- **Controller:** PD tracking of a target point with reaction delay buffer; target chosen by planner every 0.25 s.
- **Planner:** 8 rollouts of 0.5 s for each tactic (climb, approach-left, approach-right, cross-pull, cross-release, retreat); evaluate altitude advantage, crossing angle, and bird proximity (heavy penalty).
- **Personalities:** weights on tactic values; trickster adds feints (approach then retreat).
- **Fairness:** AI reads only the same state the player sees (wind indicators), never future gusts.

### A.6 Granular Task Breakdown

| ID | Task | Acceptance Criteria |
| --- | --- | --- |
| PT-P1.1 | Fixed-step physics, string PBD (R-9) | INV-1, INV-2, INV-6 |
| PT-P1.2 | Kite flight, spin, dart (R-1, R-2, R-10) | 10 deterministic trajectory fixtures |
| PT-P1.3 | Reel and wind layers (R-3, R-11, R-12) | 10 fixtures |
| PT-P1.4 | Crossing and saw (R-4–R-6, R-13–R-15) | INV-3, INV-7 |
| PT-P1.5 | Birds and rescue (R-8, R-17, R-18) | INV-8 |
| PT-P1.6 | Bout end and scoring (R-7, R-16) | 10 fixtures |
| PT-P2.1 | Input mapping (hold, pressure, one-handed) | UI tests |
| PT-P2.2 | Rooftop scene and sky layers | 60 fps on A15 |
| PT-P3.1 | 6 kites, 3 strings (all bird-safe), 6 opponents | Lint (INV-5, INV-9) |
| PT-P3.2 | About Uttarayan and bird safety | Pending advisor marks; needs-maintainer issue for advisor review |
| PT-P4.1 | AI controller and personalities | Balance targets |
| PT-P5.1 | Festival mode (two-day Uttarayan and Vasi Uttarayan) | UI test |

### A.7 Sharpened Gate Checks
- G1 adds: state-hash determinism over 10,000 ticks on simulator runtimes; INV-5 and INV-9 lint.
- G3 adds: bird-safety About text present; no helpline numbers in strings.
- G5 adds: voice lines recorded only after the advisor issue is resolved; until then, text-only callouts.

### A.8 Additional Risks

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Glorifying harmful string | Low | High | Bird-safe only, peak-time warnings, rescue | GLM |
| Controls feel floaty | Medium | High | Tuning ranges, haptic feedback on tension | GLM |
| Religious aspects of Makar Sankranti misused | Low | Medium | Festival shown as civic and family celebration | GLM |

### A.9 Additional Open Questions (Defaults)
1. Use "kai po che" callout? Default: text-only "Kapyo chhe!" until advisor review; voice later.
2. Include night tukkal (lantern kites)? Default: cosmetic only, no fire mechanics.
3. Online duels? Default: friends-only online duels at launch (as §13); matchmaking with strangers post-launch.
