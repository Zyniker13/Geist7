# 02 — Eight Suits Roadmap

> A compact empire game in which every action is a card played to a trick, and the suit that leads decides what everyone at the table may do this round.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 in full before starting. Depth pass (15 Nov 2026): Appendix A extends §4–§13 and wins where they differ. This roadmap adds only what is specific to Eight Suits.

Research: [`RESEARCH.md`](RESEARCH.md) (art direction, design lineage, cultural context, advisor institutions, verified glossary, and audio direction).

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 02 · `eight-suits` |
| Code prefix | `ES` (packages `ESCore`, `ESContent`, `ESAI`, `ESRender`, `ESAudio`, `ESPlatform`, `ESMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Trick-taking 4X (card-driven area control) |
| Difficulty tier | Deep |
| Scope | Small team |
| Session length | 30–50 minutes (2–4 players) |
| Renderer | SpriteKit (2D), custom `SKShader` for gold-leaf glint on cards |
| Players | Solo vs 1–3 AIs; local pass-and-play (2–4); async online (GameKit turn-based, 2–4) |
| Simulation | Turn-based; hidden information (hands) |
| Sourcing tier | `FULL` (Mughal Ganjifa cards and Indian painting traditions; Ganjifa is still made by artisans in Sawantwadi, Odisha, and Mysuru) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** see above.
- **Summary:** Two to four rival courts compete over eight provinces of a fictional subcontinental realm. A 96-card round Ganjifa deck (eight suits of twelve: ranks 1–10 plus a Wazir and a Shah) is dealt each chapter. Each round, the leader plays a card; its suit is the action for the round. Others follow (same suit: a weaker copy of the action), pivot (different suit, played face up: a one-point basic action of that suit), or copy face down (lowest strength of the lead action). The highest card of the lead suit wins initiative and leads next. Actions place influence, raise armies, build, tax, and trade on the province map. Court Audiences, triggered when a card with an audience seal is played, score provinces and the current ambition. The deck is fixed per chapter, so counting cards matters. Three chapters make a game.
- **Pillars:**
  1. **One card, two decisions.** Every play chooses both an action and a tempo stance (lead, follow, pivot, copy, or seize).
  2. **Countable hidden information.** Hands are hidden but the deck is known; a tracker shows which cards are out, so skill beats luck.
  3. **Lumpy time.** A player can hoard strength for one decisive round; the UI makes initiative and remaining strength visible.
  4. **Every card is a painting.** Card faces are legible at 44 pt and beautiful at 300 pt.
  5. **Under an hour, every time.** Three chapters; a hard turn cap prevents stalls.
- **Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Lacquer black `#1A1412`, vermilion `#C23B22`, lapis `#26619C`, malachite `#2E8B57`, orpiment yellow `#E3A72F`, gold leaf `#C9A44C`, ivory ground `#F3EAD7`, cloth mat `#5B2333`. Each suit owns one ground color plus a pip shape (see §5), so suits never depend on color alone. |
| Shapes | Round cards (diameter 1.0 card unit), each with a pip motif and a court figure on ranks Wazir and Shah; provinces as carpet medallions on the mat. |
| Typography | Title face with Devanagari and Latin support (default: system Kohinoor Devanagari for display, SF Pro for UI); numerals in a dedicated rank glyph set. |
| Motion | Cards slide and settle with a felt friction curve (260 ms); tricks sweep to the winner. |
| Music | Rudra veena drone with tabla patterns in three intensities driven by audience proximity. |
| SFX | Card on cloth, lacquer tap, coins, a small bell for audiences. |
| Haptics | Light tick per card placement; heavy pulse on winning initiative. |

- **Inspirations:** Cole Wehrle's trick-taking action system in Arcs and its two kinds of time; Pax Pamir's coalition scoring; IGNCA and Ashmolean writing on Ganjifa suits; Overtrick (2026).

## 2. Tech Stack Decision

Per `_CONVENTIONS.md` §2, plus:
- **Information sets.** Core separates `GameState` (omniscient) from `PlayerView` (what one seat knows). Render and AI receive only `PlayerView`; a CI test asserts that `ESAI` never imports or receives `GameState` directly (type-level boundary).
- **Async turn-based.** Hidden hands in GameKit turn-based matches are protected by encrypting each hand with a per-seat key derived from the match ID and the seat's local Keychain secret (P7). Until P7, async is pass-and-play only.
- ADRs: ADR-0003 `PlayerView` information boundary; ADR-0004 deck and suit model (8 × 12); ADR-0005 bot determinism with hidden information (determinized sampling with a seeded RNG); ADR-0006 async hidden-hand scheme (written in P0, implemented in P7).

## 3. Repository Structure (Game-Specific Additions)

```
Packages/ESCore/Sources/ESCore/
  Cards/     Suit.swift, Rank.swift, Card.swift, Deck.swift, Hand.swift, Trick.swift, PlayStance.swift
  Map/       Province.swift, ProvinceMap.swift, Influence.swift, Army.swift, Building.swift, Route.swift
  Courts/    Court.swift, CourtPower.swift, Ambition.swift
  Engine/    GameState.swift, PlayerView.swift, Action.swift, Event.swift, Reducer.swift, Chapter.swift, Audience.swift, Scoring.swift, LegalMoves.swift
Packages/ESContent/Sources/ESContent/ SuitDef.swift, CourtDef.swift, MapDef.swift, AmbitionDef.swift, AudienceDef.swift, Loader.swift, Validation.swift
Packages/ESAI/Sources/ESAI/ Determinizer.swift, ISMCTS.swift, HeuristicPlayer.swift, Personality.swift, CardCounter.swift
Packages/ESRender/Sources/ESRender/ TableScene.swift, HandFan.swift, TrickArea.swift, MapScene.swift, CardNode.swift, Tracker.swift, GoldGlint.fsh
Packages/ESMeta/Sources/ESMeta/ Campaign.swift (court unlocks), DailyDeal.swift, Stats.swift
Resources/Content/ suits.json, courts.json, maps.json, ambitions.json, audiences.json, ai_personalities.json, balance.json, tutorial.json, achievements.json, cultural_manifest.json
```

## 4. Core Rules Specification

**Components and setup**
- R-1 Deck: 96 cards, 8 suits × ranks 1–10, Wazir (11), Shah (12). Suits and actions: Taj (crown) = Rule; Shamsher (sword) = War; Safed (silver coin) = Trade; Barat (document) = Law; Ghulam (servant) = Build; Chang (harp) = Patronage; Surkh (gold coin) = Tax; Qimash (merchandise) = Market. (Names are drafts pending advisor review; SRC.)
- R-2 Map: 8 provinces in a ring plus a central capital (9 regions); each province has an income value 1–3 and a route to its two neighbors and the capital.
- R-3 Each court starts with 3 influence in its home province, 1 army, and 5 coins. Courts are drafted in reverse seat order.
- R-4 A game has 3 chapters. At each chapter start, shuffle the full deck and deal hands: 4 players 10 cards, 3 players 12, 2 players 14; the rest form the undealt pile (face down, unknown).
- R-5 Ambitions: reveal 3 ambition cards per game, one active per chapter (revealed at chapter start).

**Rounds and tricks**
- R-6 The initiative holder leads one card face up. Its suit is the lead suit; its rank is the lead strength.
- R-7 Each other player, clockwise, plays one card as one of: `follow` (same suit, face up; action strength = rank − 2, minimum 1), `pivot` (different suit, face up; performs that suit's basic action at strength 1), or `copy` (any card face down; performs the lead action at strength 1).
- R-8 Seize: before playing, a non-leader may discard a second card face down to seize; if they play a `follow` that is the highest card of the lead suit, they take initiative even if the leader's card ranks higher. Only one seize per round (first come in clockwise order).
- R-9 Resolution order: the leader acts first at full strength, then others in clockwise order.
- R-10 Initiative: the highest card of the lead suit wins (R-8 excepted); ties impossible (unique cards).
- R-11 A chapter ends when any player has no cards at the start of their turn to lead, or after 12 rounds.

**Actions** (strength `s` = action points)
- R-12 Rule: place `s` influence in a province adjacent to one you control or in the capital (cost 0).
- R-13 War: move armies up to `s` steps total, then battle in each contested province: each side rolls nothing; armies cancel one for one; the side with remaining armies removes enemy influence equal to its surplus.
- R-14 Trade: gain 1 coin per route between two provinces you control, up to `s`.
- R-15 Law: place or move a law token (max 3 on the map) that blocks one action type in that province, `s ≥ 3` required for move.
- R-16 Build: spend 2 coins per building; up to `⌊s/2⌋` buildings (Fort +1 army defense, Bazaar +1 income, Garden +1 audience point).
- R-17 Patronage: gain `s` favor (tie-breaker and ambition currency).
- R-18 Tax: gain income from provinces you control, capped at `s`.
- R-19 Market: buy cards from the undealt pile at 3 coins each, up to `⌊s/3⌋`, then discard the same number (hand size constant).

**Control, audiences, and scoring**
- R-20 A court controls a province with strictly the most influence there; armies defend influence (R-13).
- R-21 Audience seals appear on 12 cards (ranks 7 and Shah of four suits; listed in `audiences.json`). When a seal card is played face up in any stance, an Audience occurs after the round: score 2 points per controlled province, 3 for the capital, plus the active ambition (R-22).
- R-22 Ambitions (examples): Treasury (most coins: 5/2), Patron (most favor: 5/2), Builder (most buildings: 5/2), Warlord (most armies on the map: 5/2), and Lawgiver (most law tokens placed this chapter: 5/2).
- R-23 End of chapter: a final Audience; then hands are discarded and armies halved (round down).
- R-24 After chapter 3, highest score wins; tie → favor; tie → coins; tie → the court seated later wins.

**Courts** (powers in `courts.json`; six required): e.g. Deccan (may lead two cards of the same suit once per chapter), Bengal (Trade counts sea routes), Kabul (War moves ignore law), Golconda (Market cards cost 2), Malwa (Patronage strength +2), and Awadh (one pivot per round may be at full rank − 3). Court names are placeholders for a fictional realm; final names pending advisor review.

**Invariants**
- INV-1 Each of the 96 cards is in exactly one zone (hand, trick, discard, undealt).
- INV-2 `PlayerView` for seat k reveals no card in another seat's hand or the undealt pile (property test diffing views).
- INV-3 Influence and armies never go negative; total influence ≤ 9 regions × 20.
- INV-4 A chapter ends within 12 rounds.
- INV-5 Replay determinism.

## 5. Data Schemas and Content Tables

```swift
struct Card: Codable, Hashable, Sendable { var suit: SuitID; var rank: Int; var seal: Bool }
enum PlayStance: Codable, Hashable { case lead, follow, pivot, copy }
struct Play: Codable, Hashable { var seat: Int; var card: Card?; var stance: PlayStance; var seizeDiscard: Card? } // card nil in views when face down
struct GameState: Codable, Hashable, Sendable { var seats: [Seat]; var map: ProvinceMap; var hands: [[Card]]; var undealt: [Card]; var discard: [Card]
  var chapter: Int; var round: Int; var initiative: Int; var trick: [Play]; var ambitions: [String]; var scores: [Int]; var rng: SeededRNG }
struct PlayerView: Codable, Hashable, Sendable { var seat: Int; var hand: [Card]; var publicPlays: [Play]; var cardsSeen: Set<Card>; var map: ProvinceMap; var scores: [Int] /* … */ }
enum Action: Codable { case play(Card, PlayStance, seize: Card?), resolve(ActionChoice), pass }
```

| Table | G3 | G5 | Sample row |
| --- | --- | --- | --- |
| `suits.json` | 8 | 8 | `{ "id": "taj", "action": "rule", "pip": "crown", "ground": "#C23B22", "cultural": true, "nameKey": "suit.taj" }` |
| `courts.json` | 4 | 6 | `{ "id": "deccan", "power": "double_lead_once", "homeProvince": 3, "nameKey": "court.deccan", "cultural": true }` |
| `maps.json` | 2 | 5 | `{ "id": "ring8", "regions": 9, "income": [1,2,1,3,1,2,1,2,3], "routes": [[0,1],[1,2], "…"] }` |
| `ambitions.json` | 5 | 9 | `{ "id": "treasury", "metric": "coins", "first": 5, "second": 2 }` |
| `audiences.json` | 12 seals | 12 | `{ "suit": "taj", "rank": 7 }` |
| `ai_personalities.json` | 3 | 6 | `{ "id": "hoarder", "leadThreshold": 9, "pivotBias": -0.2, "seizeAggression": 0.1 }` |
| `tutorial.json` | 6 lessons | 8 | — |

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| `followPenalty` | 2 | 1–4 | `balance.json` |
| `handSize` (2/3/4 players) | 14/12/10 | ±2 | `balance.json` |
| `audienceProvincePoints` | 2 | 1–3 | `balance.json` |
| `capitalPoints` | 3 | 2–5 | `balance.json` |
| `marketCardCost` | 3 | 2–5 | `balance.json` |
| `armyHalving` | 0.5 | 0.33–0.75 | `balance.json` |
| `roundCap` | 12 | 10–14 | `balance.json` |

Targets (Strong AIs, 2,000 games per player count): each court's win rate within ±4 percentage points of fair share; seat win rates within ±3 points; median game 30–45 minutes estimated by action count × 7 s; at least 6 of 8 suits led ≥ 8% of the time each.

## 7. AI Approach

- **Determinization.** For each decision, sample `K` plausible deals of unseen cards consistent with public information (and inferred voids: a seat that pivoted on suit X is marked void in X with probability 0.8, tunable).
- **ISMCTS** (information-set Monte Carlo tree search) over the play decision, with a heuristic rollout policy; action resolution choices (where to place influence) use a greedy evaluator inside rollouts.
- **Evaluation:** score + 1.5 × provinces controlled + 0.4 × coins + 0.3 × favor + ambition lead bonus + initiative value (expected actions next round).
- **Tiers:** Courtier (heuristic only, no search), Vizier (ISMCTS 400 iterations, K = 8), Sultan (2,000 iterations, K = 24, 1.5 s), Emperor (6,000 iterations, K = 48, 3.0 s). Personalities (§5) bias priors.
- **Determinism:** search uses the seeded RNG; time budgets truncate only between iteration batches of 100.

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7, SRC0.1, SRC0.2, and HIST0.1.
- ES-P0.1 `PlayerView` type boundary and a compile-time test that `ESAI` public APIs accept only `PlayerView`.

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks
  [ ] SRC0.1, SRC0.2, and HIST0.1 complete
  [ ] ADR-0003…ADR-0006 drafted
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- ES-P1.1 Deck, deal, and trick resolution (R-1, R-4, R-6 to R-11) with 30 fixture tricks covering seize edge cases.
- ES-P1.2 Map actions R-12 to R-19 with per-action tests.
- ES-P1.3 Audiences, ambitions, chapter end, and final scoring (R-20 to R-24).
- ES-P1.4 Six court powers with tests; INV-2 view-leak property test.

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-24 tagged tests pass; INV-1…INV-5 over 2,000 seeds
  [ ] ESCore coverage ≥ 90%
  [ ] make sim N=2000 random games for 2, 3, and 4 players: 0 crashes; identical hashes on two runs
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5, SRC2.1, and SRC2.2.
- ES-P2.1 Table scene: hand fan (thumb sweep to spread), trick area, and map; drag a card to the trick, two-finger tap to flip face down, press and hold for card text. Mac: click to select, Space to play, F to flip.
- ES-P2.2 Stance picker appears only when ambiguous; resolution choices via tappable province highlights.
- ES-P2.3 Card tracker panel (cards out by suit) and initiative/strength indicator.
- ES-P2.4 Opponents: two Courtier AIs (3-player game).

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test plays a full 3-chapter, 3-player game to the results screen on iPad and Mac
  [ ] No hidden card visible in any snapshot from seat 1's view (snapshot audit test)
  [ ] Resume mid-trick to identical hash
  [ ] Manifest covers all suit pips, court figures, and names; deny-list lint passes
  [ ] `docs/SLICE_ASSESSMENT.md` written: self-assessment against the pillars, with every weakness turned into a P3 task (`_CONVENTIONS.md` §8.1)
Sign-off: GLM-SELF
```

### P3 Content and Systems
- ES-P3.1 G3 counts in §5; court draft screen; map select.
- ES-P3.2 Tutorial (6 lessons: lead, follow, pivot, copy, seize, audience) with scripted deals.
- ES-P3.3 Pass-and-play (2–4) with privacy screen between seats.
- ES-P3.4 Game log (every play and resolution in plain language) and end-of-game breakdown.
- ES-P3.5 About the Tradition (SRC3.1): Ganjifa history, Mughal and Dashavatara decks (explaining why the devotional deck is not used), artisans today; HIST3.1 labels.

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts met; content-lint 0 errors
  [ ] Tutorial and pass-and-play UI tests pass
  [ ] 1,000-game sims per court count: 0 crashes
Sign-off: GLM-SELF
```

### P4 AI Opponents
- ES-P4.1 Determinizer with void inference; ISMCTS; four tiers; personalities.
- ES-P4.2 Balance report (`docs/BALANCE.md`): court, seat, and suit-usage tables.

```
GATE G4 — AI
Checks:
  [ ] Each tier beats the tier below ≥ 65% in 2-player over 500 games
  [ ] Sultan p95 ≤ 1.5 s, Emperor p95 ≤ 3.0 s (Mac measured)
  [ ] 0 illegal actions in 500-game soaks per tier; AI never reads GameState (type test)
  [ ] Court win rates within ±6 points of fair share (tightened to ±4 in P9)
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- ES-P5.1 Remaining content to G5 counts (6 courts, 5 maps, 9 ambitions, 6 personalities).
- ES-P5.2 Campaign: "Durbar" ladder of 10 rival courts with escalating tiers; unlocks courts and card-back art.
- ES-P5.3 Daily deal: seeded deal, court, and map; solo vs two Sultans; score saved locally.
- ES-P5.4 Stats, 30 achievements; SRC5.1 packet.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Daily deal identical across devices for 30 dates
  [ ] G5 counts met; all courts pass 1,000-game sims
  [ ] Coverage thresholds met; SOURCING_REVIEW_PACKET complete; HANDOFF complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- ES-P6.1 Commission 96 card faces and 6 court portraits from an artist trained in Indian miniature or Ganjifa painting (budget is a maintainer item filed as an issue; placeholders until then); gold-leaf shader.
- ES-P6.2 Map as a painted carpet medallion layout; animations.
- ES-P6.3 Veena and tabla stems; SFX.
- ES-P6.4 SRC6.1 and SRC6.2 advisor review (Ganjifa artisan or art historian).

```
GATE G6 — Aesthetics
Checks:
  [ ] All 96 faces legible at 44 pt (snapshot set) and approved
  [ ] Advisor review filed as a `needs-maintainer` issue (SUBSTITUTED, `_SET2_ADDENDUM.md` §4); every entry still pending advisor review listed in that issue
Sign-off: GLM-SELF
```

### P7 Platform Features
- ES-P7.1 GameKit turn-based async (2–4) with encrypted hands (ADR-0006); reconnect and timeout rules (48 h per turn default).
- ES-P7.2 Leaderboards (daily deal score), achievements, challenges.
- ES-P7.3 iCloud sync; Mac menus and full keyboard play.

```
GATE G7 — Platform
Checks:
  [ ] 3-seat async match completes across sandbox accounts with no hand leakage (packet inspection test)
  [ ] iCloud round-trip
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- ES-P8.1 Suits identified by pip shape, letter badge, and color; high-contrast card mode.
- ES-P8.2 VoiceOver reads hand ("Taj 9, seal"), trick, and map; full play via rotor.
- ES-P8.3 Large-card mode; left-handed hand fan.

```
GATE G8 — Polish
Checks:
  [ ] VoiceOver full game UI test; color-blind simulations reviewed
  [ ] Performance budgets met
Sign-off: GLM-SELF
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard P9 and P10 tasks; SRC9.1; SRC10.1. ES-P9.1 court rebalancing to ±4 points.

```
GATE G9 — Beta
Checks:
  [ ] Crash-free ≥ 99.5%; no S1/S2; court win rates within ±4 points
Sign-off: GLM-SELF
GATE G10 — Release
Checks:
  [ ] Store assets approved; SRC10.1 credits draft filed as a `needs-maintainer` issue (SUBSTITUTED); final CI green
Sign-off: GLM-SELF
```

## 9. Fragile Areas and Priorities

- **Fragile areas:** seize timing (R-8); `PlayerView` boundary; void inference in the determinizer; hand-size changes after Market (R-19).
- **Priorities for P6–P10:** async encryption, view-leak audits, VoiceOver for cards; follow penalty, audience frequency, court powers, and ambition mix.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Trick rules feel opaque to non-card players | High | High | Stance picker only when needed; tutorial; preview of action strength before play | GLM |
| Lead player snowballs | Medium | High | Follow penalty, seize, and copy; sims by seat | GLM |
| ISMCTS too slow on iPad | Medium | Medium | Iteration batches; reduce K on iPad (base) | GLM |
| Hidden hands leak in async | Low | High | Encryption plus audit test | GLM |
| Misuse of devotional imagery | Low | High | Secular Mughal suits only; advisor gate | GLM |

## 11. Out of Scope

More than 4 players; real-time play; a deckbuilding campaign; a historical simulation of named Mughal-era states; voice chat.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 2–3 |
| P1 | GLM | 8–11 |
| P2 | GLM | 8–11 |
| P3 | GLM | 7–9 |
| P4 | GLM | 9–13 |
| P5 | GLM | 6–8 |
| P6 | GLM | 14–20 (art commission excluded) |
| P7 | GLM | 8–11 |
| P8 | GLM | 5–7 |
| P9 | GLM | 6–8 |
| P10 | GLM | 2–3 |
| **Total** | | **75–104** |

## 13. Open Questions

1. Fictional realm or loosely historical Deccan setting? Default: fictional realm with historical card art conventions.
2. Commission card art from a living Ganjifa artisan? Default: yes, if budget allows; GLM uses placeholders.
3. Support 5 players? Default: no.

## 14. Sourcing Notes

- **Tradition:** Ganjifa playing cards (Persian and Mughal origin, regional Indian schools in Sawantwadi, Odisha, Mysuru, and Bishnupur).
- **Sources:** IGNCA "Ganjifa – Traditional Playing Cards of India"; Ashmolean Eastern Art blog on Persian and Indian playing cards; MAP Academy articles.
- **Restricted elements:** no Dashavatara (Vishnu avatar) suits or deity imagery; no Quranic text; no depictions of named historical rulers as playable caricatures.
- **Glossary seeds (verified against IGNCA and IPCS; pending advisor):** Ganjifa, Mir/Shah, Wazir, and the 8 Mughal suits Taj, Safed, Shamsher, Ghulam, Chang, Surkh, Barat, and Qimash (96 cards, 8 suits of 12).
- **Historical labels:** suit names and the 96-card Mughal deck are Attested; the trick-to-action mechanic and courts are Invented.

## Appendix A. Extended Specification (Depth Pass)

This appendix extends §4–§13 and wins where they differ.

### A.1 Additional Rules

- R-25 Lead legality: the leader may lead any card. A court power that allows a second lead card (Deccan) is declared before the first card is placed and is shown to all seats.
- R-26 Copy is always legal; follow requires a card of the lead suit; pivot requires a card of a different suit. A seat with no legal follow may still pivot or copy.
- R-27 Seize ordering: the seize window opens to each non-leader in clockwise order before that seat plays; the first seat to discard a seize card closes the window for the round. A seize that fails (the follow is not the highest lead-suit card) still spends the discarded card.
- R-28 Initiative after a seize: the seizing seat leads next round; the original leader still resolves first this round (R-9).
- R-29 Action targets are chosen at resolution time, not at play time; a target made illegal by an earlier resolution in the same round loses that action point (no refund).
- R-30 Battle (R-13) resolves provinces in ascending province index; removed influence is taken first from the seat with the most influence there (ties: the later seat).
- R-31 Law tokens block the named action for every seat, including their owner, in that province only; the capital cannot hold a law token.
- R-32 Market (R-19) draws face down from the undealt pile; drawn cards are known only to the buyer; discards go face down to the discard pile, which is never reshuffled within a chapter.
- R-33 Audience timing: if two seal cards are played in one round, only one Audience occurs; it scores after all resolutions.
- R-34 Army halving (R-23) applies per province, rounding down, after the final Audience.

### A.2 Additional Invariants

- INV-6 Exactly one seat holds initiative at every decision point.
- INV-7 At most one seize per round (R-8, R-27).
- INV-8 Law tokens on the map ≤ 3 and never in the capital.
- INV-9 Hand sizes after Market equal hand sizes before Market (R-19).
- INV-10 `PlayerView` serialised for seat k is identical across two states that differ only in cards hidden from k (determinizer leak test).

### A.3 Complete Schemas and Sample Rows

```swift
struct ProvinceMap: Codable, Hashable, Sendable { var regions: [Region]; var routes: [[Int]]; var laws: [LawToken] }
struct Region: Codable, Hashable, Sendable { var id: Int; var income: Int; var influence: [Int]; var armies: [Int]; var buildings: [BuildingKind]; var isCapital: Bool }
struct LawToken: Codable, Hashable, Sendable { var region: Int; var blocks: SuitAction; var owner: Int }
enum ActionChoice: Codable, Hashable { case placeInfluence([Int: Int]), moveArmies([ArmyMove]), build([Int: BuildingKind]), placeLaw(Int, SuitAction), moveLaw(from: Int, to: Int), marketBuy(count: Int, discards: [Card]) }
struct Seat: Codable, Hashable, Sendable { var court: CourtID; var coins: Int; var favor: Int; var isAI: Bool; var tier: AITier? }
```

```json
{ "id": "malwa", "power": "patronage_plus", "params": { "bonus": 2 }, "homeProvince": 6, "nameKey": "court.malwa", "cultural": true, "status": "pending" }
{ "id": "lawgiver", "metric": "laws_placed_chapter", "first": 5, "second": 2, "tieBreak": "favor" }
```

### A.4 Balance Tables and Sim Targets

| Parameter | Default | Range | Sim Target |
| --- | --- | --- | --- |
| `followPenalty` | 2 | 1–4 | Follow chosen in 35–55% of non-lead plays |
| `seizeCost` (cards) | 1 | 1–2 | Seize attempted in 8–20% of rounds; succeeds in 50–70% of attempts |
| `voidInferenceP` | 0.8 | 0.5–0.95 | Determinizer void accuracy ≥ 85% on logged games |
| `audienceProvincePoints` | 2 | 1–3 | Audiences decide ≥ 50% of final margin |
| `marketCardCost` | 3 | 2–5 | Market used in 5–15% of Qimash resolutions at strength ≥ 3 |
| Court power strength | per court | data | Each court within ±4 points of fair share at Sultan |

### A.5 AI Design in Detail

- **Information set:** the AI receives only `PlayerView`; the determinizer samples hidden hands consistent with seen cards, voids (R-26 evidence), Market draws (count known, identity unknown), and seize discards.
- **Search:** ISMCTS with UCB1 (c = 0.7) over play decisions; resolution choices use a greedy evaluator with a two-option lookahead for War.
- **Rollouts:** heuristic policy (lead the highest card in a suit where the seat holds ≥ 3; follow when strength ≥ 4; otherwise pivot toward the active ambition).
- **Personalities:** `leadThreshold`, `pivotBias`, `seizeAggression`, and `ambitionWeight` scale the priors; Courtier uses the policy alone.
- **Budgets:** Vizier p95 ≤ 0.6 s, Sultan ≤ 1.5 s, Emperor ≤ 3.0 s on iPad (base); iteration batches of 100 keep results deterministic for a seed.

### A.6 Granular Task Breakdown

| ID | Task | Acceptance Criteria |
| --- | --- | --- |
| ES-P1.5 | Seize window and failed-seize handling (R-27, R-28) | 15 fixtures, including a failed seize and two seats eligible |
| ES-P1.6 | Battle ordering and influence removal (R-30) | 12 fixtures; INV-3 property test over 1,000 seeds |
| ES-P1.7 | Law and Market edge cases (R-31, R-32) | Law in capital rejected; INV-9 holds |
| ES-P2.5 | Stance auto-selection | Picker appears only when two or more stances are legal (UI test) |
| ES-P4.3 | View-leak audit tool | Diffs 10,000 views; zero leaks (INV-10) |
| ES-P4.4 | Void inference calibration | Accuracy table in `docs/BALANCE.md` |
| ES-P5.5 | Durbar ladder data | 10 rivals with tier and personality; each beatable by Sultan bot in ≥ 20% of sims |

### A.7 Sharpened Gate Checks

- G1 adds: INV-6 to INV-10 pass over 1,000 seeds.
- G4 adds: Emperor beats Sultan in ≥ 58% of 3-player games (1,000 games).
- G6 adds: every card face and portrait still `pending` is listed in the advisor issue; placeholder art carries the debug mark.

### A.8 Additional Risks

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Card art reads as generic "Indian" pastiche | Medium | High | Ganjifa round-card conventions from RESEARCH.md; advisor issue; placeholders until answered | GLM |
| Determinizer too slow on 4 players | Medium | Medium | Reduce K by tier; cache consistent deals | GLM |

### A.9 Additional Open Questions (Defaults)

1. Include the Dashavatara deck? Default: no; mentioned only in About (religious imagery).
2. Round or square cards? Default: round, matching Ganjifa.
