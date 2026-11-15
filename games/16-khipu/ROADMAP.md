# 16 — Khipu Roadmap

> Run an Andean state with no money and no markets: only labour owed, llama caravans, storehouses on the mountainside, and knotted cords that record it all, if the lords are telling the truth.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 in full before starting. Depth pass (15 Nov 2026): Appendix A extends §4–§13 and wins where they differ. This roadmap adds only what is specific to Khipu.

Research: [`RESEARCH.md`](RESEARCH.md) (art direction, design lineage, cultural context, advisor institutions, verified glossary, and audio direction).

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 16 · `khipu` (working title; see §13) |
| Code prefix | `KH` (packages `KHCore`, `KHContent`, `KHAI`, `KHRender`, `KHAudio`, `KHPlatform`, `KHMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Moneyless economic grand strategy (solo; optional rival-polity AI) |
| Difficulty tier | Hardcore |
| Scope | Larger team |
| Session length | 2–4 hours per campaign; saves anywhere |
| Renderer | SpriteKit 2.5D layered relief map (vertical altitude bands) with SwiftUI ledger panels; khipu cords drawn procedurally |
| Players | Solo |
| Simulation | Turn-based seasonal turns (wet and dry seasons), deterministic with seeded weather |
| Sourcing tier | `FULL` (Andean Indigenous peoples: Quechua and Aymara communities; Inka state history and khipu) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** see above.
- **Summary:** The map is a set of valleys, each spanning four altitude zones (coastal/yunga lowlands, quechua valleys for maize, suni highlands for potatoes and quinoa, and puna grasslands for camelid herds). Communities (ayllus) owe rotating labour (modelled on mit'a) and receive reciprocity in return: feasts, tools, and stored food in bad years. The player, as a state administrator, assigns labour turns to fields, terraces, roads, storehouses (qullqa), and caravans. Goods never trade for money; they move by caravan along roads and are stored, spoil at altitude-dependent rates (freeze-drying to ch'uñu reduces spoilage), and are redistributed. Local lords (kurakas) report output; some misreport. Khipu are the record: each report is a cord with knots, and the player can audit by sending inspectors, comparing cords with physical storehouse counts. Shocks (El Niño floods, frosts, droughts, earthquakes) test the reserves. Goals: keep every ayllu above the reciprocity threshold (or they withdraw labour or revolt) while building the network to survive the century.
- **Pillars:**
  1. **No money, all obligation.** The economy runs on labour owed, goods stored, and reciprocity honoured.
  2. **Verticality matters.** Each altitude zone produces different goods; caravans connect them.
  3. **Records can lie.** Knowledge is imperfect; audits cost labour and trust.
  4. **Andean partnership.** Quechua and Aymara advisors shape representation; language support for Quechua and Aymara terms is reviewed.
- **Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Puna gold `#C7A867`, suni green `#7F9455`, quechua maize `#D8B23F`, yunga green `#3E6B3E`, stone grey `#8E8778`, terrace ochre `#B07A42`, cochineal red `#A0283A`, indigo `#2E3F6E`, alpaca cream `#E9DFC9`, night sky `#121A2E`. |
| Shapes | Terraces as stepped contour bands; storehouses as round and rectangular qullqa (older spelling qollqa; Spanish collca); cords as hanging strands with knot types (single, long, figure-eight). Textile-inspired UI borders (tocapu-like geometric motifs only after advisor approval; until then generic step-fret). |
| Typography | SF Pro; Quechua and Aymara words in their standardised alphabets (advisor-verified). |
| Motion | Caravans walk switchback roads; stores fill and empty; cords gain knots as reports arrive. |
| Music | Andean instruments (siku, quena, charango) performed by Andean musicians (commissioned by the maintainer through a `needs-maintainer` issue). |
| SFX | Llama bells, wind, stone, river. |
| Haptics | Soft knot tick for each recorded report. |

- **Inspirations:** Murra, "The Economic Organization of the Inka State" (1956/1980) and the "vertical archipelago"; Urton, "Signs of the Inka Khipu" (2003) and "Inka History in Knots" (2017); D'Altroy, "The Incas" (2nd ed., 2014); Medrano and Urton on khipu census decipherment (2018); LeVine on Inka storage.

## 2. Tech Stack Decision

Per `_CONVENTIONS.md` §2, plus:
- **Simulation:** integer stocks per good per storehouse; flows computed per season by a deterministic scheduler; caravans as discrete agents on a road graph.
- **Khipu encoding:** reports encode numbers in base-10 knot positions (Locke's decimal convention), rendered from data; misreports change the encoded value.
- **Performance:** full season resolution ≤ 150 ms on iPad (base) for the largest map (40 valleys, 300 ayllus).
- ADRs: ADR-0003 economy model; ADR-0004 khipu representation (decimal positional, Attested); ADR-0005 reporting and audit model; ADR-0006 scheduler order.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/KHCore/Sources/KHCore/
  Land/      Valley.swift, Zone.swift, Field.swift, Terrace.swift, Road.swift, Bridge.swift, RoadGraph.swift
  People/    Ayllu.swift, Kuraka.swift, Labour.swift, Obligation.swift, Reciprocity.swift, Unrest.swift
  Goods/     Good.swift, Storehouse.swift, Spoilage.swift, Processing.swift (ch'uñu, charki)
  Logistics/ Caravan.swift, Route.swift, Scheduler.swift
  Records/   Report.swift, Khipu.swift, Audit.swift, Discrepancy.swift
  Shocks/    Weather.swift, ElNino.swift, Frost.swift, Quake.swift
  Engine/    GameState.swift, Action.swift, Event.swift, Reducer.swift, Season.swift, Score.swift
Packages/KHContent/  MapDef.swift, GoodDef.swift, BuildingDef.swift, ScenarioDef.swift, KurakaDef.swift, EventDef.swift, GlossaryDef.swift, Loader.swift, Validation.swift
Packages/KHAI/       Advisor.swift (planning assistant), KurakaBehavior.swift, RivalPolity.swift, Autoplay.swift
Packages/KHRender/   ReliefScene.swift, ZoneLayers.swift, CaravanNode.swift, KhipuRenderer.swift, LedgerViews/
Packages/KHMeta/     Scenarios.swift, Chronicle.swift, Stats.swift
Resources/Content/   maps.json, goods.json, buildings.json, scenarios.json, kurakas.json, events.json, glossary.json, balance.json, tutorial.json, cultural_manifest.json
```

## 4. Core Rules Specification

**Turn structure**
- R-1 Each year has two seasons: wet (Nov–Apr, planting and growth) and dry (May–Oct, harvest, building, caravans). One season per turn.
- R-2 Season order: (1) Weather draw (seeded; El Niño cycles from data); (2) Reports arrive (kuraka reports for last season); (3) Player orders (labour assignment, construction, caravan routes, feasts, audits, processing); (4) Resolution (production, spoilage, caravans move, construction progress); (5) Reciprocity and unrest; (6) Record (new khipu knots).

**Land and production**
- R-3 Each field has a zone, crop, base yield, and terrace level (0–3). Yield = base × (1 + 0.25 × terrace) × weather modifier × labour fraction, rounded down.
- R-4 Zones produce: yunga (coca (ritual good, see §14 restrictions), fruit, cotton), quechua (maize), suni (potatoes, quinoa), puna (camelid wool, charki, llamas for caravans).

**Labour**
- R-5 Each ayllu has households; it owes labour turns per season (`laborDuty × households`). The player assigns turns to tasks within reach (road distance ≤ 2 days) or to distant projects with travel costs.
- R-6 Reciprocity: each labour turn creates an obligation of food (maize beer and food at feasts) and goods; unpaid obligations raise unrest.

**Storage and spoilage**
- R-7 Storehouses have capacity and altitude; spoilage per season by good and altitude (higher is colder and drier, lower spoilage). Processing (ch'uñu from potatoes, charki from meat) converts goods to low-spoilage forms at a labour cost.

**Logistics**
- R-8 Caravans of llamas carry up to `llamaLoad × llamas`; move along roads at a speed per terrain; bridges are maintained by assigned labour or decay.

**Records and audits**
- R-9 Each kuraka has honesty (hidden, 0–100) and ambition. Reports may understate production (keeping surplus) or overstate storehouse contents. The khipu shows reported values.
- R-10 Audit: send an inspector (costs labour and kuraka trust); reveals true values for that district with certainty and adjusts honesty. Discrepancies can be punished (replace the kuraka: unrest +) or forgiven (trust +).
- R-11 The player sees only reported values for unaudited districts; the UI marks unaudited data with a cord-colour code and confidence band.

**Shocks**
- R-12 Weather and events from seeded tables; El Niño floods coast and droughts highlands.

**Unrest and end**
- R-13 Ayllu unrest > threshold → labour withdrawal (duty halves); further → revolt (district stops reporting and producing). Restoration via feasts and remitted duty.
- R-14 Scenario end after N years; score = population fed × years + storehouse reserve + infrastructure − unrest penalties; defeat if more than 40% of ayllus revolt.

**Invariants**
- INV-1 Goods conservation: production − consumption − spoilage − processing losses = Δ stock (ledgered).
- INV-2 Labour conservation per season.
- INV-3 Reported values differ from true values only through R-9 mechanisms (audit reveals exact true state).
- INV-4 Replay determinism.
- INV-5 Khipu rendering round-trip: decoding the rendered knot model gives the reported numbers.

## 5. Data Schemas and Content Tables

```swift
struct GoodDef: Codable, Sendable { var id: String; var zone: Zone; var spoilage: [Zone: Int] /* per mille per season */; var processesTo: String?; var processLabour: Int; var restricted: Bool }
struct Ayllu: Codable, Hashable, Sendable { var id: AylluID; var valley: ValleyID; var households: Int; var duty: Int; var obligationsOwed: Int; var unrest: Int; var kuraka: KurakaID }
struct Report: Codable, Hashable, Sendable { var kuraka: KurakaID; var season: Int; var reported: [GoodID: Int]; var trueHash: UInt64 /* for audit integrity tests only */ }
enum Action: Codable, Hashable { case assignLabour(AylluID, Task, turns: Int), build(BuildingID, at: SiteID), routeCaravan(CaravanID, [RoadID], load: [GoodID: Int]), holdFeast(ValleyID, goods: [GoodID: Int]), audit(DistrictID), punish(KurakaID), forgive(KurakaID), process(StorehouseID, GoodID, Int), endSeason }
```

| Table | G3 | G5 | Sample row |
| --- | --- | --- | --- |
| `maps.json` | 1 (12 valleys) | 3 (up to 40) | `{ "id": "southern_valleys", "valleys": [...], "roads": [...] }` |
| `goods.json` | 10 | 14 | `{ "id": "potato", "zone": "suni", "spoilage": {"suni": 80, "puna": 40, "quechua": 120}, "processesTo": "chuno", "processLabour": 2 }` |
| `buildings.json` | 10 | 18 | `{ "id": "qullqa_round", "capacity": 300, "labour": 40, "seasons": 2 }` |
| `kurakas.json` | 20 archetypes | 40 | `{ "id": "k_proud", "honesty": [40,80], "ambition": [50,90] }` |
| `events.json` | 20 | 50 | `{ "id": "elnino_strong", "effect": {"coast_flood": 2, "highland_drought": 1}, "label": "Attested" }` |
| `scenarios.json` | 2 | 6 | `{ "id": "first_terraces", "years": 25, "map": "southern_valleys" }` |
| `glossary.json` | 20 | 40 | ayllu, mit'a, kuraka, qullqa, khipu, ch'uñu, apu (restricted, see §14) |

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| Labour duty per household | 1 turn/season | 0.5–2 | `balance.json` |
| Terrace bonus per level | 25% | 15–35% | `balance.json` |
| Spoilage rates | per good | — | `goods.json` |
| Unrest thresholds | 50 / 80 | — | `balance.json` |
| Audit cost | 10 labour + 10 trust | — | `balance.json` |
| El Niño frequency | 1 per 7 years avg | 1/4–1/12 | `scenarios.json` |

Targets: Autoplay "competent" strategy survives the 25-year scenario with ≤ 10% revolt; "naive" (no storage) suffers famine within 10 years in ≥ 80% of seeds; dishonest kurakas cost 5–15% of output when unaudited; audit frequency for optimal play 10–25% of districts per year.

## 7. AI Approach

- **Kuraka behaviour:** data-driven policies combining honesty and ambition with perceived audit risk (Bayesian estimate of the player's audit rate).
- **Advisor:** an optional assistant suggesting labour allocations by linear-programming-like greedy allocation (integer, deterministic) to meet projected needs; the player can accept, modify, or ignore.
- **Autoplay bots:** competent and naive strategies for balance sims.
- **Rival polity (optional mode):** a neighbouring state with expansion policy as data, competing for valleys diplomatically (marriage alliances, gift exchange), not military conquest at launch.

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7, SRC0.1, SRC0.2, HIST0.1 (Attested: vertical archipelago, mit'a, qullqa, khipu decimal system, El Niño; Reconstructed: details of reciprocity amounts; Invented: numbers, audit mechanics).
- KH-P0.1 `docs/SOURCING.md` §3 states the game portrays a state system and must also depict ayllu communities with dignity, not as mere resources; §5 restricts sacred sites (huacas), apu mountain deities, and ritual practices from being game resources.

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; SRC0.1, SRC0.2, HIST0.1 complete
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- KH-P1.1 Land, zones, production, terraces (R-3, R-4).
- KH-P1.2 Labour, reciprocity, unrest (R-5, R-6, R-13).
- KH-P1.3 Storage, spoilage, processing, caravans, roads (R-7, R-8).
- KH-P1.4 Reports, khipu encoding, audits (R-9 to R-11); shocks (R-12); end (R-14).

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-14 tests; INV-1…INV-5 over 1,000 seeds × 25 years
  [ ] Season resolution ≤ 150 ms on the largest test map; KHCore coverage ≥ 90%
  [ ] make sim N=200 (full campaigns) deterministic
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5, SRC2.1, SRC2.2.
- KH-P2.1 Relief map with altitude bands; valley detail panel; labour assignment board (drag household tokens onto tasks); storehouse ledger; caravan route drawing.
- KH-P2.2 Khipu viewer: cords per district with knots; tap a cord to read values; audit action.
- KH-P2.3 A 5-year slice scenario on one valley.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test completes the 5-year slice on iPad and Mac
  [ ] Khipu viewer values equal reported values (INV-5) for every report in a 25-year sim
  [ ] Manifest marks glossary, textile motifs, music, and kuraka names pending; deny-list passes
  [ ] `docs/SLICE_ASSESSMENT.md` written: self-assessment against the pillars, with every weakness turned into a P3 task (`_CONVENTIONS.md` §8.1)
Sign-off: GLM-SELF
```

### P3 Content and Systems
- KH-P3.1 G3 content; HIST3.1 labels; About the Tradition (SRC3.1) with advisor placeholders; glossary view.
- KH-P3.2 Tutorial campaign (6 chapters: zones, labour, storage, caravans, records, shocks).
- KH-P3.3 Save anywhere; chronicle of key events.

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts met; lint clean; 500 autoplay campaigns complete without softlocks
Sign-off: GLM-SELF
```

### P4 AI and Simulation Tuning
- KH-P4.1 Kuraka behaviour; advisor; autoplay bots; rival polity (optional mode); `docs/BALANCE.md`.

```
GATE G4 — AI
Checks:
  [ ] Targets in §6 met (or ADR)
  [ ] Advisor suggestion ≤ 500 ms; rival polity turn ≤ 200 ms
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- KH-P5.1 G5 counts (3 maps, 6 scenarios); seeded map variation; stats; 24 achievements; SRC5.1; HANDOFF.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Counts met; coverage thresholds; packet and HANDOFF complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- KH-P6.1 Relief art; terrace and storehouse sprites; khipu renderer polish (fibre textures, colours as data); Andean musicians' score.
- KH-P6.2 SRC6.1 and SRC6.2 advisor review (Quechua and Aymara cultural advisors and an Andean historian).

```
GATE G6 — Aesthetics and Cultural Review
Checks:
  [ ] Advisor review filed as a `needs-maintainer` issue (SUBSTITUTED, `_SET2_ADDENDUM.md` §4); every entry still pending advisor review listed in that issue; 60 fps on base iPad with largest map
Sign-off: GLM-SELF
```

### P7 Platform Features
- KH-P7.1 iCloud saves; Game Center achievements and scenario leaderboards; Mac multi-window (map plus ledgers); Spanish, Quechua (Southern Quechua), and Aymara localisation if the maintainer commissions translators (`needs-maintainer` issue).

```
GATE G7 — Platform
Checks:
  [ ] iCloud round-trip with 4-hour save; multi-window verified
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- KH-P8.1 VoiceOver ledgers and khipu (cords read as numbers); zone identification by pattern; Dynamic Type.
- KH-P8.2 Performance: background season resolution with progress; memory ≤ 600 MB.

```
GATE G8 — Polish
Checks:
  [ ] VoiceOver completes tutorial chapter 1–3; budgets met
Sign-off: GLM-SELF
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard tasks; SRC9.1 community playtest with Andean players and SRC10.1 credits, each prepared locally and filed as a `needs-maintainer` issue.

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

- **Fragile areas:** scheduler order (ADR-0006), spoilage at storehouse transfer, audit trust interplay.
- **Priorities for P6–P10:** ledger UI scale, performance, VoiceOver; economy tuning, kuraka policies, cultural packet.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Colonial or extractive framing | Medium | High | Advisors; ayllu dignity requirements; no conquest mechanics | GLM |
| Complexity overwhelms players | High | High | Advisor assistant, tutorial campaign | GLM |
| Simulation performance | Medium | Medium | Integer model, background resolution | GLM |
| GLM scope overrun | High | High | Strict phase gates; slice scenario first | GLM |

## 11. Out of Scope

Military conquest; Spanish colonial period; multiplayer; real-time.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 3 |
| P1 | GLM | 16–22 |
| P2 | GLM | 12–16 |
| P3 | GLM | 10–14 |
| P4 | GLM | 8–12 |
| P5 | GLM | 6–9 |
| P6 | GLM | 12–16 |
| P7 | GLM | 6–9 |
| P8 | GLM | 6–8 |
| P9 | GLM | 6–9 |
| P10 | GLM | 2–4 |
| **Total** | | **87–122** |

## 13. Open Questions

1. Title "Khipu" uses the name of a cultural record form; advisors may prefer another. Default: working title until the maintainer answers the advisor issue; GLM continues with it.
2. Portray the state as the Inka (Tawantinsuyu) explicitly or a generic Andean polity? Default: generic polity with labelled Inka parallels, pending advisor input.

## 14. Sourcing Notes

- **Sources:** Murra (1956/1980); Urton (2003, 2017); D'Altroy (2014); Medrano and Urton, "Toward the Decipherment of a Set of Mid-Colonial Khipus from the Santa Valley, Coastal Peru", Ethnohistory 65(1), 2018; LeVine, "Inka Storage Systems" (1992); Locke, "The Ancient Quipu" (1923).
- **Restricted elements:** huacas, apus, and ritual offerings (including coca in ritual use) are never consumable game resources; no mummy (mallqui) imagery; no conquest narratives.
- **Glossary seeds (spellings checked against Southern Quechua standard orthography in the research file; all pending advisor):** ayllu, mit'a, kuraka, qullqa (older spelling qollqa; Spanish collca), khipu, ch'uñu (Spanish chuño), ayni (reciprocal labour); charki (Quechua ch'arki, Spanish charqui) is Unverified for preferred spelling.

## Appendix A. Extended Specification (Depth Pass)

### A.1 Additional Rules

**Khipu record model**
- R-15 Each district's report is a khipu: a primary cord with pendant cords, one pendant per good (colour-coded by good category, data), with numbers encoded in base 10: long knots (2–9 turns) in the units position, a figure-eight knot for 1 in units, single knots for tens, hundreds, and thousands clusters, and an empty space for zero (Locke 1923; Urton 2003). Subsidiary cords carry sub-district values.
- R-16 Top cords (summation cords) display the sum of their pendants; a mismatch between a top cord and its pendants is a visible inconsistency that hints at misreporting (players learn to check sums).
- R-17 Reports arrive one season late (R-2 step 2) and only for districts connected by a maintained road to the administrative centre; disconnected districts send no report.

**Labour and reciprocity detail**
- R-18 Labour turns: each household provides `laborDuty` turns per season (default 1 wet, 2 dry). Tasks: farm (per field), terrace (+1 level, 6 turns, max 3), build (storehouse, bridge, road segment), process (ch'uñu, ch'arki), caravan (1 turn per 5 llamas), audit escort.
- R-19 Reciprocity cost per labour turn: 1 food unit + 1 maize beer unit (aqha, pending advisor) delivered at a feast within the same year; feasts are orders that consume goods and reduce unrest by 1 per 10 units delivered beyond obligations.
- R-20 Ayni (household-to-household reciprocal labour) is modelled implicitly: ayllus with low duty load produce a self-sufficiency surplus (data) that does not enter state storehouses.

**Storage detail**
- R-21 Spoilage per season (default %): maize 4/2/1 (low/mid/high altitude), potatoes 12/8/4, ch'uñu 0, charki 1, quinoa 2/1/1, wool 0, cotton 0.
- R-22 Storehouse capacity in goods units; round qullqa store potatoes and ch'uñu with −1 spoilage tier; rectangular qullqa store maize with −1 tier (LeVine 1992, simplified; label Reconstructed).

**Kuraka detail**
- R-23 Kuraka misreporting policy: if `honesty < 50` and perceived audit risk < (100 − honesty)/100, the kuraka understates production by up to `ambition`% and keeps the difference; at very low honesty (< 20), they may overstate storehouse contents to avoid deliveries.
- R-24 Audits cost 4 labour turns plus −5 trust with that kuraka; punishment replaces the kuraka (new kuraka honesty drawn from data range, unrest +2 in the district); forgiveness grants +10 honesty and −1 unrest.

**Events**
- R-25 El Niño years (scenario data): coastal yields −50%, highland yields −25%, floods damage 1 bridge per coastal valley. Frost events affect suni and puna only.

### A.2 Additional Invariants
- INV-6 Every top cord equals the sum of its pendants for honest reports; dishonest reports may break this only via R-23 overstatement paths (property test with honesty = 100 shows zero mismatches).
- INV-7 Disconnected districts never produce a report (R-17).
- INV-8 Spoilage never makes stock negative and is applied after production.
- INV-9 Feast deliveries ≤ stock at the feast's storehouse.

### A.3 Complete Schemas and Sample Rows

```swift
struct KhipuReport: Codable, Sendable { var district: String; var season: Int; var primary: [PendantCord]; var top: [TopCord] }
struct PendantCord: Codable, Sendable { var good: String; var colour: CordColour; var value: Int; var subsidiaries: [PendantCord] }
struct TopCord: Codable, Sendable { var sums: [Int] /* pendant indices */; var value: Int }
struct KurakaDef: Codable, Sendable { var id: String; var district: String; var honestyRange: ClosedRange<Int>; var ambition: Int; var portraitKey: String }
struct FieldDef: Codable, Sendable { var id: String; var valley: String; var zone: Zone; var crop: String; var baseYield: Int; var terrace: Int }
struct WeatherDef: Codable, Sendable { var id: String; var zones: [Zone: Int] /* percent */; var bridgeDamage: Int; var label: HistoryLabel }
```

```json
{ "district": "santa_lower", "season": 14, "primary": [{"good": "maize", "colour": "yellow", "value": 1240, "subsidiaries": []}, {"good": "potato", "colour": "brown", "value": 860, "subsidiaries": []}], "top": [{"sums": [0, 1], "value": 2100}] }
{ "id": "k_santa", "district": "santa_lower", "honestyRange": [30, 80], "ambition": 15, "portraitKey": "kuraka_generic_03" }
{ "id": "nino_strong", "zones": {"yunga": -50, "quechua": -25, "suni": -25, "puna": -15}, "bridgeDamage": 1, "label": "Attested" }
```

In the sample, the top cord (2,100) equals the sum of its pendants (1,240 + 860), so the report is consistent; a misreport would show, for example, pendants of 1,140 and 860 under a 2,100 top cord.

### A.4 Balance Tables and Sim Targets

| Parameter | Default | Range | Sim Target |
| --- | --- | --- | --- |
| Labour duty (wet/dry) | 1/2 | 1–3 | Competent bot uses 85–95% of labour |
| Terrace bonus per level | 25% | 15–35% | Terraces built on 30–60% of quechua fields by year 10 |
| Potato spoilage (low alt) | 12% | 8–16% | Processing share of potatoes 25–50% |
| Audit cost | 4 turns, −5 trust | — | Audits 1–3 per year (competent) |
| Kuraka ambition | 5–25% | — | Unaudited misreporting hides 3–10% of production |
| Revolt threshold | unrest 6 | 5–8 | Naive bot loses to revolt in 30–60% of runs |

Run 1,000 seeded 20-year scenarios per bot; competent bot survives ≥ 90% and stores ≥ 1 year of reserve by year 15 in ≥ 60%.

### A.5 AI Design in Detail
- **Advisor allocation:** greedy integer allocation over tasks ranked by marginal value per labour turn (projected food deficit reduction, spoilage avoided, unrest reduction), with constraints on reach and duty; deterministic tie-breaks.
- **Kuraka model:** perceived audit risk = Beta(α, β) updated by observed audits in neighbouring districts (α += audits, β += seasons without audit), deterministic arithmetic in Fixed.
- **Competent bot:** advisor allocation + audit when a top-cord mismatch or a production/rainfall mismatch > 15% appears + feasts when unrest ≥ 3.
- **Rival polity:** gift-exchange utility; accepts alliance when cumulative gifts ≥ threshold (data).

### A.6 Granular Task Breakdown

| ID | Task | Acceptance Criteria |
| --- | --- | --- |
| KH-P0.1 | SOURCING.md with Quechua orthography decision (Southern Quechua standard) | Glossary statuses set |
| KH-P1.1 | Fields, zones, yields (R-3, R-4) | 20 fixtures |
| KH-P1.2 | Labour duty and tasks (R-5, R-18) | INV-2 |
| KH-P1.3 | Reciprocity and feasts (R-6, R-19, R-20) | INV-9 |
| KH-P1.4 | Storage and spoilage (R-7, R-21, R-22) | INV-1, INV-8 |
| KH-P1.5 | Caravans, roads, bridges (R-8) | 15 fixtures |
| KH-P1.6 | Reports and khipu encoding (R-9, R-15–R-17) | INV-5, INV-6, INV-7 |
| KH-P1.7 | Kuraka policies and audits (R-10, R-23, R-24) | INV-3 |
| KH-P1.8 | Weather, El Niño, unrest, end (R-12–R-14, R-25) | 20 fixtures |
| KH-P2.1 | Khipu renderer with knot types and cord colours | Round-trip test (INV-5) |
| KH-P2.2 | Valley map with altitude bands | 60 fps |
| KH-P2.3 | Confidence bands on unaudited data (R-11) | Matches Core |
| KH-P3.1 | Content: 3 valleys, 10 buildings, 20 events | Lint |
| KH-P3.2 | Khipu-reading tutorial | UI test |
| KH-P4.1 | Advisor and bots | Targets met |
| KH-P5.1 | Rival polity mode | Sims in range |

### A.7 Sharpened Gate Checks
- G1 adds: khipu encoding fixtures for 0, 1, 9, 10, 11, 101, 1,240, and 9,999.
- G3 adds: no huaca, apu, or ritual good is consumable (lint against restricted list).
- G5 adds: glossary spellings listed in the advisor-review `needs-maintainer` issue; `docs/SOURCING.md` §4 marks each spelling pending until answered.

### A.8 Additional Risks

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| State-centric framing erases ayllu agency | Medium | High | Ayllu views, self-sufficiency surplus, revolt as legitimate | GLM |
| Khipu decipherment overclaimed | Medium | Medium | About states only numerical khipu are understood well; narrative khipu remain debated | GLM |
| Complexity overload | High | Medium | Advisor and progressive tutorial | GLM |

### A.9 Additional Open Questions (Defaults)
1. Quechua orthography: Southern Quechua standard (qullqa, ch'uñu) or older Hispanicised forms? Default: standard, with older forms in tooltips.
2. Include coca at all? Default: present only as a non-consumable ritual good that can never be spent.
3. Name the polity "Inka" or fictional? Default: as §13 (a generic Andean polity with labelled Inka parallels); the Inka named in About; scenario valleys fictionalised.
