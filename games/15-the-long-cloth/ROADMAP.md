# 15 — The Long Cloth Roadmap

> A war fought along an embroidered strip of linen: armies advance scene by scene, and the borders above and below the story decide who has the upper hand.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 in full before starting. Depth pass (15 Nov 2026): Appendix A extends §4–§13 and wins where they differ. This roadmap adds only what is specific to The Long Cloth.

Research: [`RESEARCH.md`](RESEARCH.md) (art direction, design lineage, cultural context, advisor institutions, verified glossary, and audio direction).

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 15 · `the-long-cloth` |
| Code prefix | `LC` (packages `LCCore`, `LCContent`, `LCAI`, `LCRender`, `LCAudio`, `LCPlatform`, `LCMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Linear-front card-driven wargame (two players) |
| Difficulty tier | Intermediate |
| Scope | Small team |
| Session length | 20–40 minutes |
| Renderer | SpriteKit horizontal scrolling strip with stitched-texture shader |
| Players | Solo vs AI; local pass-and-play; async online |
| Simulation | Turn-based, hidden hands, seeded decks |
| Sourcing tier | `HISTORICAL` (the Bayeux Tapestry and the 1066 Norman Conquest; plus fictional campaigns in the same style) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** see above.
- **Summary:** The battlefield is a one-dimensional strip of 11–15 scenes. Each player has a home end. Units (embroidered figures: infantry, archers, cavalry, ships, leaders) occupy scenes. Above and below the main register run the border registers (as in the Tapestry: fables, beasts, and later the fallen). Players hold cards that are played either into a scene (to move, attack, or rally) or into the border above or below a scene, where they become persistent modifiers for that scene ("Omen", "Feigned Retreat", "Shield Wall"). Supply runs back along the cloth: units more than N scenes from an unbroken chain of friendly-controlled scenes to home lose strength. Victory: control 3 decisive scenes (marked by the scenario) at the end of a round, or break the enemy leader's morale. The flagship scenario is Hastings (1066) with historical labels; other scenarios are fictional "cloths" in the same visual language.
- **Pillars:**
  1. **One dimension, many decisions.** The strip makes the front readable at a glance.
  2. **Borders matter.** The margins are a second board.
  3. **The cloth tells the story.** Each finished game becomes a scrollable embroidered record with captions.
  4. **History labelled.** Hastings scenario separates Attested events from game abstractions.
- **Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Linen `#E8DFC8`, wool terracotta `#B0533C`, blue-green `#3D6F6A`, dark blue `#2B3A5A`, yellow ochre `#C9A24A`, sage `#7F8F5B`, black-brown `#3A2E26`. |
| Shapes | Figures in laid-and-couched work stylisation; Latin captions in embroidered capitals. |
| Typography | Uncial/insular display (default: an OFL uncial) and SF Pro; captions in Latin with translations. |
| Motion | Stitches draw in when units move; scroll along the cloth; captions stitch at round end. |
| Music | Early medieval plainchant and harp textures (original or public-domain). |
| SFX | Needle pull, cloth rustle, shield bash, horn. |
| Haptics | Stitch ticks on movement. |

- **Inspirations:** The Bayeux Tapestry (Bayeux Museum digital edition); Hicks, "The Bayeux Tapestry: The Life Story of a Masterpiece"; Morris, "The Norman Conquest"; Battle Line and Commands & Colors for card-driven fronts.

## 2. Tech Stack Decision

Per `_CONVENTIONS.md` §2, plus:
- **Linear model:** arrays of scenes; units as stacks; supply as prefix connectivity.
- **Information boundary:** `PlayerView` hides the opponent's hand and deck order.
- ADRs: ADR-0003 1D board; ADR-0004 card effect DSL (closed set); ADR-0005 supply rule.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/LCCore/Sources/LCCore/
  Cloth/    Scene.swift, Border.swift, Control.swift, Supply.swift
  Units/    UnitKind.swift, Stack.swift, Morale.swift, Leader.swift
  Cards/    Card.swift, Deck.swift, Effect.swift, Interpreter.swift
  Combat/   Combat.swift, CombatTable.swift
  Engine/   GameState.swift, PlayerView.swift, Action.swift, Event.swift, Reducer.swift, Round.swift, Victory.swift, Chronicle.swift
Packages/LCContent/  ScenarioDef.swift, CardDef.swift, UnitDef.swift, CaptionDef.swift, Loader.swift
Packages/LCAI/       ISMCTS.swift, Determinize.swift, Eval.swift, Tiers.swift
Packages/LCRender/   ClothScene.swift, StitchShader.fsh, FigureNode.swift, BorderNode.swift, ChronicleView.swift
Packages/LCMeta/     Campaign.swift, Stats.swift
Resources/Content/   scenarios.json, cards.json, units.json, captions.json, balance.json, tutorial.json
```

## 4. Core Rules Specification

**Setup**
- R-1 Scenario defines scene count, decisive scenes, initial stacks, decks per side, hand size (default 5), and leaders.
- R-2 Each stack holds up to 4 units of one side; a scene may hold one stack per side (contested) or one side (controlled).

**Round**
- R-3 A round has 3 actions per player, alternating, starting with the initiative holder.
- R-4 An action is: play a card into a scene (resolve immediately), play a card into a border above or below a scene (persistent while the border slot is free; max 1 card per border slot), or `muster` (draw 1 card and add 1 infantry at the home scene).
- R-5 Scene cards: Advance (move a stack up to N scenes toward the enemy, stopping at contested scenes), Assault (combat in a contested scene), Volley (archers attack an adjacent scene), Rally (restore morale), Embark (ships move along the river scenes).
- R-6 Border cards modify the scene they border: upper border favours the attacker or the morale of the side named on the card; lower border records the fallen (casualties placed there increase the enemy's morale loss when the scene is lost).
- R-7 Combat: each side rolls strength dice (seeded): units' strength + border modifiers + leader bonus; casualties = difference per CombatTable; loser retreats one scene toward home or is eliminated if blocked.
- R-8 Supply (end of round): a stack is in supply if every scene between it and its home is controlled by its side or empty and not enemy-controlled; out-of-supply stacks lose 1 strength step.
- R-9 Morale: leaders have morale tracks; losing a decisive scene or leader death lowers morale; at 0 the side breaks and loses.

**Victory**
- R-10 At round end, a side controlling all scenario decisive scenes (typically 3) wins. Otherwise, after the final round, compare morale.
- R-11 Chronicle: every round appends caption entries to a log (from `captions.json`) rendered as the embroidered record.

**Invariants**
- INV-1 Card conservation (deck, hand, discard, borders).
- INV-2 PlayerView never reveals hidden cards (property test).
- INV-3 Stack limits enforced.
- INV-4 Replay determinism.
- INV-5 Supply computed equals brute-force path check.

## 5. Data Schemas and Content Tables

```swift
struct CardDef: Codable, Sendable { var id: String; var side: Side?; var mode: CardMode /* scene, border, either */; var effect: [EffectStep]; var title: String; var latin: String?; var label: HistoryLabel }
struct ScenarioDef: Codable, Sendable { var id: String; var scenes: Int; var decisive: [Int]; var setup: [StackDef]; var decks: [Side: [String]]; var rounds: Int; var label: HistoryLabel }
enum Action: Codable, Hashable { case playScene(CardID, scene: Int, targets: [Target]), playBorder(CardID, scene: Int, upper: Bool), muster }
```

| Table | G3 | G5 | Sample row |
| --- | --- | --- | --- |
| `scenarios.json` | 3 (Hastings + 2 fictional) | 8 | `{ "id": "hastings_1066", "scenes": 13, "decisive": [6,7,8], "rounds": 8, "label": "Attested" }` |
| `cards.json` | 50 | 110 | `{ "id": "feigned_retreat", "mode": "border", "effect": [{"kind":"lure","n":1}], "title": "Feigned Retreat", "latin": "FUGA SIMULATA", "label": "Reconstructed" }` |
| `units.json` | 6 | 9 | `{ "id": "huscarl", "strength": 3, "morale": 1, "label": "Attested" }` |
| `captions.json` | 60 | 200 | `{ "trigger": "leader_falls", "latin": "HIC … INTERFECTUS EST", "en": "Here … is killed" }` |

Latin captions use templates modelled on the Tapestry's "HIC" phrases; translations shown.

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| Actions per round | 3 | 2–4 | `balance.json` |
| Hand size | 5 | 4–7 | `balance.json` |
| Supply break penalty | 1 step | — | `balance.json` |
| Combat table | data | — | `balance.json` |

Targets: Hastings balanced so the Norman AI wins 50–60% vs Saxon AI at equal tier (history-flavoured but playable); fictional scenarios 45–55%; median game 6–8 rounds; border cards used in 25–45% of actions.

## 7. AI Approach

- **ISMCTS** with determinisation of the opponent's hand from the remaining deck; rollouts with a heuristic policy (advance toward decisive scenes, assault favourable odds, border on contested decisive scenes).
- **Tiers:** Levy (200 iterations), Thegn (1,000), Earl (4,000 or 1.0 s), King (12,000 or 2.5 s).

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7, HIST0.1 (Attested: Tapestry scenes and Hastings events; Reconstructed: feigned retreats (debated), Harold's death (debated: arrow or sword); Invented: rules, fictional cloths).

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; HIST0.1 complete
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- LC-P1.1 Cloth, stacks, control, supply (R-1, R-2, R-8).
- LC-P1.2 Cards and DSL; combat; morale; victory (R-3 to R-10); chronicle (R-11).

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-11 tests; INV-1…INV-5
  [ ] LCCore coverage ≥ 90%; make sim N=2000 deterministic
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5.
- LC-P2.1 Scrolling cloth with minimap; hand view; drag card to a scene or border slot; combat resolution panel with odds.
- LC-P2.2 Hastings vs Thegn AI.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test completes Hastings on iPad and Mac
  [ ] Odds panel matches Core combat distribution (exact enumeration) on 200 cases
  [ ] `docs/SLICE_ASSESSMENT.md` written: self-assessment against the pillars, with every weakness turned into a P3 task (`_CONVENTIONS.md` §8.1)
Sign-off: GLM-SELF
```

### P3 Content and Systems
- LC-P3.1 G3 content; HIST3.1; chronicle view (scrollable finished cloth).
- LC-P3.2 Tutorial (4 lessons); pass-and-play with hand privacy.

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts met; lint clean; 1,000 AI games per scenario
Sign-off: GLM-SELF
```

### P4 AI Opponents
- LC-P4.1 ISMCTS tiers; `docs/BALANCE.md`.

```
GATE G4 — AI
Checks:
  [ ] Each tier beats the one below ≥ 65% (swapping sides); targets met; p95 budgets
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- LC-P5.1 G5 counts; campaign of linked cloths; share chronicle image; 20 achievements; HANDOFF.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Counts met; HANDOFF complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- LC-P6.1 Stitch shader; commissioned embroidered figure art (original, not traced from the Tapestry); HIST6.1.
- LC-P6.2 Music and SFX.

```
GATE G6 — Aesthetics
Checks:
  [ ] Snapshots approved; HIST6.1 clean
Sign-off: GLM-SELF
```

### P7 Platform Features
- LC-P7.1 Async, Game Center, iCloud; Mac trackpad horizontal scroll; export chronicle as a long PNG.

```
GATE G7 — Platform
Checks:
  [ ] Async completes; export verified
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- LC-P8.1 VoiceOver scene rotor; sides by shape and border pattern; captions read in English.

```
GATE G8 — Polish
Checks:
  [ ] VoiceOver completes a game; budgets met
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

1. Advance stops at the first contested scene.
2. Blocked retreat eliminates the losing stack.
3. Border slot holds at most one card; a second play to the same slot is rejected.
4. Supply: a stack beyond an enemy-controlled scene is out of supply at round end.
5. Morale 0 ends the game immediately.
6. Decisive-scene victory checked only at round end.
7. PlayerView of Player 1 contains no Player 2 hand cards.
8. Chronicle emits the leader-falls caption when a leader is eliminated.

## 9. Fragile Areas and Priorities

- **Fragile areas:** retreat when blocked; border persistence when scenes change control.
- **Priorities for P6–P10:** stitch shader, chronicle export; card balance; history labels.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| 1D feels shallow | Medium | High | Borders, supply, card variety | GLM |
| Art too derivative of the Tapestry | Low | Medium | Original figures in the style | GLM |

## 11. Out of Scope

Two-dimensional maps; more than two sides; real-time.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 2 |
| P1 | GLM | 6–8 |
| P2 | GLM | 5–7 |
| P3 | GLM | 5–7 |
| P4 | GLM | 4–6 |
| P5 | GLM | 3–5 |
| P6 | GLM | 8–11 |
| P7 | GLM | 3–5 |
| P8 | GLM | 3–4 |
| P9 | GLM | 4–6 |
| P10 | GLM | 2–3 |
| **Total** | | **45–64** |

## 13. Open Questions

1. More historical cloths (Stamford Bridge, Crusades) or fictional? Default: Hastings plus fictional at launch.

## 14. Sourcing Notes

- **Sources:** Bayeux Museum digital Tapestry; Hicks (2006); Bates, "William the Conqueror" (2016); Lawson, "The Battle of Hastings 1066".
- **Historical labels:** listed in HIST0.1.

## Appendix A. Extended Specification (Depth Pass)

### A.1 Additional Rules

**Scenes and stacks**
- R-12 Scenes are indexed 0 (Side A home) to n−1 (Side B home). Scene kinds (data): field, hill (+1 defender strength), river (Embark only for ships; land units cross at fords marked in data), village (Rally +1), and coast.
- R-13 Unit kinds (G3): infantry (str 2), heavy infantry/huscarls (3), archers (1; Volley range 1), cavalry (3; +1 when advancing into a scene this action), ships (carry up to 2 units; move along river and coast scenes), leaders (0 strength; +1 to their stack's combat, morale anchor).
- R-14 A stack that enters a scene with an enemy stack stops (the scene becomes contested); stacks never pass through contested or enemy-controlled scenes.

**Combat detail**
- R-15 Combat strength = Σ unit strengths + hill bonus + border modifiers + leader bonus + d6 per side (seeded, displayed). Difference `Δ` maps to casualties via the CombatTable: Δ 0 → 1 each; 1–2 → loser 1; 3–4 → loser 2; ≥ 5 → loser 2 and retreats; ties retreat neither.
- R-16 Casualties are taken from the strongest non-leader unit first if the owner chooses "shield wall" (border card) else owner's choice; leaders die only when they are the last unit in a stack that takes a casualty.
- R-17 Volley: archers deal 1 casualty if their roll (d6 + archers) ≥ 5 + target scene's hill bonus; the target cannot retaliate.

**Borders**
- R-18 Each scene has an upper and lower border slot. Upper border cards are persistent modifiers (e.g., "Omen: comet" +1 morale for the side named); lower border receives fallen markers automatically: each casualty in that scene adds a fallen marker; when the scene's controller changes, the losing side loses morale equal to ⌈fallen/2⌉ (max 3), then markers clear.
- R-19 A border card can be overwritten only by a card that explicitly says "unpick"; the unpicked card goes to its owner's discard.

**Hand and deck**
- R-20 Hand size 5; draw to hand size at round end; reshuffle discard when the deck is empty (seeded); a side that would reshuffle a second time loses 1 morale (fatigue).
- R-21 Initiative: the side with higher total morale takes initiative next round; ties alternate.

**Chronicle**
- R-22 Caption templates use exact Latin forms attested on the Tapestry, checked in HIST6.1; any newly composed Latin goes into a Latin-review `needs-maintainer` issue, and until it is answered those captions use English with "[Latin pending]".

### A.2 Additional Invariants
- INV-6 Morale ≥ 0 and ≤ max per leader; side breaks exactly at 0.
- INV-7 Fallen markers in each lower border equal casualties in that scene since its last control change.
- INV-8 No stack passes through a contested scene (property test on 10,000 random advances).
- INV-9 Every caption template renders without missing slots for all triggers.

### A.3 Complete Schemas and Sample Rows

```swift
struct SceneDef: Codable, Sendable { var index: Int; var kind: SceneKind; var name: String; var ford: Bool }
struct UnitDef: Codable, Sendable { var id: String; var strength: Int; var morale: Int; var carries: Int?; var label: HistoryLabel }
struct StackDef: Codable, Sendable { var side: Side; var scene: Int; var units: [String]; var leader: String? }
enum EffectStep: Codable, Sendable { case advance(max: Int), assault, volley, rally(Int), embark(max: Int), lure(Int), modifyStrength(Int, side: SideRef), modifyMorale(Int, side: SideRef), unpick, shieldWall }
struct CaptionDef: Codable, Sendable { var trigger: CaptionTrigger; var latin: String?; var en: String; var reviewed: Bool }
struct LeaderDef: Codable, Sendable { var id: String; var side: Side; var morale: Int; var bonus: Int; var label: HistoryLabel }
```

```json
{ "index": 7, "kind": "hill", "name": "The Ridge", "ford": false }
{ "id": "harold", "side": "english", "morale": 6, "bonus": 1, "label": "Attested" }
{ "id": "comet", "mode": "border", "effect": [{"modifyMorale": [1, "named"]}], "title": "The Star", "latin": null, "label": "Attested" }
{ "trigger": "scene_taken", "latin": null, "en": "Here the {side} take {scene}", "reviewed": false }
```

The comet appears on the Tapestry with the caption ISTI MIRANT STELLA ("these men wonder at the star"); the card's title stays English until Latin review.

### A.4 Balance Tables and Sim Targets

| Parameter | Default | Range | Sim Target |
| --- | --- | --- | --- |
| Actions per round | 3 | 2–4 | Rounds per game 6–9 |
| Hand size | 5 | 4–6 | Border cards 25–40% of plays |
| Hill bonus | 1 | 0–2 | Hastings: defender holds ridge until round 5+ in 40–60% of games |
| Fallen morale cap | 3 | 2–4 | Morale breaks end 40–60% of games |
| Cavalry charge bonus | 1 | 0–2 | Cavalry share of casualties inflicted 25–40% |
| Hastings balance | per scenario | — | Each side wins 45–55% (King vs King) |

Historical-outcome note: the game does not force the historical result; the About screen states that William won in 1066 and that the game models why either outcome was possible.

### A.5 AI Design in Detail
- **Determinisation:** sample the opponent's hand uniformly from unseen cards consistent with public plays (border cards revealed).
- **Rollout policy:** priority list — Assault if Δ expected ≥ 2; Advance toward nearest uncontrolled decisive scene; Border on contested decisive scene with the highest fallen count; Muster if hand < 3.
- **Evaluation at rollout cutoff (depth 12 actions):** morale difference × 10 + decisive scenes held × 15 + strength on board × 2.
- **Tier budgets:** as §7; King uses progressive widening on border placements.

### A.6 Granular Task Breakdown

| ID | Task | Acceptance Criteria |
| --- | --- | --- |
| LC-P0.1 | HISTORY.md with Attested/Reconstructed/Invented for Hastings | Every card and unit labelled |
| LC-P1.1 | Scenes, stacks, movement (R-2, R-12–R-14) | INV-3, INV-8 |
| LC-P1.2 | Combat and casualties (R-7, R-15–R-17) | 30 fixtures |
| LC-P1.3 | Borders and fallen (R-6, R-18, R-19) | INV-7 |
| LC-P1.4 | Supply (R-8) | INV-5 |
| LC-P1.5 | Morale, initiative, victory (R-9, R-10, R-21) | INV-6 |
| LC-P1.6 | Deck, hand, fatigue (R-20) | INV-1, INV-2 |
| LC-P1.7 | Chronicle templates (R-11, R-22) | INV-9 |
| LC-P2.1 | Horizontal scrolling strip with embroidery shader (stem and laid-and-couched stitch look) | 60 fps; 15 scenes |
| LC-P2.2 | Border slots UI | Shows persistent modifiers |
| LC-P2.3 | Chronicle view: the game as a long cloth export (image) | PNG export matches log |
| LC-P3.1 | Hastings + 2 fictional scenarios | Lint; labels |
| LC-P4.1 | ISMCTS and tiers | Gaps ≥ 70% |
| LC-P5.1 | Additional scenarios (Stamford Bridge, fictional) | Sims in range |

### A.7 Sharpened Gate Checks
- G1 adds: combat table fixtures for every Δ band; INV-2 property test.
- G3 adds: HISTORY.md agrees with card labels; Latin captions marked pending until reviewed.
- G5 adds: chronicle export renders a full game without overlapping captions.

### A.8 Additional Risks

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Incorrect Latin | Medium | Medium | Latin checked against the Bayeux Tapestry inscriptions in `docs/HISTORY.md`; a Latin-review `needs-maintainer` issue filed in P6; English fallback | GLM |
| Copying Tapestry figures directly | Medium | Medium | Original figures in the style (public-domain object, but our art is original) | GLM |
| Nationalist framing (English vs Norman) | Low | Medium | Neutral About text | GLM |

### A.9 Additional Open Questions (Defaults)
1. Show the fallen in lower borders graphically? Default: yes, abstract (stitched marks), not graphic bodies.
2. Include the Harold arrow-in-the-eye scene? Default: no; it is debated, and the caption is about the event, not the arrow.
3. Call it "tapestry" in UI? Default: "the cloth" and "embroidery" (it is technically embroidery).
