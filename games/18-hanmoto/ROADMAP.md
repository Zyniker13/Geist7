# 18 — Hanmoto Roadmap

> Run an Edo-period print publisher: commission artists, carvers, and printers, stack the colour blocks in order, follow fashion, and stay one step ahead of the censors.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 in full before starting. Depth pass (15 Nov 2026): Appendix A extends §4–§13 and wins where they differ. This roadmap adds only what is specific to Hanmoto.

Research: [`RESEARCH.md`](RESEARCH.md) (art direction, design lineage, cultural context, advisor institutions, verified glossary, and audio direction).

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 18 · `hanmoto` |
| Code prefix | `HM` (packages `HMCore`, `HMContent`, `HMAI`, `HMRender`, `HMAudio`, `HMPlatform`, `HMMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Worker placement with production chains and a fashion market |
| Difficulty tier | Intermediate |
| Scope | Small team |
| Session length | 45–75 minutes |
| Renderer | SpriteKit with layered woodblock-print shader (registration, bokashi gradients, paper fibre) |
| Players | 1–4 (AI fills seats); pass-and-play; async online |
| Simulation | Turn-based, seeded fashion and edict decks |
| Sourcing tier | `FULL` (ukiyo-e and Japanese woodblock printing, a living craft tradition with practising carvers and printers) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** see above.
- **Summary:** Each player is a publisher (hanmoto) in Edo. Over 8 seasons, players place workers (apprentices and their own token) on locations: artists' studios (commission designs in genres: landscape, kabuki actors, beauties, warrior prints, surimono), carvers' workshops (carve one block per colour), printers' workshops (print a run, applying blocks in order: key block outline first, then colours light to dark), paper and pigment merchants, the bookstall (sell prints to the fashion market), and the censor's office (obtain the approval seal). A print requires a design (with a colour count), one carved block per colour, and a print run; colour order must be respected (pigments in data). Fashion cards shift demand by genre each season; sumptuary edicts periodically ban genres or colour counts (based on Kansei and Tenpō reforms), confiscating unsealed stock. Reputation with artists unlocks better designs. Score: money (ryō), reputation, and collections (series of prints, for example a 5-print landscape series).
- **Pillars:**
  1. **The print is the production chain.** Design → blocks → printing → seal → sale, each a visible step.
  2. **Order matters.** Colour order and block count are spatial puzzles on the printing table.
  3. **Fashion and censorship.** Market timing and risk management drive strategy.
  4. **Honour the craft.** Advisors from the woodblock print community review processes and depictions.
- **Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Washi `#F1E8D3`, sumi black `#1D1C1A`, Prussian blue (bero-ai) `#1F3B6E`, beni red `#C0393B`, ochre (ōdo) `#C49A45`, indigo `#2C3D55`, safflower pink `#E07A8B`, kusa green `#5E7A3E`, mica grey `#BFB8AA`. |
| Shapes | Woodblocks as cherry-wood rectangles with kentō registration marks; prints composed from layered flat colours. |
| Typography | SF Pro and a Mincho-style typeface for Japanese terms (Hiragino Mincho, system); no fake Japanese text. |
| Motion | Printing animates the baren rubbing; colours appear layer by layer. |
| Music | Shamisen and shakuhachi textures (commissioned; advisor-reviewed). |
| SFX | Chisel, baren rub, paper lift, bookstall bustle. |
| Haptics | Rhythmic rub feedback per colour pass. |

- **Inspirations:** Salter, "Japanese Woodblock Printing" (2001); Marks, "Japanese Woodblock Prints: Artists, Publishers and Masterworks" (2010); the Adachi Institute of Woodcut Prints; Tsutaya Jūzaburō's career; Agricola and Lords of Waterdeep for worker placement.

## 2. Tech Stack Decision

Per `_CONVENTIONS.md` §2, plus:
- **Print model:** a print = design (genre, colours ordered by pigment layer index), blocks (one per colour), run size; quality derives from carver and printer skill.
- **Print rendering:** procedural layer composition from design templates (commissioned original designs, layer-separated).
- ADRs: ADR-0003 worker placement locations as data; ADR-0004 colour order rule; ADR-0005 edicts.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/HMCore/Sources/HMCore/
  Board/      Location.swift, Worker.swift, Placement.swift
  Print/      Design.swift, Block.swift, Pigment.swift, PrintRun.swift, Quality.swift, Seal.swift, Series.swift
  Market/     Fashion.swift, Bookstall.swift, Demand.swift
  Edicts/     Edict.swift, Confiscation.swift
  People/     Artist.swift, Carver.swift, Printer.swift, Reputation.swift
  Engine/     GameState.swift, Action.swift, Event.swift, Reducer.swift, Season.swift, Score.swift
Packages/HMContent/  ArtistDef.swift, DesignDef.swift, PigmentDef.swift, LocationDef.swift, FashionDef.swift, EdictDef.swift, Loader.swift
Packages/HMAI/       MCTS.swift, Heuristics.swift, Personalities.swift
Packages/HMRender/   EdoScene.swift, PrintCompositor.swift, PrintShader.metal, BlockNode.swift
Packages/HMMeta/     Collection.swift, Campaign.swift, Stats.swift
Resources/Content/   artists.json, designs.json, pigments.json, locations.json, fashion.json, edicts.json, balance.json, tutorial.json, glossary.json, cultural_manifest.json
```

## 4. Core Rules Specification

**Season**
- R-1 Each season: reveal fashion card (demand per genre) and possibly an edict; players place workers one at a time in turn order; resolve locations in board order; sell; upkeep.
- R-2 Workers: each player starts with 3 apprentices plus the publisher token (the token can use "exclusive" spaces). Hire more at the guild (max 6).

**Production chain**
- R-3 Commission: at an artist's studio, pay to take a design card: genre, colour count c (2–8), quality base, artist reputation requirement.
- R-4 Carving: at a carver's workshop, carve up to k blocks (k by carver skill) for one design; a design needs c blocks (key block plus colours).
- R-5 Printing: at a printer's workshop, pay pigment and paper to produce a run of n prints (n ≤ printer capacity). Colour order: pigments are printed in ascending layer index; a design's colours must be printed in one run in order; if a required pigment is unavailable, the run cannot proceed.
- R-6 Seal: unsealed prints may be sold at a risk: if an edict hits that genre while unsealed stock is held, it is confiscated. Visiting the censor seals all your current prints of permitted genres.
- R-7 Selling: at the bookstall, sell up to s prints; price = base × demand (fashion) × quality factor; demand drops as prints of a genre are sold that season.

**Edicts**
- R-8 Edict cards (from data, modelled on reforms) ban a genre, cap colour counts, or raise fines, for N seasons.

**Scoring**
- R-9 Final score = ryō + reputation × 2 + series bonuses (complete a 3-, 5-, or 10-print series in one genre by the same artist) − unsold inventory penalty.

**Invariants**
- INV-1 Money and pigment conservation (ledger).
- INV-2 A print exists only if all c blocks are carved and its run printed in order.
- INV-3 Worker placement legality (exclusive spaces, capacity).
- INV-4 Replay determinism.
- INV-5 Confiscation exactly removes unsealed stock of banned genres.

## 5. Data Schemas and Content Tables

```swift
struct DesignDef: Codable, Sendable { var id: String; var genre: Genre; var colours: [PigmentID]; var quality: Int; var artist: String; var series: String?; var art: String; var cultural: Bool }
struct PigmentDef: Codable, Sendable { var id: String; var layer: Int; var cost: Int; var label: HistoryLabel }
struct EdictDef: Codable, Sendable { var id: String; var effect: EdictEffect; var seasons: Int; var label: HistoryLabel; var source: String }
enum Action: Codable, Hashable { case place(WorkerID, LocationID, params: LocationParams), passSeason }
```

| Table | G3 | G5 | Sample row |
| --- | --- | --- | --- |
| `artists.json` | 8 | 16 | `{ "id": "artist_a", "name": "(fictional) Ōmura Kōsai", "genres": ["landscape"], "repReq": 2, "label": "Invented" }` |
| `designs.json` | 40 | 100 | `{ "id": "d012", "genre": "landscape", "colours": ["sumi","bero","ai","beni"], "quality": 3, "series": "eight_views_x" }` |
| `pigments.json` | 8 | 10 | `{ "id": "bero", "layer": 5, "cost": 3, "label": "Attested" }` |
| `edicts.json` | 6 | 12 | `{ "id": "kansei_like", "effect": {"banGenre": "beauties"}, "seasons": 2, "label": "Reconstructed", "source": "Kansei Reforms 1787–1793" }` |
| `fashion.json` | 16 | 32 | `{ "id": "f_kabuki_boom", "demand": {"actors": 3, "landscape": 1} }` |

Artists are fictional; real artists (Hokusai, Hiroshige, Utamaro) appear only in About the Tradition with credits, not as game pieces (ADR, advisor confirmation).

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| Seasons | 8 | 6–10 | `balance.json` |
| Starting ryō | 10 | 6–15 | `balance.json` |
| Demand decay per sale | 10% | 5–20% | `balance.json` |
| Edict frequency | 1 per 3 seasons avg | — | `edicts.json` |
| Series bonuses | 5 / 12 / 30 | — | `balance.json` |

Targets: 4-player seat win shares 22–28%; confiscations affect 20–40% of games; average colour count of printed designs 4–5; series completed in ≥ 50% of games by winners.

## 7. AI Approach

- **MCTS** (perfect information except deck order; determinised) with heuristic rollouts; personalities: Fashionable (follows demand), Craftsman (high quality, few colours), Risk-taker (skips seals).
- **Tiers:** Apprentice, Clerk, Master Publisher.

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7, SRC0.1, SRC0.2, HIST0.1 (Attested: publisher role, block per colour, kentō, Prussian blue arrival c. 1820s, Kansei and Tenpō reforms, censorship seals; Invented: economics, fictional artists).

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; SRC0.1, SRC0.2, HIST0.1 complete
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- HM-P1.1 Locations and placement (R-1, R-2).
- HM-P1.2 Production chain and colour order (R-3 to R-7).
- HM-P1.3 Edicts and scoring (R-8, R-9).

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-9 tests; INV-1…INV-5
  [ ] HMCore coverage ≥ 90%; make sim N=2000 deterministic
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5, SRC2.1, SRC2.2.
- HM-P2.1 Edo board with locations; worker drag; design cards; printing table that shows blocks stacking in order; bookstall sales.
- HM-P2.2 Clerk AI.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test completes a 2-player game on iPad and Mac
  [ ] Manifest marks all designs, glossary, and music pending; deny-list passes
  [ ] `docs/SLICE_ASSESSMENT.md` written: self-assessment against the pillars, with every weakness turned into a P3 task (`_CONVENTIONS.md` §8.1)
Sign-off: GLM-SELF
```

### P3 Content and Systems
- HM-P3.1 G3 content; About the Tradition (SRC3.1); HIST3.1.
- HM-P3.2 Tutorial (5 lessons); pass-and-play.

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts met; lint clean; 1,000 sims
Sign-off: GLM-SELF
```

### P4 AI Opponents
- HM-P4.1 Personalities; tiers; `docs/BALANCE.md`.

```
GATE G4 — AI
Checks:
  [ ] Master win share ≥ 40% vs Apprentices in 4-player; targets met; p95 ≤ 800 ms
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- HM-P5.1 G5 counts; collection album of printed designs; solo campaign (rise of a publishing house); 24 achievements; SRC5.1; HANDOFF.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Counts met; packet and HANDOFF complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- HM-P6.1 Commissioned original designs (layer-separated) ideally by practising mokuhanga artists; print shader; SRC6.1 and SRC6.2 review by a woodblock printing advisor and a Japanese art historian.
- HM-P6.2 Music and SFX.

```
GATE G6 — Aesthetics and Cultural Review
Checks:
  [ ] Advisor review filed as a `needs-maintainer` issue (SUBSTITUTED, `_SET2_ADDENDUM.md` §4); every entry still pending advisor review listed in that issue; snapshots approved
Sign-off: GLM-SELF
```

### P7 Platform Features
- HM-P7.1 Async, Game Center, iCloud; Japanese localisation (a maintainer decision filed as an issue; GLM ships String Catalogs ready for translation); share a print image.

```
GATE G7 — Platform
Checks:
  [ ] Async completes; localisation pseudo-tests
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- HM-P8.1 Pigments named and patterned; VoiceOver for placement and printing table.

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

- **Fragile areas:** colour order with optional pigments; edict timing versus seals.
- **Priorities for P6–P10:** print compositor and shader; economy balance; cultural packet.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Shunga or sensitive genres | Low | High | Excluded in deny-list | GLM |
| Art cost (100 designs) | High | Medium | Layered templates, staged commissions | GLM |
| Misrepresentation of craft | Medium | Medium | Advisors from the craft | GLM |

## 11. Out of Scope

Shunga; real artists as playable pieces; book publishing (post-launch).

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 2 |
| P1 | GLM | 6–8 |
| P2 | GLM | 6–8 |
| P3 | GLM | 5–7 |
| P4 | GLM | 5–7 |
| P5 | GLM | 4–6 |
| P6 | GLM | 9–13 |
| P7 | GLM | 4–6 |
| P8 | GLM | 3–5 |
| P9 | GLM | 4–6 |
| P10 | GLM | 2–3 |
| **Total** | | **50–71** |

## 13. Open Questions

1. Use real historical publishers' names (Tsutaya Jūzaburō) as rivals? Default: no; fictional publishers, real ones credited in About.

## 14. Sourcing Notes

- **Sources:** Salter, "Japanese Woodblock Printing" (2001); Marks, "Japanese Woodblock Prints: Artists, Publishers and Masterworks 1680–1900" (2010); Adachi Institute materials; Kansei and Tenpō reform histories; Wikipedia "Glossary of ukiyo-e"; Asian Art Museum education page on the ukiyo-e process; Fitzwilliam Museum Yoshitoshi glossary. (A previously listed Clark title could not be verified and was removed.)
- **Restricted elements:** shunga; Buddhist and Shinto sacred imagery as commodities; fake Japanese text.
- **Glossary seeds (verified against museum glossaries; pending advisor):** hanmoto (publisher), horishi (carver; also hori-shi), surishi (printer; also suri-shi), eshi (artist), kentō (見当, registration marks), baren (rubbing pad), bokashi (gradation), aratame (改, "examined") censor seal, and kiwame (極, "approved") censor seal.

## Appendix A. Extended Specification (Depth Pass)

### A.1 Additional Rules

**Board locations (G3)**
- R-10 Locations and capacities: Artists' Row (4 studios, 1 worker each; one exclusive space for the publisher token gives first pick of new designs), Carvers' Street (3 workshops: skill k = 2, 3, 4 blocks per visit; capacity 1), Printers' Lane (3 workshops: capacity n = 20, 40, 60 prints; capacity 1), Paper Merchant (buy paper; unlimited), Pigment Seller (buy pigments; unlimited, limited stock per pigment per season), Censor's Office (seal; capacity 2), Bookstall (sell; capacity 3), Guild Hall (hire 1 apprentice; capacity 1; costs 3 ryō).
- R-11 Resolution order: Artists → Paper → Pigment → Carvers → Printers → Censor → Bookstall → Guild (board order, R-1).
- R-12 A design's blocks persist between seasons; carving can be spread over several visits.

**Printing detail**
- R-13 A run of n prints of a design with c colours costs n paper and n × (c − 1) pigment units (key block sumi costs 0 extra; sumi is always available).
- R-14 Pigments have layers (data): lighter colours are printed before darker ones, sumi key block first (R-5). The layer order is validated at design load.
- R-15 Bokashi (gradation) designs need a printer of skill ≥ 2 (the second or third workshop) and add +1 quality.
- R-16 Misregistration: designs with c ≥ 6 printed at the 20-capacity workshop lose 1 quality (kentō precision varies by printer, Invented abstraction).

**Market detail**
- R-17 Demand per genre starts at the fashion card value (1–4); each print sold lowers that genre's price multiplier by 0.1 (floor 0.5) for the season.
- R-18 Quality factor: quality 1 ×0.8, 2 ×1.0, 3 ×1.2, 4 ×1.5, 5 ×2.0.
- R-19 Unsold inventory carries over; at game end, each unsold print costs 1 ryō (disposal).

**Edicts detail**
- R-20 Edicts are revealed one season in advance as rumours (face-down card with genre hint) at the Censor's Office for players who visit (information advantage).
- R-21 Colour-cap edicts (e.g., max 4 colours) apply to prints run during the edict; existing stock is unaffected.

### A.2 Additional Invariants
- INV-6 Layer order of every design is strictly increasing (lint).
- INV-7 Blocks carved per design never exceed its colour count.
- INV-8 Price multiplier never below 0.5.
- INV-9 Rumour visibility is per player (PlayerView test).

### A.3 Complete Schemas and Sample Rows

```swift
struct LocationDef: Codable, Sendable { var id: String; var kind: LocationKind; var capacity: Int; var exclusive: Bool; var params: [String: Int] }
struct ArtistDef: Codable, Sendable { var id: String; var name: String; var genres: [Genre]; var repReq: Int; var label: HistoryLabel }
struct FashionDef: Codable, Sendable { var id: String; var demand: [Genre: Int] }
enum EdictEffect: Codable, Sendable { case banGenre(Genre), colourCap(Int), fineMultiplier(Int), sealRequired }
struct Inventory: Codable, Hashable, Sendable { var design: String; var sealed: Int; var unsealed: Int }
struct SeriesDef: Codable, Sendable { var id: String; var artist: String; var genre: Genre; var sizes: [Int]; var bonus: [Int] }
```

```json
{ "id": "carver_3", "kind": "carver", "capacity": 1, "exclusive": false, "params": {"k": 4} }
{ "id": "beni", "layer": 3, "cost": 4, "label": "Attested" }
{ "id": "f_rainy_season", "demand": {"landscape": 3, "actors": 2, "beauties": 2, "warriors": 1, "surimono": 1} }
{ "id": "eight_views_x", "artist": "artist_a", "genre": "landscape", "sizes": [3, 5, 8], "bonus": [4, 9, 18] }
{ "id": "tenpo_like", "effect": {"colourCap": 7}, "seasons": 3, "label": "Reconstructed", "source": "Tenpō Reforms 1841–1843" }
```

### A.4 Balance Tables and Sim Targets

| Parameter | Default | Range | Sim Target |
| --- | --- | --- | --- |
| Seasons | 8 | 6–10 | 45–75 minutes, 4 players |
| Starting ryō | 12 | 8–16 | First print sold by season 2 in ≥ 80% of games |
| Pigment cost | 1–4 | — | Average design colours printed 3–5 |
| Series bonus (3/5/8) | 4/9/18 | — | Series bonuses 15–30% of winning score |
| Edict frequency | 1 per 2 seasons | 1/3–1/1 | Confiscations in 20–40% of games |
| Demand decay | 0.1/print | 0.05–0.15 | Players sell across ≥ 3 genres |

Personality balance: each of 3 personalities wins 28–40% in 3-bot games.

### A.5 AI Design in Detail
- **Determinisation:** fashion and edict deck order sampled; rumours fixed if known.
- **Rollout policy:** commission designs whose genre demand ≥ 2 and colour count ≤ affordable; carve before print; seal if any edict rumour targets a held genre; sell highest multiplier first.
- **Placement ordering:** value of blocking (exclusive spaces, scarce carvers) estimated by the opponent's next-step needs.
- **Budget:** Master 1.0 s, 2,000 iterations.

### A.6 Granular Task Breakdown

| ID | Task | Acceptance Criteria |
| --- | --- | --- |
| HM-P1.1 | Locations and placement (R-2, R-10, R-11) | INV-3 |
| HM-P1.2 | Commission and carving (R-3, R-4, R-12) | INV-7 |
| HM-P1.3 | Printing and layers (R-5, R-13–R-16) | INV-2, INV-6 |
| HM-P1.4 | Seals, edicts, rumours (R-6, R-8, R-20, R-21) | INV-5, INV-9 |
| HM-P1.5 | Market and scoring (R-7, R-9, R-17–R-19) | INV-8 |
| HM-P2.1 | Print-building animation (layer-by-layer reveal) | Layer order matches data |
| HM-P2.2 | Ledger and inventory panel | INV-1 |
| HM-P3.1 | 8 fictional artists, 40 designs (original art) | Lint; manifest |
| HM-P3.2 | About the Tradition: process, censorship seals | Pending marks |
| HM-P4.1 | MCTS and personalities | Targets met |
| HM-P5.1 | 100 designs, 16 artists | Lint |

### A.7 Sharpened Gate Checks
- G1 adds: a printed design's final image composites exactly its c layers in order.
- G3 adds: no real artist appears as a game piece; no shunga or sacred imagery (deny-list).
- G5 adds: all Japanese text and seal designs listed in the advisor-review `needs-maintainer` issue and marked pending advisor review.

### A.8 Additional Risks

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Original art looks like pastiche | Medium | High | Commission a printmaker-informed illustrator; advisor review | GLM |
| Fake Japanese text | Medium | High | Only reviewed text; seals designed by a calligrapher | GLM |
| Edicts feel arbitrary | Medium | Medium | Rumours (R-20) | GLM |

### A.9 Additional Open Questions (Defaults)
1. Use real publishers' marks? Default: no; fictional marks.
2. Include surimono (privately commissioned prints)? Default: yes, as a high-quality low-volume genre.
3. Real woodblock printmakers for marketing art? Default: placeholder art by GLM; any commission is a maintainer item filed as an issue.
