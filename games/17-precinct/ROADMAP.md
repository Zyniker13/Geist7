# 17 — Precinct Roadmap

> A 1970s city council race told in risograph ink: every issue is a colour, and where your flyers overprint, new coalitions appear.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 in full before starting. Depth pass (15 Nov 2026): Appendix A extends §4–§13 and wins where they differ. This roadmap adds only what is specific to Precinct.

Research: [`RESEARCH.md`](RESEARCH.md) (art direction, design lineage, cultural context, advisor institutions, verified glossary, and audio direction).

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 17 · `precinct` |
| Code prefix | `PC` (packages `PCCore`, `PCContent`, `PCAI`, `PCRender`, `PCAudio`, `PCPlatform`, `PCMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Area-majority with coalitions (political campaign) |
| Difficulty tier | Intermediate |
| Scope | Small team |
| Session length | 25–45 minutes |
| Renderer | SpriteKit with a risograph shader (ink layers, misregistration, grain) |
| Players | 2–4 (AI fills seats); pass-and-play; async online |
| Simulation | Turn-based, partial information (hidden polling), seeded event deck |
| Sourcing tier | `NONE` (fictional city and parties; HIST labels optional for 1970s municipal politics flavour) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** see above.
- **Summary:** A fictional mid-sized city has 16–24 precincts (wards) on a map, each with voter blocs that care about five issues, each issue a risograph ink colour: Housing (fluorescent pink), Transit (teal), Jobs (yellow), Schools (blue), and Safety (orange). Each turn players spend volunteer cubes to canvass precincts on an issue (placing ink of that colour), buy ads (ink across several precincts), hold rallies (convert ink to committed votes), or form coalitions with other candidates (shared ink: two issues printed over each other create a "blend" colour that counts for both players when a bloc cares about both). Endorsements from unions, papers, and neighbourhood associations are auctioned. On election night, each precinct's majority is computed by matching ink coverage to blocs' issue weights; precinct winners take seats; most seats wins, with coalition seat-sharing optionally creating a governing majority. Polls give noisy information.
- **Pillars:**
  1. **Ink is influence.** The map literally shows each campaign as printed layers.
  2. **Coalitions are double-edged.** Shared blends help both partners and blur identity.
  3. **Noisy information.** Polls are estimates; spending on polling sharpens them.
  4. **Light satire, no real parties.** Fictional, even-handed politics.
- **Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Paper `#F4F0E6`, riso fluorescent pink `#FF48B0`, teal `#00838A`, yellow `#FFE800`, medium blue `#3255A4`, orange `#FF6C2F`, black `#000000`; overprint blends computed multiplicatively. |
| Shapes | Hand-cut collage of city blocks, halftone photos of fictional candidates (generated illustrations), flyer shapes. |
| Typography | Grotesk display (Helvetica Neue Condensed, system) and a typewriter face for news. |
| Motion | Ink drums roll across precincts; misregistration jitter; election night tally ticker. |
| Music | 1970s funk and soft-rock pastiche (original). |
| SFX | Mimeograph thump, crowd cheer, phone ring, typewriter. |
| Haptics | Drum roll on ad buys; strong pulse when a precinct flips. |

- **Inspirations:** Risograph printing guides (Riso Kagaku colour library); Twilight Struggle and El Grande for area influence; Campaign Manager 2008; Banfield and Wilson, "City Politics" (1963).

## 2. Tech Stack Decision

Per `_CONVENTIONS.md` §2, plus:
- **Ink model:** each precinct stores integer ink per (player, issue); blends counted per pair of coalition partners.
- **Risograph shader:** Metal fragment shader compositing ink layers with multiply blend, grain, and offset (render only).
- **PlayerView:** hides other players' polling results and sealed endorsement bids.
- ADRs: ADR-0003 ink and bloc model; ADR-0004 coalition rules; ADR-0005 polling noise.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/PCCore/Sources/PCCore/
  City/      Precinct.swift, Bloc.swift, Issue.swift, Map.swift
  Campaign/  Volunteers.swift, Funds.swift, Ink.swift, Canvass.swift, Ads.swift, Rally.swift, Coalition.swift, Endorsement.swift, Polling.swift
  Election/  Tally.swift, Seats.swift, Government.swift
  Engine/    GameState.swift, PlayerView.swift, Action.swift, Event.swift, Reducer.swift, Week.swift
Packages/PCContent/  CityDef.swift, EndorserDef.swift, EventDef.swift, CandidateDef.swift, Loader.swift
Packages/PCAI/       ISMCTS.swift, Strategist.swift, Personalities.swift, CoalitionNegotiator.swift
Packages/PCRender/   CityScene.swift, RisoShader.metal, InkLayer.swift, ElectionNight.swift
Packages/PCMeta/     Campaigns.swift, Stats.swift
Resources/Content/   cities.json, endorsers.json, events.json, candidates.json, balance.json, tutorial.json
```

## 4. Core Rules Specification

**City**
- R-1 Each precinct has voters (in figures of 100) split into blocs; each bloc has issue weights summing to 10 and a turnout base.
- R-2 Campaign length: 8 weeks; each week is one round.

**Week**
- R-3 Income: each player gets volunteers (default 6) and funds (by fundraising track).
- R-4 Actions (in turn order, one at a time, until all pass): Canvass (1 volunteer: +2 ink of one issue in one precinct), Ad (funds: +1 ink of one issue in up to 4 adjacent precincts), Rally (2 volunteers + 1 fund: convert up to 3 of your ink in a precinct into committed votes in that precinct's best-matching bloc), Poll (1 fund: reveal estimated bloc preferences in 3 precincts with noise ±σ), Fundraise (2 volunteers: +1 fundraising track).
- R-5 Event card each week (seeded): strikes, scandals, transit breakdowns; shifts bloc weights or turnout.
- R-6 Endorsements: each week one endorser is up; sealed bids of funds; the winner gets the endorser's effect (for example union: +1 Jobs ink in all industrial precincts).

**Coalitions**
- R-7 Two players may form a coalition by mutual consent (AI accepts by utility); each names one issue to share. In precincts where both have ink in their shared issues, the overlapping amount counts as blended ink for both players' tallies (both get credit up to the overlap).
- R-8 Coalitions may be broken at the start of a week (the breaker loses 1 ink per shared precinct, "betrayal").

**Election night**
- R-9 For each bloc in each precinct: each player's appeal = Σ issue weight × the player's ink in that issue (including blends) + committed votes; votes go to the highest appeal (ties split); turnout modified by events.
- R-10 Precinct winner takes the seat. Most seats wins; ties by total votes. Optional governing-majority variant: coalition partners' seats combined.

**Invariants**
- INV-1 Volunteer and fund conservation.
- INV-2 PlayerView hides private polls and sealed bids (property test).
- INV-3 Blend credit never exceeds either partner's ink.
- INV-4 Replay determinism.
- INV-5 Tally equals brute-force recount.

## 5. Data Schemas and Content Tables

```swift
struct Bloc: Codable, Hashable, Sendable { var id: String; var voters: Int; var weights: [Issue: Int]; var turnout: Int }
struct Precinct: Codable, Hashable, Sendable { var id: String; var blocs: [Bloc]; var neighbours: [String]; var ink: [PlayerID: [Issue: Int]]; var committed: [PlayerID: Int] }
enum Action: Codable, Hashable { case canvass(PrecinctID, Issue), ad([PrecinctID], Issue), rally(PrecinctID), poll([PrecinctID]), fundraise, bid(Int), proposeCoalition(PlayerID, Issue), respondCoalition(Bool), breakCoalition, pass }
```

| Table | G3 | G5 | Sample row |
| --- | --- | --- | --- |
| `cities.json` | 2 | 5 | `{ "id": "port_ellery", "precincts": 20, ... }` |
| `endorsers.json` | 10 | 20 | `{ "id": "haulers_local", "effect": {"ink": "jobs", "tag": "industrial", "n": 1} }` |
| `events.json` | 24 | 60 | `{ "id": "bus_strike", "effect": {"weights": {"transit": "+2"}}, "label": "Invented" }` |
| `candidates.json` | 8 | 16 | fictional candidates with starting strengths |

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| Volunteers per week | 6 | 4–8 | `balance.json` |
| Poll noise σ | 15% | 5–25% | `balance.json` |
| Betrayal penalty | 1 | 0–2 | `balance.json` |
| Weeks | 8 | 6–10 | `balance.json` |

Targets: 4-player seat win shares 22–28%; coalitions formed in 40–70% of games; precinct flips in the final week 10–25%; average margin 1–4 seats.

## 7. AI Approach

- **ISMCTS** with determinised polling truths; rollouts with strategist heuristics; coalition negotiator evaluates expected seat gain.
- **Personalities (data):** Machine (canvass heavy), Reformer (polls and ads), Populist (rallies), Dealmaker (coalitions).
- **Tiers:** Volunteer, Organiser, Boss.

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7.

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- PC-P1.1 City, ink, actions, events, endorsements (R-1 to R-6).
- PC-P1.2 Coalitions and blends (R-7, R-8); tally (R-9, R-10).

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-10 tests; INV-1…INV-5
  [ ] PCCore coverage ≥ 90%; make sim N=2000 deterministic
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5.
- PC-P2.1 City map with ink layers (placeholder shader); action tray; poll panel with error bars; coalition proposal sheet; election night.
- PC-P2.2 Organiser AI.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test completes a 3-player campaign on iPad and Mac
  [ ] Election-night results equal Core tally
  [ ] `docs/SLICE_ASSESSMENT.md` written: self-assessment against the pillars, with every weakness turned into a P3 task (`_CONVENTIONS.md` §8.1)
Sign-off: GLM-SELF
```

### P3 Content and Systems
- PC-P3.1 G3 content; tutorial (4 lessons); pass-and-play privacy for polls and bids.

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts met; lint clean; 1,000 sims
Sign-off: GLM-SELF
```

### P4 AI Opponents
- PC-P4.1 Personalities; tiers; `docs/BALANCE.md`.

```
GATE G4 — AI
Checks:
  [ ] Boss win share ≥ 40% in 4-player vs Volunteers; targets met; p95 ≤ 800 ms
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- PC-P5.1 G5 counts; career mode (council → mayor); 20 achievements; HANDOFF.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Counts met; HANDOFF complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- PC-P6.1 Risograph shader; collage art; generated-illustration candidates reviewed for bias.
- PC-P6.2 Music and SFX.

```
GATE G6 — Aesthetics
Checks:
  [ ] Snapshots approved; 120 fps
Sign-off: GLM-SELF
```

### P7 Platform Features
- PC-P7.1 Async with private polls and bids; Game Center; iCloud; poster export of the final map.

```
GATE G7 — Platform
Checks:
  [ ] Async 4-player completes; private data unreadable by other clients
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- PC-P8.1 Issues identified by pattern and icon, not ink colour alone (crucial: the theme is colour); VoiceOver precinct summaries.

```
GATE G8 — Polish
Checks:
  [ ] Color-blind simulations pass for all five inks plus blends; VoiceOver game
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

1. Canvass adds exactly 2 ink of the chosen issue to one precinct.
2. Ad spreads 1 ink to up to 4 adjacent precincts; non-adjacent targets are rejected.
3. Blend credit equals min(partner A ink, partner B ink) in shared issues.
4. Breaking a coalition applies the betrayal penalty in every shared precinct.
5. Sealed endorsement tie resolves by turn order.
6. Poll noise uses the seeded RNG; the same seed gives the same poll.
7. Tally tie in a precinct splits votes and awards the seat by total votes.
8. PlayerView hides other players' polls.

## 9. Fragile Areas and Priorities

- **Fragile areas:** blend counting with multiple coalitions (max one coalition per player at launch), poll noise seeding.
- **Priorities for P6–P10:** riso shader, accessibility for colour; balance, satire tone review.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Colour-dependent design | High | High | Patterns and icons for issues | GLM |
| Political offence | Low | Medium | Fictional city, even-handed satire | GLM |

## 11. Out of Scope

Real elections; national politics; real-time debates.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 2 |
| P1 | GLM | 5–7 |
| P2 | GLM | 5–7 |
| P3 | GLM | 4–6 |
| P4 | GLM | 5–7 |
| P5 | GLM | 3–5 |
| P6 | GLM | 7–10 |
| P7 | GLM | 4–6 |
| P8 | GLM | 3–5 |
| P9 | GLM | 4–6 |
| P10 | GLM | 2–3 |
| **Total** | | **44–64** |

## 13. Open Questions

1. Allow multiple coalitions per player? Default: one.

## Appendix A. Extended Specification (Depth Pass)

### A.1 Additional Rules

**Ink and decay**
- R-11 Ink per precinct per player per issue is an integer 0–12 (cap). Ink above the cap is lost.
- R-12 Decay: at the end of weeks 2, 4, and 6, each player loses 1 ink of each issue in each precinct where they have ≥ 3 of that issue (campaigns fade without upkeep); committed votes never decay.
- R-13 Ads (R-4) must target a connected set of up to 4 precincts (adjacency in data); the cost is 1 fund per precinct.
- R-14 Fundraise (R-4 action): +2 funds, and the fundraising track advances 1 (track gives +1 weekly income at steps 2, 4, and 6).

**Polling**
- R-15 Polls reveal each bloc's weights with noise: each weight shown as `true ± k` where `k` is drawn from {−σ..σ} (seeded per player per poll), σ = 2 at launch; the noise is persistent per player-precinct-week (re-polling the same week gives the same result).
- R-16 Public polls (events) reveal noisy estimates to all players.

**Endorsements**
- R-17 Endorsement bids are sealed (commitment hashing in async); ties go to the player with fewer endorsements so far, then turn order.
- R-18 An endorser's effect applies immediately and its ink decays normally.

**Coalitions detail**
- R-19 At most one coalition per player at a time. Coalition proposals specify each side's shared issue; both issues may be the same.
- R-20 Blend credit (R-7): in a precinct, for partner A's shared issue i and partner B's shared issue j, blended amount = min(A.ink[i], B.ink[j]); each partner adds the blended amount to the other partner's issue for appeal purposes (A counts it as j-ink, B counts it as i-ink).
- R-21 Breaking a coalition (R-8): the breaker loses 1 ink of their shared issue in every precinct with blended ink > 0.

**Election night detail**
- R-22 Turnout per bloc = base turnout + events + 5% per rally held in that precinct (cap +15%), rounded down to 100-voter figures.
- R-23 Seats: one per precinct; at-large variant awards 3 extra seats by citywide proportional allocation (largest remainder).
- R-24 Recount: precincts decided by ≤ 1% are flagged; the tally is deterministic, so recount only re-renders (theatre, not RNG).

### A.2 Additional Invariants
- INV-6 Ink never exceeds the cap; decay never makes ink negative.
- INV-7 Poll results for a player-precinct-week are stable (R-15).
- INV-8 Committed votes in a precinct ≤ total voters of its best-matching bloc.
- INV-9 Sealed bids revealed only after all bids are committed.

### A.3 Complete Schemas and Sample Rows

```swift
struct CityDef: Codable, Sendable { var id: String; var name: String; var precincts: [PrecinctDef]; var tags: [String: [String]] }
struct PrecinctDef: Codable, Sendable { var id: String; var name: String; var blocs: [Bloc]; var neighbours: [String]; var tags: [String]; var shape: String /* SVG path id */ }
struct EndorserDef: Codable, Sendable { var id: String; var name: String; var effect: EndorseEffect; var week: Int? }
enum EndorseEffect: Codable, Sendable { case ink(Issue, tag: String, n: Int), funds(Int), volunteers(Int), turnout(tag: String, percent: Int) }
struct PollResult: Codable, Sendable { var precinct: String; var week: Int; var blocs: [String: [Issue: Int]] }
struct Coalition: Codable, Hashable, Sendable { var a: PlayerID; var b: PlayerID; var issueA: Issue; var issueB: Issue; var formedWeek: Int }
```

```json
{ "id": "harbor_flats", "name": "Harbor Flats", "blocs": [{"id": "dockworkers", "voters": 1800, "weights": {"jobs": 4, "housing": 3, "safety": 1, "transit": 1, "schools": 1}, "turnout": 55}, {"id": "young_renters", "voters": 1200, "weights": {"housing": 5, "transit": 3, "jobs": 1, "schools": 0, "safety": 1}, "turnout": 40}], "neighbours": ["old_market", "rail_yard"], "tags": ["industrial", "waterfront"], "shape": "p07" }
{ "id": "haulers_local", "name": "Freight Haulers Local 12", "effect": {"ink": ["jobs", "industrial", 1]} }
{ "a": "p1", "b": "p3", "issueA": "housing", "issueB": "transit", "formedWeek": 3 }
```

### A.4 Balance Tables and Sim Targets

| Parameter | Default | Range | Sim Target |
| --- | --- | --- | --- |
| Volunteers per week | 6 | 4–8 | 20–40 actions per player per game |
| Ink cap | 12 | 8–15 | Cap reached in ≤ 10% of precinct-issues |
| Decay threshold | 3 | 2–4 | Late-campaign swings: ≥ 20% of seats change leader after week 6 |
| Poll σ | 2 | 1–3 | Polls bought 4–10 per player |
| Coalition betrayal cost | 1/precinct | 0–2 | Coalitions broken in 15–35% of games |
| Personality balance | — | — | Each personality wins 20–30% in 4-bot games |

Seat-margin check: median winning margin 1–4 seats in 20-precinct cities; < 10% of games decided by citywide votes tie-break.

### A.5 AI Design in Detail
- **Determinisation:** sample hidden bloc weights consistent with the bot's own polls (posterior uniform over ±σ) and public info.
- **Rollout policy:** canvass the issue with the highest estimated weight in swing precincts (where appeal difference ≤ 2 ink-equivalents); ads in clusters of swing precincts; rally in week 7–8 where appeal leads are narrow.
- **Coalition negotiator:** estimate seat gain with and without coalition over 64 determinised rollouts; propose or accept if gain ≥ 1 seat; Dealmaker threshold 0.5.
- **Endorsement bids:** value = expected seat gain × funds-per-seat estimate; bid 60–90% of value by personality.

### A.6 Granular Task Breakdown

| ID | Task | Acceptance Criteria |
| --- | --- | --- |
| PC-P1.1 | City, precincts, blocs (R-1) | Lint: weights sum to 10 |
| PC-P1.2 | Week flow and income (R-2, R-3, R-14) | INV-1 |
| PC-P1.3 | Canvass, ads, rally (R-4, R-11, R-13) | INV-6, INV-8 |
| PC-P1.4 | Decay (R-12) | 10 fixtures |
| PC-P1.5 | Polls (R-15, R-16) | INV-7 |
| PC-P1.6 | Events and endorsements (R-5, R-6, R-17, R-18) | INV-9 |
| PC-P1.7 | Coalitions (R-7, R-8, R-19–R-21) | INV-3; 20 fixtures |
| PC-P1.8 | Election night (R-9, R-10, R-22–R-24) | INV-5 |
| PC-P2.1 | Risograph map with ink overprint (multiply blend) | Snapshot tests |
| PC-P2.2 | Poll overlay with noise bands | Matches Core |
| PC-P2.3 | Election-night reveal animation | Reveal order matches tally |
| PC-P3.1 | 2 cities, 10 endorsers, 24 events | Lint; all fictional names |
| PC-P4.1 | ISMCTS and personalities | Targets met |
| PC-P5.1 | Async with commitments | 2-device test |

### A.7 Sharpened Gate Checks
- G1 adds: blend fixtures for same-issue and cross-issue coalitions; INV-3 property test.
- G3 adds: name lint — no real party, union, politician, or city names (deny-list).
- G4 adds: no personality above 32% in 4-bot sims.

### A.8 Additional Risks

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Perceived partisan bias | Medium | High | Fictional issues framing; symmetric parties; deny-list | GLM |
| Real-world names slip into content | Medium | Medium | Deny-list lint (real unions removed, e.g., renamed the sample union) | GLM |
| Election-year App Review sensitivity | Low | Medium | No real elections, no voter-guidance claims | GLM |

### A.9 Additional Open Questions (Defaults)
1. Include negative campaigning? Default: no at launch.
2. Show bloc names as demographics? Default: interest-based names (dockworkers, young renters), never race or religion.
3. Ranked-choice variant? Default: post-launch.
