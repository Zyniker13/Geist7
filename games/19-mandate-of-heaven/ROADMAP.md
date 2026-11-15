# 19 — Mandate of Heaven Roadmap

> As a Han dynasty court astronomer, learn the hidden rules of the sky, stake your reputation on predictions, and catch rivals who falsify the records.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 in full before starting. Depth pass (15 Nov 2026): Appendix A extends §4–§13 and wins where they differ. This roadmap adds only what is specific to Mandate of Heaven.

Research: [`RESEARCH.md`](RESEARCH.md) (art direction, design lineage, cultural context, advisor institutions, verified glossary, and audio direction).

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 19 · `mandate-of-heaven` |
| Code prefix | `MH` (packages `MHCore`, `MHContent`, `MHAI`, `MHRender`, `MHAudio`, `MHPlatform`, `MHMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Deduction and forecasting strategy with court intrigue |
| Difficulty tier | Deep |
| Scope | Small team |
| Session length | 30–60 minutes per reign; campaign of 4 reigns |
| Renderer | SpriteKit sky dome projection plus SwiftUI court panels in lacquer style |
| Players | Solo vs rival astronomers (AI); pass-and-play 2–3 |
| Simulation | Turn-based monthly turns; procedurally generated hidden sky model per game (seeded) |
| Sourcing tier | `FULL` (Chinese astronomy and cosmology; living cultural heritage) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** see above.
- **Summary:** Each game generates a hidden "sky": periods and phases for 5 wandering stars (planets), a lunar cycle with nodes (for eclipses), comet probabilities, and a few "guest star" events, all governed by integer cycles with small perturbations. Players observe each month (choose which instruments and lodges to watch: the 28 lunar lodges (xiu) are the celestial coordinate system), record observations in their own ledgers, and submit predictions to the throne (for example "Eclipse in the 7th month", "Mars enters the Heart lodge in the 3rd month"). Correct predictions raise favour; failures lower it. Omens matter politically: the court interprets events against the emperor's virtue; predicting an eclipse lets the court prepare rites (favour bonus), while unexpected eclipses harm the dynasty's stability. Rival astronomers also predict and may falsify records; the player can audit archives (compare records with their own observations) and denounce falsifiers at risk. After 4 reigns, the highest favour plus accuracy wins; the dynasty's stability track determines the epilogue.
- **Pillars:**
  1. **Learn a real model.** The sky is lawful; patient observation pays.
  2. **Bets with stakes.** Predictions are wagers of favour.
  3. **Truth as a resource.** Records can be falsified; audits and denunciations are risky.
  4. **Cultural respect.** Cosmology presented accurately with advisors; no fortune-telling claims.
- **Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Lacquer black `#1A1414`, cinnabar `#B3261E`, bronze `#8C6A3E`, jade `#5E8C6A`, silk `#EDE3CB`, night sky `#0E1426`, star white `#F5F1E0`, lodge lines gold `#C8A04A`. |
| Shapes | TLV mirror cosmograms (square earth, round heaven), armillary rings, bamboo-slip ledgers, star charts in the style of the Dunhuang Star Chart (original renderings; note the chart is Tang-era or slightly later, centuries after the Han setting, and is used only as a style source). |
| Typography | SF Pro and a Song-style serif for Chinese terms (Songti SC, system); Chinese terms shown with pinyin. |
| Motion | Sky rotates through the night; predictions sealed with a chop; eclipse darkening. |
| Music | Guqin and bianzhong bell textures (commissioned). |
| SFX | Water clock drip, bronze bell, bamboo slip clack. |
| Haptics | Seal stamp; low pulse at eclipse. |

- **Inspirations:** Needham, "Science and Civilisation in China", vol. 3; Cullen, "Astronomy and Mathematics in Ancient China: The Zhou Bi Suan Jing" (1996); Pankenier, "Astrology and Cosmology in Early China" (2013); Sivin, "Granting the Seasons" (2009); the Dunhuang Star Chart (British Library; Tang-era or later style source).

## 2. Tech Stack Decision

Per `_CONVENTIONS.md` §2, plus:
- **Sky model:** integer cycles (periods in days with rational phase offsets) and bounded perturbations, all in `Fixed`; positions mapped to lodges by angle tables (4096-step circle).
- **Deduction support:** player ledger stored as observations; optional in-game "calculating rods" tool computes averages and periods from the player's own data (no hidden info).
- ADRs: ADR-0003 sky model; ADR-0004 prediction types and resolution windows; ADR-0005 falsification and audit.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/MHCore/Sources/MHCore/
  Sky/       SkyModel.swift, Wanderer.swift, Moon.swift, Eclipse.swift, Comet.swift, GuestStar.swift, Lodges.swift, Generator.swift
  Observe/   Instrument.swift, Observation.swift, Ledger.swift, Weather.swift
  Court/     Favour.swift, Stability.swift, Prediction.swift, Rites.swift, Archive.swift, Falsification.swift, Denunciation.swift
  Engine/    GameState.swift, PlayerView.swift, Action.swift, Event.swift, Reducer.swift, Month.swift, Reign.swift, Score.swift
Packages/MHContent/  LodgeDef.swift, InstrumentDef.swift, OmenDef.swift, RivalDef.swift, ReignDef.swift, GlossaryDef.swift, Loader.swift
Packages/MHAI/       RivalAstronomer.swift (Bayesian estimator), Falsifier.swift, CourtAI.swift
Packages/MHRender/   SkyScene.swift, LodgeOverlay.swift, CourtView.swift, LedgerView.swift
Packages/MHMeta/     Campaign.swift, Stats.swift
Resources/Content/   lodges.json, instruments.json, omens.json, rivals.json, reigns.json, glossary.json, balance.json, tutorial.json, cultural_manifest.json
```

## 4. Core Rules Specification

**Sky**
- R-1 The generator creates: 5 wanderers with synodic periods sampled near historical values (± 10%) and phase offsets; a moon with a 29.53-day mean month and a node cycle; eclipse rules (lunar or solar when new or full moon is within a node window); comets with seeded appearance chances; 0–2 guest stars per game.
- R-2 Positions are lodge indices (28 lodges with unequal widths per `lodges.json`, Attested values).

**Month turn**
- R-3 Each month: (1) weather (clouds hide observations by probability per season); (2) player chooses up to 3 observations (instrument + target); (3) observations recorded (with instrument error ± k); (4) predictions may be submitted (up to 2 per month) and are sealed; (5) events occur; predictions resolve; (6) court phase.
- R-4 Prediction types: eclipse in month m (solar/lunar), wanderer W in lodge L in month m, conjunction of W1 and W2 in month m, comet appearance within a season. Stakes: favour wagered 1–5; payout by difficulty table.

**Court**
- R-5 Favour changes by prediction results; stability changes by unpredicted omens (−), predicted omens with rites (+ small), and the emperor's virtue track (data events).
- R-6 Archive: all astronomers' records are filed; a rival may falsify (alter an observation or backdate a prediction) per its personality.
- R-7 Audit: spend an action to compare one rival's archive entries for a month against your own observations; discrepancies beyond instrument error raise suspicion.
- R-8 Denounce: accuse a rival; if suspicion ≥ threshold and falsification occurred, the rival is dismissed (favour +); if wrong, your favour falls heavily.

**End**
- R-9 A reign lasts 24 months; campaign 4 reigns (the sky model persists; reigns test longer cycles). Score = favour + accuracy bonus; if stability reaches 0, the dynasty falls (campaign ends early, epilogue).

**Invariants**
- INV-1 Sky model determinism: the same seed gives the same positions for 100 years.
- INV-2 PlayerView never exposes the hidden model or rivals' unfiled ledgers.
- INV-3 Prediction resolution uses true model values only.
- INV-4 Replay determinism.
- INV-5 Eclipse generator yields 2–5 eclipses per simulated year on average (sanity bound).

## 5. Data Schemas and Content Tables

```swift
struct Wanderer: Codable, Hashable, Sendable { var id: String; var period: Fixed; var phase: Fixed; var perturbAmp: Fixed; var perturbPeriod: Fixed }
struct Observation: Codable, Hashable, Sendable { var month: Int; var target: Target; var lodge: Int?; var visible: Bool; var instrument: String }
struct Prediction: Codable, Hashable, Sendable { var by: PlayerID; var kind: PredictionKind; var month: Int; var stake: Int; var sealedAt: Int }
enum Action: Codable, Hashable { case observe(String, Target), predict(PredictionKind, month: Int, stake: Int), audit(PlayerID, month: Int), denounce(PlayerID), performRites, endMonth }
```

| Table | G3 | G5 | Sample row |
| --- | --- | --- | --- |
| `lodges.json` | 28 | 28 | `{ "index": 4, "name": "Xin", "en": "Heart", "width": 5, "label": "Attested" }` |
| `instruments.json` | 3 | 6 | `{ "id": "gnomon", "targets": ["sun"], "error": 1, "label": "Attested" }` |
| `omens.json` | 12 | 30 | `{ "id": "solar_eclipse", "stability": -3, "ritesBonus": 1, "label": "Attested" }` |
| `rivals.json` | 4 | 8 | `{ "id": "rival_ambitious", "skill": 0.7, "falsify": 0.25 }` |
| `reigns.json` | 2 | 4 | `{ "id": "reign_1", "virtueEvents": [...] }` |

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| Observations per month | 3 | 2–4 | `balance.json` |
| Cloud probability by season | 20–50% | — | `balance.json` |
| Instrument error | 1 lodge-step | 0–2 | `instruments.json` |
| Denounce threshold | 3 discrepancies | 2–5 | `balance.json` |

Targets: a Bayesian bot reaches ≥ 70% eclipse prediction accuracy by month 18; a naive bot ≤ 30%; rivals falsify in 30–60% of reigns; correct denunciations by the top bot ≥ 70% of attempts.

## 7. AI Approach

- **Rival astronomers:** Bayesian estimators over model parameters (particle filter with 2,000 particles, integer weights) learn from their own observations; skill parameter controls observations and particles.
- **Falsifiers:** decide to alter records when their prediction failed and audit risk is low.
- **Court:** data-driven reactions.

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7, SRC0.1, SRC0.2, HIST0.1 (Attested: 28 lodges, Han astronomical bureau, eclipse records and omen interpretation, instruments; Reconstructed: court procedures; Invented: sky generator, falsification mechanics).

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; SRC0.1, SRC0.2, HIST0.1 complete
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- MH-P1.1 Sky generator and lodges (R-1, R-2; INV-1, INV-5).
- MH-P1.2 Observation, prediction, court, archive, audit, denunciation (R-3 to R-9).

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-9 tests; INV-1…INV-5
  [ ] MHCore coverage ≥ 90%; make sim N=1000 deterministic
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5, SRC2.1, SRC2.2.
- MH-P2.1 Sky scene with lodge overlay; observation picker; ledger view with plots; prediction sealing; court results.
- MH-P2.2 One reign vs 2 rivals.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test completes a reign on iPad and Mac
  [ ] Manifest covers lodges names, glossary, and art; deny-list passes
  [ ] `docs/SLICE_ASSESSMENT.md` written: self-assessment against the pillars, with every weakness turned into a P3 task (`_CONVENTIONS.md` §8.1)
Sign-off: GLM-SELF
```

### P3 Content and Systems
- MH-P3.1 G3 content; About the Tradition (SRC3.1); HIST3.1; calculating rods tool.
- MH-P3.2 Tutorial (5 lessons: lodges, wanderers, moon and eclipses, predictions, archives).

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts met; lint clean; tutorial UI test
Sign-off: GLM-SELF
```

### P4 AI Opponents
- MH-P4.1 Particle-filter rivals; falsifiers; `docs/BALANCE.md`.

```
GATE G4 — AI
Checks:
  [ ] Targets in §6 met; rival month ≤ 100 ms
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- MH-P5.1 G5 counts; campaign; daily sky; 20 achievements; SRC5.1; HANDOFF.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Counts met; packet and HANDOFF complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- MH-P6.1 Lacquer UI; TLV mirror motifs; star chart art; SRC6.1 and SRC6.2 review by a historian of Chinese astronomy and a cultural advisor.
- MH-P6.2 Music and SFX.

```
GATE G6 — Aesthetics and Cultural Review
Checks:
  [ ] Advisor review filed as a `needs-maintainer` issue (SUBSTITUTED, `_SET2_ADDENDUM.md` §4); every entry still pending advisor review listed in that issue; snapshots approved
Sign-off: GLM-SELF
```

### P7 Platform Features
- MH-P7.1 Game Center, iCloud; Simplified and Traditional Chinese localisation (a maintainer decision filed as an issue; GLM ships String Catalogs ready for translation).

```
GATE G7 — Platform
Checks:
  [ ] iCloud round-trip; localisation tests
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- MH-P8.1 Ledger as accessible tables and Audio Graphs; VoiceOver sky navigation by lodge.

```
GATE G8 — Polish
Checks:
  [ ] VoiceOver reign; budgets met
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

- **Fragile areas:** generator realism versus learnability; prediction resolution windows.
- **Priorities for P6–P10:** ledger plots, accessibility; rival tuning; cultural packet.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Too hard to learn the sky | Medium | High | Calculating rods tool; tutorial | GLM |
| Presenting astrology as fact | Low | Medium | Framing as historical court practice | GLM |

## 11. Out of Scope

Real ephemeris mode (post-launch candidate); other dynasties.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 2 |
| P1 | GLM | 7–9 |
| P2 | GLM | 6–8 |
| P3 | GLM | 5–7 |
| P4 | GLM | 5–7 |
| P5 | GLM | 3–5 |
| P6 | GLM | 8–11 |
| P7 | GLM | 3–5 |
| P8 | GLM | 3–5 |
| P9 | GLM | 4–6 |
| P10 | GLM | 2–3 |
| **Total** | | **48–68** |

## 13. Open Questions

1. Add a real-sky mode using historical Han-era positions? Default: post-launch.

## 14. Sourcing Notes

- **Sources:** Needham vol. 3 (1959); Cullen (1996); Pankenier (2013); Sivin (2009); British Library Dunhuang Star Chart (Or.8210/S.3326; Tang dynasty or slightly later, 7th–10th century, with the exact date debated; a later style source, not evidence of Han practice).
- **Restricted elements:** no claims of real divination; ancestral rites shown respectfully as court practice, not as player-exploitable magic.
- **Glossary seeds (checked against British Library IDP and Pankenier; pending advisor):** xiu (宿, lunar lodge; 28 in total), Taishi ling (太史令, Grand Astrologer/Prefect of the Grand Scribes), tianming (天命, Mandate of Heaven), huntian (渾天, "enveloping heaven" cosmology, associated with the armillary sphere), gaitian (蓋天, "canopy heaven" cosmology).
- **Historical accuracy note:** Han astronomers could predict lunar eclipses reasonably but solar eclipse prediction was limited and unreliable; the game's prediction difficulty table reflects this (solar eclipses are the hardest).

## Appendix A. Extended Specification (Depth Pass)

### A.1 Additional Rules

**Sky model detail**
- R-10 Time unit is the day; a month turn covers one lunation (29 or 30 days, alternating by the generator's integer approximation of 29.53: 30-day months follow a 17-in-32 pattern, Invented approximation).
- R-11 Wanderer longitude (in du, 365¼ du per circuit as in the Chinese system; stored as quarter-du integers, 1,461 per circuit) = mean motion × t + phase + perturbation, where perturbation is a sum of up to 2 integer sinusoid approximations (lookup tables) to create retrograde-like loops for outer wanderers.
- R-12 Lodge of a longitude: cumulative lodge widths from `lodges.json` (sum must equal 365¼ du).
- R-13 Eclipse rule: a lunar eclipse occurs at full moon when the moon's distance from a node ≤ 12 du (data); a solar eclipse at new moon when ≤ 18 du and the "visibility" roll for the capital succeeds (solar eclipses are often not visible locally).
- R-14 Comets: per month chance from a slowly varying hidden rate; a comet appears in a seeded lodge and moves 1–3 lodges per month for 1–3 months.
- R-15 Guest stars: appear in a lodge and fade over 3–12 months; they are visible omens and can be predicted only by luck (never in difficulty table).

**Observation and prediction detail**
- R-16 Instruments (G3): gnomon (sun shadow; solstice timing; error ±1 day), clepsydra (timing; reduces eclipse timing error), armillary sphere (wanderer lodge; error ±1 lodge boundary in 20% of observations). Instruments need maintenance actions every 6 months or error doubles.
- R-17 Difficulty table (payout multiplier): wanderer-in-lodge 1×, conjunction 2×, lunar eclipse 2×, solar eclipse visible at the capital 4×, comet within season 3×.
- R-18 A prediction is sealed (hash in async) and resolves at the target month; ties among astronomers predicting the same event share the payout.

**Court detail**
- R-19 Stability 0–20; unpredicted solar eclipse −3, unpredicted comet −2, guest star −1; predicted with rites performed: +1. Favour 0–30 per astronomer.
- R-20 Falsification by rivals is recorded in a hidden ledger; audits compare entries against your observations only for months both observed with visible sky.
- R-21 Suspicion accrues +2 per discrepancy beyond instrument error; denounce threshold 4.

### A.2 Additional Invariants
- INV-6 Lodge widths sum to 365¼ du (1,461 quarter-du).
- INV-7 Eclipse frequency in 100-year sims: lunar 0.8–1.6 per year visible somewhere; solar visible at capital ≤ 0.6 per year (sanity bounds; tuneable).
- INV-8 Sealed predictions cannot be modified after sealing (hash check).
- INV-9 Audits never reveal months where the auditor's sky was clouded.

### A.3 Complete Schemas and Sample Rows

```swift
struct LodgeDef: Codable, Sendable { var index: Int; var name: String; var hanzi: String; var en: String; var widthQuarterDu: Int; var label: HistoryLabel }
struct InstrumentDef: Codable, Sendable { var id: String; var targets: [TargetKind]; var errorDays: Int?; var errorLodges: Int?; var maintenanceMonths: Int; var label: HistoryLabel }
struct SkyModel: Sendable { var wanderers: [Wanderer]; var moon: MoonModel; var cometRate: [Int]; var guestStars: [GuestStar] }
struct MoonModel: Sendable { var nodePeriodDays: Int; var nodePhase: Int }
struct ArchiveEntry: Codable, Hashable, Sendable { var astronomer: PlayerID; var month: Int; var observation: Observation; var falsified: Bool /* hidden */ }
struct RivalDef: Codable, Sendable { var id: String; var skill: Int /* percent */; var falsify: Int /* percent */; var particles: Int }
```

```json
{ "index": 4, "name": "Xin", "hanzi": "心", "en": "Heart", "widthQuarterDu": 20, "label": "Attested" }
{ "id": "armillary", "targets": ["wanderer", "moon"], "errorLodges": 1, "maintenanceMonths": 6, "label": "Attested" }
{ "id": "rival_ambitious", "skill": 70, "falsify": 25, "particles": 2000 }
{ "kind": "lunarEclipse", "month": 37, "stake": 3, "sealedAt": 31 }
```

(Rival `skill` and `falsify` stored as integer percents to keep Core free of floating point; earlier §5 sample values 0.7 and 0.25 map to 70 and 25.)

### A.4 Balance Tables and Sim Targets

| Parameter | Default | Range | Sim Target |
| --- | --- | --- | --- |
| Observations per month | 3 | 2–4 | Skilled player predicts ≥ 60% of lunar eclipses by reign 2 |
| Cloud chance (by season) | 20–50% | — | ≥ 1 month in 4 has a missed key observation |
| Node window (lunar/solar) | 12/18 du | ±4 | INV-7 bounds |
| Instrument error | as data | — | Wanderer predictions 1 month ahead correct 70–85% for skilled play |
| Falsify rate (ambitious rival) | 25% | 10–40% | Audits catch ≥ 50% of falsifications when used monthly |
| Stability start | 12 | 8–16 | Dynasty falls in 10–25% of naive campaigns |

### A.5 AI Design in Detail
- **Particle filter:** each particle = full parameter vector (periods, phases, node phase) in integers; weights updated by likelihood of observations under instrument error (integer log-likelihood tables); systematic resampling with the game RNG stream `rival_k`.
- **Prediction policy:** rival predicts event e if posterior probability ≥ threshold by personality (cautious 0.8, ambitious 0.55) and stake = round(5 × (p − 0.5) × 2).
- **Falsification:** if a rival's prediction fails and estimated audit risk < falsify%, it backdates a prediction or alters an observation.
- **Hint engine for the player:** optional "junior astronomer" that shows the player's own posterior from their observations (same filter) on Easy difficulty only.

### A.6 Granular Task Breakdown

| ID | Task | Acceptance Criteria |
| --- | --- | --- |
| MH-P1.1 | Calendar and month lengths (R-10) | 1,000 months average 29.53 ± 0.01 |
| MH-P1.2 | Wanderer model and lodges (R-1, R-2, R-11, R-12) | INV-1, INV-6 |
| MH-P1.3 | Eclipses, comets, guest stars (R-13–R-15) | INV-5, INV-7 |
| MH-P1.4 | Observations, weather, instruments (R-3, R-16) | 20 fixtures |
| MH-P1.5 | Predictions and sealing (R-4, R-17, R-18) | INV-3, INV-8 |
| MH-P1.6 | Court, archive, audit, denounce (R-5–R-8, R-19–R-21) | INV-2, INV-9 |
| MH-P2.1 | Sky dome renderer with 28 lodges | 60 fps |
| MH-P2.2 | Bamboo-slip ledger UI | Entries match archive |
| MH-P2.3 | Prediction sealing ceremony UI | Hash visible in debug |
| MH-P3.1 | 28 lodges (Attested), instruments, omens | Lint; labels |
| MH-P3.2 | About: Han astronomy, later sources labelled | Dunhuang dating stated |
| MH-P4.1 | Particle-filter rivals | Targets met |
| MH-P5.1 | 4-reign campaign | Epilogues for each ending |

### A.7 Sharpened Gate Checks
- G1 adds: 100-year sky determinism across devices; INV-7 bounds in sims.
- G3 adds: lodge names and widths reviewed against a cited table; label Reconstructed where sources disagree.
- G5 adds: About text states the Dunhuang chart is Tang-era or later and used only for style.

### A.8 Additional Risks

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Players treat the game as astrology endorsement | Low | Medium | About frames omen culture historically | GLM |
| Lodge width sources disagree | High | Low | Choose one cited table; label | GLM |
| Particle filter cost | Medium | Medium | 500 particles on older devices | GLM |

### A.9 Additional Open Questions (Defaults)
1. Show hanzi for lodges? Default: yes, reviewed by advisor, with pinyin and English.
2. Use real Han emperors? Default: fictional reign names; Han only as setting.
3. Include the canopy vs. enveloping heaven debate as a tech choice? Default: flavour only.
