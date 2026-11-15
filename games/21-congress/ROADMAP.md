# 21 — Congress Roadmap

> A diplomatic congress in caricature: every delegate carries secret instructions, every offer is on the record, and the AI delegates remember who lied to them.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 in full before starting. Depth pass (15 Nov 2026): Appendix A extends §4–§13 and wins where they differ. This roadmap adds only what is specific to Congress.

Research: [`RESEARCH.md`](RESEARCH.md) (art direction, design lineage, cultural context, advisor institutions, verified glossary, and audio direction).

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 21 · `congress` |
| Code prefix | `CN` (packages `CNCore`, `CNContent`, `CNAI`, `CNRender`, `CNAudio`, `CNPlatform`, `CNMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Negotiation strategy (structured offers, hidden objectives) |
| Difficulty tier | Deep |
| Scope | Larger team |
| Session length | 60–120 minutes (quick congress 30) |
| Renderer | SwiftUI with SpriteKit map inset; aquatint caricature art |
| Players | 1 human vs 4–6 AI delegates; local pass-and-play 2–6 (with privacy); async online (friends) |
| Simulation | Turn-based sessions; hidden instructions; AI delegates with persistent memory |
| Sourcing tier | `NONE` (fictional powers parodying 19th-century congress diplomacy; HIST labels optional) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** see above.
- **Summary:** Five to seven fictional powers meet to redraw a map after a war. Each delegate receives secret instructions (objectives with point values: gain province X, keep Y out of Z's hands, secure a trade treaty, avoid humiliation). The congress proceeds in sessions; each session has a committee agenda (territories, trade, indemnities, guarantees). Negotiation is structured: offers are built from a closed grammar ("I give you A and B if you vote Yes on C and give me D"), proposals are made privately or publicly, and binding agreements are recorded in the protocol. Votes decide committee outcomes (weighted by power). Promises outside binding treaties can be broken; AI delegates remember broken promises (trust ledger) and respect (from successful brinkmanship and public commitments). At the end, delegates score secret objectives; the highest score wins. No free-text chat with AI and no LLM at runtime: AI uses utility models, beliefs about others' instructions, and reputation memory.
- **Pillars:**
  1. **Structured talk.** The offer grammar is expressive enough for real deals and precise enough for AI.
  2. **Memory makes reputation.** Lies cost later.
  3. **Hidden goals, readable play.** Inference about others' instructions is the core skill.
  4. **Satire with teeth.** Gillray-style caricature, fictional powers.
- **Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Aquatint paper `#EFE4CB`, sepia ink `#3B2A1E`, wash pink `#D9967E`, wash blue `#7FA1B8`, wash green `#8FA77A`, gilt `#C59B43`, wax red `#9E2B25`. Power colours: muted washes. |
| Shapes | Caricatured delegates (original art) with exaggerated features per power; congress hall, map table, treaty parchments with seals. |
| Typography | Caslon-like (Big Caslon, system) and a copperplate script for signatures. |
| Motion | Delegates' portraits react (smirk, scowl) by stance; seals stamped on treaties. |
| Music | Classical-era pastiche (string quartet, original). |
| SFX | Quill, gavel, murmurs, wax seal. |
| Haptics | Seal stamp. |

- **Inspirations:** Diplomacy (Calhamer); the Congress of Vienna (Zamoyski, "Rites of Peace"; King, "Vienna 1814"); James Gillray's caricatures (public domain); Raiffa, "The Art and Science of Negotiation" (1982); Meta's CICERO research (for context; no LLM used here).

## 2. Tech Stack Decision

Per `_CONVENTIONS.md` §2, plus:
- **Offer grammar:** algebraic data type of offer terms with validation; an offer is a pair of term sets (give, get) plus conditions.
- **AI:** utility from instructions; beliefs about others' instructions (Bayesian over instruction deck); trust and respect ledgers; negotiation by evaluating counteroffers via search over term bundles (bounded).
- **Privacy:** `PlayerView` hides others' instructions and private offers.
- ADRs: ADR-0003 offer grammar; ADR-0004 AI belief and memory model; ADR-0005 no LLM (determinism and privacy).

## 3. Repository Structure (Game-Specific Additions)

```
Packages/CNCore/Sources/CNCore/
  World/       Power.swift, Province.swift, Map.swift
  Agenda/      Committee.swift, Session.swift, Vote.swift
  Offers/      Term.swift, Offer.swift, Grammar.swift, Validation.swift, Treaty.swift, Protocol.swift
  Objectives/  Instruction.swift, Scoring.swift
  Engine/      GameState.swift, PlayerView.swift, Action.swift, Event.swift, Reducer.swift
Packages/CNContent/  PowerDef.swift, InstructionDef.swift, ScenarioDef.swift, PersonaDef.swift, Loader.swift
Packages/CNAI/       Utility.swift, Beliefs.swift, Memory.swift (trust, respect), Negotiator.swift, Voter.swift, Personas.swift, Explain.swift
Packages/CNRender/   HallView.swift, MapInset.swift, OfferBuilder.swift, ProtocolView.swift, PortraitView.swift
Packages/CNMeta/     Scenarios.swift, Stats.swift
Resources/Content/   powers.json, provinces.json, instructions.json, scenarios.json, personas.json, balance.json, tutorial.json
```

## 4. Core Rules Specification

**Setup**
- R-1 Scenario: powers (5–7), provinces with current holders and values, committees order, instruction deck; each power draws 4 instructions (objectives with points and type).

**Sessions**
- R-2 A session handles one committee item. Phases: (1) Opening statements (each delegate may make one public commitment, for example "We will never accept X"); (2) Negotiation rounds (3 rounds; in each, each delegate may send up to 2 private offers and 1 public offer); (3) Responses (accept, reject, counter); accepted offers become binding treaties if marked binding, else promises; (4) Vote on the committee item (options defined per item; votes weighted by power rank); (5) Resolution.
- R-3 Binding treaties are enforced by the engine (votes locked, transfers executed). Promises are not enforced.
- R-4 Public commitments: breaking one costs respect with all delegates.

**Offer grammar**
- R-5 Terms: `transfer(province, from, to)`, `vote(item, option)`, `indemnity(amount, from, to)`, `guarantee(power, province)`, `tradeTreaty(a, b)`, `support(future item, option)`. Conditions: `if vote passes`, `if X accepts`. Offers validated for feasibility.

**Memory and reputation**
- R-6 Each AI holds trust[other] and respect[other] (0–100). Kept promises raise trust; broken promises drop trust by `betrayalCost`; public commitments upheld raise respect; bluffs called reduce respect.

**End and scoring**
- R-7 After all committees, score instructions (fully met, partially met per data); highest wins; ties by provinces held.

**Invariants**
- INV-1 Binding treaties always executed.
- INV-2 PlayerView hides instructions and private offers (property test).
- INV-3 Offers validated; invalid offers never accepted.
- INV-4 Replay determinism including AI.
- INV-5 Every AI response has an explain record (utility components and trust effects).

## 5. Data Schemas and Content Tables

```swift
indirect enum Term: Codable, Hashable, Sendable { case transfer(ProvinceID, from: PowerID, to: PowerID), vote(ItemID, OptionID, by: PowerID), indemnity(Int, from: PowerID, to: PowerID), guarantee(PowerID, ProvinceID), tradeTreaty(PowerID, PowerID), support(ItemID, OptionID, by: PowerID) }
struct Offer: Codable, Hashable, Sendable { var id: OfferID; var from: PowerID; var to: [PowerID]; var give: [Term]; var get: [Term]; var conditions: [Condition]; var binding: Bool; var isPublic: Bool }
struct InstructionDef: Codable, Sendable { var id: String; var kind: InstructionKind; var params: [String: String]; var points: Int; var partial: Int }
struct PersonaDef: Codable, Sendable { var id: String; var name: String; var greed: Int; var vengefulness: Int; var bluffRate: Int; var riskAversion: Int }
enum Action: Codable, Hashable { case commit(Statement), sendOffer(Offer), respond(OfferID, Response), vote(ItemID, OptionID), passRound }
```

| Table | G3 | G5 | Sample row |
| --- | --- | --- | --- |
| `powers.json` | 6 | 8 | `{ "id": "ostmark", "name": "Grand Duchy of Ostmark", "rank": 3, "colour": "#7FA1B8" }` |
| `instructions.json` | 40 | 100 | `{ "id": "gain_saltmarsh", "kind": "gain", "params": {"province": "saltmarsh"}, "points": 6, "partial": 0 }` |
| `scenarios.json` | 2 | 5 | `{ "id": "congress_of_varenne", "powers": [...], "items": [...] }` |
| `personas.json` | 6 | 12 | `{ "id": "fox", "name": "The Old Fox", "greed": 6, "vengefulness": 8, "bluffRate": 4, "riskAversion": 5 }` |

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| Negotiation rounds per session | 3 | 2–4 | `balance.json` |
| Offers per round | 2 private + 1 public | — | `balance.json` |
| Betrayal cost | 25 trust | 10–40 | `balance.json` |
| Vote weights by rank | 3, 3, 2, 2, 1, 1, 1 | — | `scenarios.json` |

Targets (AI-only sims, 1,000 congresses): seat win shares within ±5% of uniform; ≥ 60% of sessions see at least one binding treaty; a "betrayer" bot wins 10–20% (betrayal is viable but costly); human playtests: average 10–20 offers per session.

## 7. AI Approach

- **Utility:** expected instruction points given beliefs about the final outcome, plus persona terms (greed, vengefulness toward low-trust powers).
- **Beliefs:** Bayesian over each other power's instruction set, updated by offers made, votes cast, and commitments (likelihood tables).
- **Negotiator:** generates candidate offers by local search over term bundles (≤ 4 terms) maximising own utility subject to estimated acceptance probability by the recipient (from beliefs and trust); evaluates incoming offers by utility delta and trust-weighted reliability of promises.
- **Tiers:** Attaché, Envoy, Ambassador (deeper search, better belief updates).
- **Explain:** "The Old Fox rejected: values Saltmarsh at 6; distrusts you (broke promise in session 2)."

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
- CN-P1.1 World, agenda, sessions, votes (R-1, R-2).
- CN-P1.2 Offer grammar, validation, treaties, promises, commitments (R-3 to R-5).
- CN-P1.3 Memory and scoring (R-6, R-7).

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-7 tests; INV-1…INV-4
  [ ] CNCore coverage ≥ 90%; make sim N=500 deterministic (random agents)
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5.
- CN-P2.1 Hall view with portraits; offer builder (drag provinces, votes, and money onto give/get trays); inbox of offers; protocol view; vote panel.
- CN-P2.2 Simple utility AI (no beliefs yet) for 4 delegates; quick congress scenario.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test completes a quick congress on iPad and Mac
  [ ] Offer builder cannot construct invalid offers (property test on UI model)
  [ ] `docs/SLICE_ASSESSMENT.md` written: self-assessment against the pillars, with every weakness turned into a P3 task (`_CONVENTIONS.md` §8.1)
Sign-off: GLM-SELF
```

### P3 Content and Systems
- CN-P3.1 G3 content; tutorial (5 lessons: offers, binding, votes, commitments, inference).
- CN-P3.2 Pass-and-play privacy; save anywhere.

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts met; lint clean; 1,000 AI congresses complete
Sign-off: GLM-SELF
```

### P4 AI Opponents
- CN-P4.1 Beliefs, memory, negotiator, personas, explain (INV-5); tiers; `docs/BALANCE.md`.

```
GATE G4 — AI
Checks:
  [ ] Ambassador win share ≥ 30% vs Attachés in 6-power congress
  [ ] AI response p95 ≤ 500 ms; session AI total ≤ 5 s
  [ ] Targets in §6 met or ADR
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- CN-P5.1 G5 counts; career of a diplomat across congresses (reputation persists); 24 achievements; HANDOFF.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Counts met; HANDOFF complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- CN-P6.1 Caricature portraits with expression sets (commissioned); hall and map art.
- CN-P6.2 Music and SFX.

```
GATE G6 — Aesthetics
Checks:
  [ ] Snapshots approved; caricatures reviewed for ethnic stereotyping (none)
Sign-off: GLM-SELF
```

### P7 Platform Features
- CN-P7.1 Async friends congress with AI fill; private offers via per-player encryption in match data; Game Center; iCloud.

```
GATE G7 — Platform
Checks:
  [ ] 3-human async congress completes; private offers unreadable by others
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- CN-P8.1 VoiceOver offer builder (list-based alternative); explain panel read aloud; Dynamic Type.

```
GATE G8 — Polish
Checks:
  [ ] VoiceOver completes the tutorial; budgets met
Sign-off: GLM-SELF
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard tasks.

```
GATE G9 — Beta
Checks:
  [ ] Crash-free ≥ 99.5%; AI exploit reports triaged
Sign-off: GLM-SELF
GATE G10 — Release
Checks:
  [ ] Store assets; final CI green
Sign-off: GLM-SELF
```

### Key Test Fixtures (GLM Writes These in P1)

1. Binding treaty with a vote term locks the delegate's vote.
2. Invalid transfer (province not held by the giver) is rejected.
3. Conditional offer applies only if its condition is met at resolution.
4. Breaking a promise lowers trust by `betrayalCost` for the victim only.
5. Breaking a public commitment lowers respect with all delegates.
6. Weighted vote with ranks 3, 3, 2, 2, 1 resolves correctly with ties.
7. PlayerView hides private offers between other delegates.
8. Explain record lists utility delta and trust effect for every AI response.

## 9. Fragile Areas and Priorities

- **Fragile areas:** belief updates (likelihood tables), conditional offers resolution order.
- **Priorities for P6–P10:** offer builder UX; async privacy; AI tuning, exploit hunting.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| AI feels robotic | High | High | Personas, memory, explain, portraits | GLM |
| AI exploitable by spam offers | Medium | High | Offer limits; trust decay for spam | GLM |
| Offer builder too fiddly | Medium | High | Templates and suggestions | GLM |

## 11. Out of Scope

Free-text chat with AI; LLM delegates; real historical powers as playable (post-launch historical scenario candidate).

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 2 |
| P1 | GLM | 8–11 |
| P2 | GLM | 8–11 |
| P3 | GLM | 6–8 |
| P4 | GLM | 12–16 |
| P5 | GLM | 4–6 |
| P6 | GLM | 9–12 |
| P7 | GLM | 6–8 |
| P8 | GLM | 4–6 |
| P9 | GLM | 6–9 |
| P10 | GLM | 2–3 |
| **Total** | | **67–92** |

## 13. Open Questions

1. Add a historical Congress of Vienna scenario? Default: post-launch, with HIST labels.

## Appendix A. Extended Specification (Depth Pass)

### A.1 Additional Rules

**Committee items and voting**
- R-8 Each committee item has 2–4 options (e.g., "Saltmarsh to Ostmark", "Saltmarsh neutral under guarantee", "status quo"). Votes are weighted by power rank (great powers 3, middle 2, small 1; data).
- R-9 An option passes with a weighted majority of votes cast; if no option has a majority, the item falls to the chair's compromise (scenario-defined default option) and every power loses 1 respect with the chair (pressure to agree).
- R-10 Abstention is allowed and counts toward neither option.
- R-11 The chair rotates each session in rank order; the chair breaks exact ties.

**Offers detail**
- R-12 Private offers are visible only to recipients; a recipient may reveal a private offer publicly (showing the sender's terms), costing the revealer 5 trust with the sender and earning 2 respect from others if the offer was duplicitous (conflicting promises detected by the engine).
- R-13 Conditional offers resolve after the vote; a condition referencing a later item creates a promise of future support (enforced only if binding).
- R-14 Binding treaties require both parties to spend 1 "seal" (each power has 3 seals per congress) — scarcity makes binding commitments meaningful.
- R-15 Indemnities transfer treasury points; treasury cannot go negative; an infeasible indemnity invalidates the offer (INV-3).

**Reputation detail**
- R-16 Trust update on a promise kept: +8 (capped 100); broken: −`betrayalCost` (default 25) with the victim, −5 with every other power that learns of it (public revelation or the victim's announcement).
- R-17 Respect: public commitment kept +5 with all; broken −15 with all.
- R-18 Humiliation: losing a home province or failing all "avoid humiliation" instructions sets a "humiliated" flag: that power's vengefulness doubles for the rest of the congress.

**Scoring detail**
- R-19 Instruction kinds: gain (province), deny (keep province from a power), keep (retain province), treaty (trade treaty with power), indemnity (receive ≥ amount), honour (no broken public commitments), avoid humiliation.
- R-20 Partial credit only where the instruction defines it (e.g., neutralisation instead of denial).

### A.2 Additional Invariants
- INV-6 Seals per power ≤ 3 and never negative.
- INV-7 Weighted vote totals equal the sum of rank weights of non-abstaining powers.
- INV-8 Trust and respect in [0, 100].
- INV-9 Instruction scoring is a pure function of the final map, treaties, treasury, and commitment log.

### A.3 Complete Schemas and Sample Rows

```swift
struct ItemDef: Codable, Sendable { var id: String; var committee: Committee; var options: [OptionDef]; var defaultOption: String; var session: Int }
struct OptionDef: Codable, Sendable { var id: String; var effects: [Term]; var text: String }
struct Statement: Codable, Hashable, Sendable { var kind: StatementKind; var item: ItemID?; var option: OptionID?; var power: PowerID? }
enum StatementKind: String, Codable, Sendable { case neverAccept, willSupport, willOppose, guaranteeOf }
struct Reputation: Codable, Hashable, Sendable { var trust: [PowerID: Int]; var respect: [PowerID: Int] }
struct TreatyRecord: Codable, Hashable, Sendable { var offer: OfferID; var parties: [PowerID]; var binding: Bool; var session: Int; var fulfilled: Bool? }
```

```json
{ "id": "item_saltmarsh", "committee": "territories", "options": [{"id": "to_ostmark", "effects": [{"transfer": ["saltmarsh", "varenne", "ostmark"]}], "text": "Saltmarsh to Ostmark"}, {"id": "neutral", "effects": [{"guarantee": ["all", "saltmarsh"]}], "text": "Neutral Saltmarsh"}, {"id": "status_quo", "effects": [], "text": "Status quo"}], "defaultOption": "neutral", "session": 2 }
{ "kind": "neverAccept", "item": "item_saltmarsh", "option": "to_ostmark", "power": null }
{ "id": "honour_word", "kind": "honour", "params": {}, "points": 4, "partial": 0 }
```

### A.4 Balance Tables and Sim Targets

| Parameter | Default | Range | Sim Target |
| --- | --- | --- | --- |
| Instructions per power | 4 | 3–5 | Winner meets 2–3 of 4 on average |
| Seals | 3 | 2–4 | Binding treaties 3–8 per congress |
| Betrayal cost | 25 | 15–40 | Broken promises 2–6 per congress |
| Rank weights | 3/2/1 | — | Small powers win 15–25% (6 powers) |
| Offers per round | 2 private, 1 public | — | 60–120 offers per congress |
| Session count | 6–8 | — | 60–90 minutes per human game |

Persona balance in 6-bot games: no persona wins > 25% or < 10%.

### A.5 AI Design in Detail
- **Beliefs:** for each other power, a distribution over instruction sets sampled from the deck (importance sampling with 500 samples, integer weights); likelihood of observed actions computed from a softmax over that power's utility given the sample.
- **Outcome forecasting:** for each item, estimate vote probabilities from beliefs and current treaties; expected utility via 200 sampled futures.
- **Offer generation:** hill-climb over term bundles from a candidate pool (my items, their likely wants); acceptance probability = logistic of the recipient's estimated utility gain × reliability (trust/100 for promises; 1 for binding).
- **Lying policy:** bluffRate controls promises the AI does not intend to keep (only non-binding); never violates binding treaties (engine-enforced).
- **Explain records:** components (instruction points, persona terms, trust adjustments) logged per decision.

### A.6 Granular Task Breakdown

| ID | Task | Acceptance Criteria |
| --- | --- | --- |
| CN-P1.1 | Scenario, powers, provinces, items (R-1, R-8) | Lint |
| CN-P1.2 | Session flow and chair (R-2, R-9–R-11) | INV-7 |
| CN-P1.3 | Offer grammar and validation (R-5, R-13, R-15) | INV-3; 40 fixtures |
| CN-P1.4 | Treaties, seals, enforcement (R-3, R-14) | INV-1, INV-6 |
| CN-P1.5 | Commitments and reveals (R-4, R-12, R-17) | 15 fixtures |
| CN-P1.6 | Reputation (R-6, R-16, R-18) | INV-8 |
| CN-P1.7 | Scoring (R-7, R-19, R-20) | INV-9 |
| CN-P2.1 | Map with province holders and committee table | Snapshot tests |
| CN-P2.2 | Offer builder (drag terms into give/get) | Only valid offers sendable |
| CN-P2.3 | Diplomatic log with explain cards | INV-5 |
| CN-P3.1 | 2 scenarios, 40 instructions, 6 personas | Lint |
| CN-P4.1 | Belief model and negotiator | Persona balance met |
| CN-P4.2 | Performance: AI turn ≤ 1.5 s on A15 | Profiler report |
| CN-P5.1 | Online play (Game Center turn-based) | 2-device test |

### A.7 Sharpened Gate Checks
- G1 adds: offer validator rejects 100% of 500 generated infeasible offers.
- G2 adds: a scripted UI test completes a full session using only the offer builder; the human timing check is SUBSTITUTED per `_CONVENTIONS.md` §8.2.
- G4 adds: AI never violates a binding treaty in 10,000 bot games (enforced and asserted).

### A.8 Additional Risks

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| AI diplomacy feels opaque | High | High | Explain records and trust meters | GLM |
| Offer builder too complex on iPhone | High | Medium | Templates for common offers | GLM |
| Echoes of real treaties seen as political | Low | Low | Fictional powers; Vienna 1815 only in About | GLM |

### A.9 Additional Open Questions (Defaults)
1. Free-text chat in multiplayer? Default: no; structured offers only (moderation and AI parity).
2. Show AI trust meters to the player? Default: yes, approximate (three bands).
3. Historical scenario (Vienna 1814–15)? Default: post-launch, as a labelled historical scenario.
