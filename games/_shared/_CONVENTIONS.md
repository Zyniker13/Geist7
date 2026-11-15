# Shared Conventions for All Strategy Game Roadmaps

Version 2.0 · 2026-11-15 · Applies to every game roadmap at `../NN-<slug>/ROADMAP.md`.

Set Two also has [`_SET2_ADDENDUM.md`](_SET2_ADDENDUM.md) (respectful sourcing, historical labels, and set-wide technical notes); read it after this file and before the game roadmap.

Every roadmap references this file. When a roadmap and this file disagree, **the roadmap wins for game-specific facts** (rules, content, modules) and **this file wins for process, stack, standards, and gates**. The build agent must read this file in full before starting P0 of any game.

---

## 1. Roles and Sign-Off Codes

| Code | Who | Responsibility |
| --- | --- | --- |
| `GLM` | The autonomous build agent | Builds every game end to end, P0 through P10, and checks every gate itself. |
| Maintainer | The repository owner | Only the steps that need an Apple account, real devices, money, or a public action: App Store Connect records, signing certificates, TestFlight, App Store submission, pricing, spending, and posting publicly. The maintainer may play and review any build at any time; those reviews are outside the roadmaps and never gate GLM. |

Every gate is signed off `GLM-SELF`: GLM runs every check itself, pastes the evidence into `docs/STATUS.md`, tags `<slug>/gate-Gn-pass` (see §6), and goes straight on to the next phase.

### 1.1 Owner-Only Steps and Blockers (Same for Every Game)

GLM never stops a game and never waits. Instead:

1. **A step only the maintainer can do** (an Apple Developer account action, real signing certificates, App Store Connect, TestFlight, payment, a third-party account, a real device, a human playtest or approval, or a cultural advisor's sign-off): do everything possible locally using the substitutes in §8.2, record the check as `SUBSTITUTED` with the local evidence and the maintainer item's link, file the item (see "Issues for the Maintainer" in the root `ROADMAP.md`), and continue.
2. **A gate check that fails three consecutive, genuinely different fix attempts:** record it in `docs/KNOWN_ISSUES.md`, file a `blocked` item, mark the check `FAILED` in `docs/STATUS.md`, and continue with the next phase if it does not depend on the failed check; if it does, the game is `Blocked` and GLM moves on to the next game until the item is answered (root `ROADMAP.md`, "Program Loop"). Do not tag that gate until the check passes; retry every open `FAILED` check before the game's G10.
3. **A design ambiguity that would change a rule in `docs/RULES.md`:** use the roadmap's default if it lists one; otherwise choose the option most consistent with the roadmap's pillars (§1), record it as an ADR and in `docs/OPEN_QUESTIONS.md`, file a `question` item, and continue.
4. **A dependency outside the allow-list (§4.4) seems necessary:** do not add it. Write the code yourself or use an allow-listed package; if neither is feasible, ship a tested stub, file a `blocked` item, and continue.

---

## 2. Fixed Technology Stack (Do Not Re-Decide)

| Concern | Decision | Rationale |
| --- | --- | --- |
| Language | Swift 6, strict concurrency `complete` | First-party, one language across iPad, iPhone, and Mac; strong typing suits deterministic rules. |
| Toolchain | Xcode 27.2, the toolchain installed on the build machine; record the exact version and build number in `docs/DECISIONS.md` (ADR-0001) | Reproducible builds. Xcode 27.2 builds the 26.0 deployment targets below. |
| Deployment targets | iOS and iPadOS 26.0, macOS 26.0 | Unlocks Game Center challenges in the Apple Games app, current Pencil APIs, and Metal 4; acceptable reach by launch. |
| App shell and menus | SwiftUI multiplatform app (one app target per platform from one source set) | Native Mac menus, windows, and pointer behavior without Catalyst compromises. |
| 2D rendering (default) | SpriteKit hosted in SwiftUI via `SpriteView` | Mature, built in, enough for every 2D concept; supports custom `SKShader` for effects. |
| 3D rendering | RealityKit via `RealityView` (only where the roadmap says 3D) | Apple's maintained 3D path; SceneKit is not used. |
| Custom GPU work | Metal 4 via MetalKit `MTKView` (only where the roadmap says so, e.g. lighting, ink, or flocking compute) | Performance-critical effects. |
| Audio | AVAudioEngine (music, layered stems, procedural audio) plus `AVAudioPlayerNode` pools for SFX | Low latency and sample-accurate scheduling. |
| Haptics | Core Haptics with AHAP files in `Resources/Haptics/` | Rich, data-driven haptics. |
| Persistence | Codable JSON save files; `FileManager` in Application Support, mirrored to iCloud via `NSUbiquitousKeyValueStore` (small data) and CloudKit private database or iCloud Drive documents (save files) | Simple, debuggable, cross-device. |
| Online and social | GameKit: leaderboards, achievements, challenges, and turn-based matches where the roadmap says so | No custom servers in any roadmap. |
| Project generation | XcodeGen (`project.yml`); the `.xcodeproj` is generated and git-ignored | Agents must never hand-edit `project.pbxproj`. |
| Packages | Swift Package Manager local packages under `Packages/` | Pure-Swift cores are testable on the command line with `swift test`. |
| Tests | Swift Testing (`import Testing`) for packages; XCTest/XCUITest for UI tests; `swift-snapshot-testing` for rendering snapshots | Modern, parallel, parameterized tests. |
| Lint and format | SwiftLint (config in repo) and `swift-format` | Consistent style. |
| CI | GitHub Actions on the latest macOS runner (`macos-latest`), selecting the newest Xcode 27 on the image; see §6 | Every gate is checkable by CI. |
| Monetization (default) | Premium, one price, universal purchase across iPhone, iPad, and Mac; no ads, no consumables | Matches the research; keeps Apple Arcade pitches possible. Pricing is a maintainer decision. |

Universal purchase: iOS and macOS apps share **one bundle identifier**, which the maintainer sets. Every target's `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` derives from one build setting, `GEIST_BUNDLE_ID`, defined only in `Config/Bundle.xcconfig` with the neutral placeholder `com.example.<slug>` (tests append a suffix, for example `$(GEIST_BUNDLE_ID).tests`). GLM never changes that value, never invents a real prefix, and never asks about it. The maintainer fills it in and creates the App Store Connect record.

---

## 3. Repository Layout (Every Game)

> **This repository:** all twenty-five games share one repository, so `<slug>/` below is the game's folder, `games/NN-<slug>/`. "Repository Adaptations" in the root `ROADMAP.md` maps the CI file, branches, tags, and merging, and "Program Loop" there says how GLM moves from one game to the next.

```
<slug>/
├── project.yml                  # XcodeGen spec (iOS app, macOS app, UI test targets)
├── Config/Bundle.xcconfig       # GEIST_BUNDLE_ID placeholder only (§2)
├── Makefile                     # make bootstrap | gen | build | test | lint | snapshot | perf | coverage
├── .swiftlint.yml
├── .swift-format
├── .github/workflows/ci.yml
├── App/
│   ├── Shared/                  # SwiftUI scenes, navigation, settings, shared views
│   ├── iOS/                     # iOS-only entry, Info.plist, entitlements
│   └── macOS/                   # macOS-only entry, menus/commands, Info.plist, entitlements
├── Packages/
│   ├── <Prefix>Core/            # Pure Swift rules engine. NO import of SwiftUI/SpriteKit/UIKit/AppKit/GameKit.
│   ├── <Prefix>Content/         # Content tables (JSON) + typed loaders + validation
│   ├── <Prefix>AI/              # Opponents, solvers, and bots. Depends only on Core and Content.
│   ├── <Prefix>Render/          # SpriteKit/RealityKit/Metal scenes and nodes. Reads Core state, never mutates it directly.
│   ├── <Prefix>Audio/           # AVAudioEngine graph, music system, SFX
│   ├── <Prefix>Platform/        # GameKit, iCloud, Pencil, haptics adapters behind protocols
│   └── <Prefix>Meta/            # Progression, unlocks, daily seeds, stats
├── Resources/
│   ├── Content/                 # *.json tables (source of truth for balance)
│   ├── Art/                     # Asset catalogs, atlases
│   ├── Audio/                   # Stems and SFX (CAF/m4a)
│   ├── Haptics/                 # *.ahap
│   └── Localization/            # String Catalogs (*.xcstrings)
├── Tools/
│   ├── sim/                     # Headless CLI: run N seeded games, AI vs AI, balance reports
│   └── content-lint/            # Validates all JSON against schemas
├── Tests/
│   ├── UITests/                 # XCUITest smoke flows
│   └── Snapshots/               # Reference images
└── docs/
    ├── RULES.md                 # Authoritative rules spec (copied from roadmap §4, then maintained)
    ├── ARCHITECTURE.md
    ├── DECISIONS.md             # ADR log (ADR-0001 …)
    ├── STATUS.md                # Phase/gate tracker with sign-offs
    ├── KNOWN_ISSUES.md
    ├── TODO_MAP.md
    ├── COVERAGE.md
    ├── OPEN_QUESTIONS.md
    ├── PERF.md
    └── HANDOFF.md
```

Each roadmap defines `<Prefix>` (two to four letters, e.g. `CG` for Cartographer's Gambit) and may add game-specific modules **inside** these packages; it never adds new top-level packages unless the roadmap says so.

### 3.1 Dependency Direction (Enforced)

`Core` ← `Content` ← `AI` ← `Meta` ← `Render`/`Audio`/`Platform` ← `App`. `Core` depends on nothing but the Swift standard library and Foundation (`Foundation` only for `Codable`/`Data`; no `Date()` reads, no `UUID()` generation inside rules). A CI script (`Tools/check-imports.sh`) fails the build if `Core`, `Content`, or `AI` import any UI or platform framework.

---

## 4. Coding Standards

### 4.1 Naming
- Types `UpperCamelCase`; functions and properties `lowerCamelCase`; files named after their primary type.
- Rules types are nouns (`Board`, `Move`, `GameState`); rule functions are verbs (`apply(_:)`, `legalMoves(for:)`).
- Content IDs are `snake_case` strings, stable forever once shipped (`nib_fine_point`).
- Test names describe behavior: `@Test("River blocks supply for both factions")`.

### 4.2 Deterministic Rules Engine (Non-Negotiable)
1. `GameState` is a value type (`struct`, `Codable`, `Equatable`, `Hashable`, `Sendable`).
2. All state changes go through one pure reducer: `func apply(_ action: Action, to state: GameState, rng: inout SeededRNG) throws(RuleError) -> (GameState, [Event])`.
3. Randomness uses only `SeededRNG` (Xoshiro256** seeded through SplitMix64), stored in the state or passed explicitly. `SystemRandomNumberGenerator`, `Int.random(in:)` without an explicit generator, `Date()`, and `UUID()` are banned in `Core`, `Content`, and `AI` (SwiftLint custom rule).
4. Rules math uses `Int` or the shared fixed-point type `Fixed` (Q32.32 in `Int64`). `Float`/`Double` are banned in `Core` except in debug-only formatting. Real-time simulations step at a fixed tick (default 30 ticks/second) with integer or fixed-point math, so a replay of the same seed and inputs yields byte-identical state on every device.
5. Every game supports `Replay { seed, contentVersion, actions: [TimedAction] }` and a test that replays it to a known final-state hash.
6. Rendering and audio subscribe to `[Event]` emitted by the reducer; they never infer rules.

### 4.3 General
- No force unwraps outside tests; no `fatalError` in shipping paths except unreachable `switch` defaults with a message.
- Public APIs of packages carry `///` doc comments.
- Functions longer than 60 lines or types longer than 400 lines need a justification comment or a split.
- Every user-facing string goes through String Catalogs; ship English (US) first.
- Accessibility identifiers on every interactive control (`"board.cell.3.4"`), used by UI tests.

### 4.4 Dependency Allow-List
Only: `pointfreeco/swift-snapshot-testing` (tests only), `apple/swift-collections`, `apple/swift-algorithms`, `apple/swift-numerics` (Render/Audio only), XcodeGen, SwiftLint, and swift-format as tools. Nothing else is added (§1.1, item 4).

---

## 5. Testing Requirements

| Layer | Requirement | Gate threshold |
| --- | --- | --- |
| Core (rules) | Unit tests for every rule in `docs/RULES.md` (one or more tests per numbered rule ID, tagged with that ID) | ≥ 90% line coverage |
| Core determinism | Golden replay tests: 20 seeded replays per game with stored final-state hashes; property tests (≥ 1,000 random seeds) for invariants listed in the roadmap | 100% pass |
| Content | `content-lint` validates every JSON file against its schema; referential integrity (no dangling IDs) | 0 errors |
| AI | Unit tests for evaluation functions; headless AI-vs-AI soak (≥ 500 games per difficulty) with no crashes, no illegal moves, and the time budget respected | 0 illegal moves; p95 think time within budget |
| Render | Snapshot tests of key scenes at iPad 13" (iPad Pro 13-inch (M5)), iPad 11" (iPad Pro 11-inch (M5)), iPhone 6.9" (iPhone 18 Pro Max), and Mac 1440×900 in light/dark where relevant | No unreviewed diffs |
| UI | XCUITest smoke: launch → tutorial → play first match/run to completion with scripted inputs → results screen | Pass on iPad and Mac |
| Performance | XCTest `measure` and Instruments signposts; see §7 | Meets §7 |
| Overall | Line coverage across packages | ≥ 60% (Core ≥ 90%, AI ≥ 75%, Meta ≥ 75%) |

Coverage is generated with `xcrun xccov` / `swift test --enable-code-coverage` and summarized into `docs/COVERAGE.md` by `make coverage`.

---

## 6. CI Expectations

> **This repository:** the workflow is `.github/workflows/<slug>.yml` at the repository root, branches are `<slug>/phase/Pn-short-name`, tags are `<slug>/gate-Gn-pass`, and the build agent merges with a normal push after local checks and branch CI pass; see "Repository Adaptations" in the root `ROADMAP.md`.

`.github/workflows/ci.yml` runs on every push and pull request:
1. `make bootstrap` (install XcodeGen, SwiftLint, and swift-format via Homebrew, cached).
2. `make lint` — SwiftLint `--strict` and swift-format lint; zero warnings.
3. `Tools/check-imports.sh` — dependency direction (§3.1).
4. `make content-lint`.
5. `swift test --parallel --enable-code-coverage` for each package in `Packages/`.
6. `make gen && xcodebuild build` for the iOS (iPad simulator) and macOS schemes, warnings as errors.
7. `xcodebuild test` for snapshot and UI tests on one iPad simulator and macOS. Simulators are picked by query (`xcrun simctl list devices available -j`), preferring iPad Pro 13-inch (M5); any installed iOS simulator runtime 26.0 or later is accepted (see "Environment" in the root `ROADMAP.md`).
8. `make sim N=200` — headless seeded AI-vs-AI smoke; fails on any crash, illegal move, or determinism mismatch.
9. Upload coverage summary and sim report as artifacts.

Branching: `main` is always green. GLM works on `<slug>/phase/Pn-short-name` branches, merges to `main` only when the phase's tests pass, and tags `<slug>/gate-Gn-pass` when a gate passes. Commits use Conventional Commits (`feat(core): add river supply rule R-12`).

---

## 7. Performance and Quality Budgets (Default; Roadmaps May Tighten)

| Metric | Target | Device class |
| --- | --- | --- |
| Frame rate (gameplay) | 120 fps sustained on ProMotion, p99 frame time ≤ 8.3 ms | iPad Pro 13-inch (M5) and iPad Pro 11-inch (M5) |
| Frame rate floor | 60 fps sustained, p99 ≤ 16.7 ms | iPad (base) and iPad mini (A20 Pro) |
| Mac | 120 fps on ProMotion displays, 60 fps on others | Any Apple silicon Mac |
| Cold start to interactive main menu | < 2.0 s | iPad (base) |
| Resume a saved game | < 1.0 s | iPad (base) |
| Memory (resident) | < 1.0 GB (2D games), < 1.5 GB (3D games) | iPad (base) |
| App download size | < 300 MB (2D), < 600 MB (3D) | — |
| AI think time | Per roadmap; default p95 < 1.5 s on iPad (base) | — |
| Thermal | No `serious` thermal state within 30 minutes of play | iPad (base) |
| Crash-free sessions (beta) | ≥ 99.5% | TestFlight |

Measure with Instruments (Time Profiler, Game Performance template, and Metal System Trace) and record results in `docs/PERF.md` with device, OS, build, and date.

---

## 8. The Shared Phase and Gate Model

Every roadmap uses these eleven phases. Standard tasks (`S` prefix) apply to every game; roadmaps add game-specific tasks with the game prefix (e.g. `CG-P1.3`).

| Phase | Name | Owner | Gate | Sign-off |
| --- | --- | --- | --- | --- |
| P0 | Setup | GLM | G0 | GLM-SELF |
| P1 | Rules Engine Prototype | GLM | G1 | GLM-SELF |
| P2 | Core Loop Vertical Slice | GLM | G2 | GLM-SELF |
| P3 | Content and Systems | GLM | G3 | GLM-SELF |
| P4 | AI Opponents | GLM | G4 | GLM-SELF |
| P5 | Meta and Replayability | GLM | G5 | GLM-SELF |
| P6 | Aesthetics and Audio Pass | GLM | G6 | GLM-SELF |
| P7 | Platform Features (Pencil, Game Center, iCloud, Mac) | GLM | G7 | GLM-SELF |
| P8 | Polish, Accessibility, and Performance | GLM | G8 | GLM-SELF |
| P9 | Beta and TestFlight | GLM | G9 | GLM-SELF |
| P10 | Release Prep | GLM | G10 | GLM-SELF |

GLM may build **placeholder** art, audio, and Pencil/Game Center stubs earlier when a slice needs them, and replaces them in P6 and P7.

### 8.1 Standard Tasks

**P0 Setup**
- S0.1 Create the repo layout in §3 with `project.yml`, `Makefile`, lint configs, and empty packages that compile.
- S0.2 Implement `SeededRNG` (Xoshiro256**/SplitMix64) and `Fixed` (Q32.32) in `<Prefix>Core/Foundation/` with tests (known-answer vectors).
- S0.3 Add `Tools/check-imports.sh`, SwiftLint custom rules for banned APIs (§4.2), and `content-lint` skeleton.
- S0.4 Add CI workflow (§6); it must be green on an empty app that launches to a placeholder menu on iPad and Mac.
- S0.5 Create all `docs/` files with headings; copy roadmap §4 into `docs/RULES.md` with rule IDs intact; write ADR-0001 (toolchain) and ADR-0002 (stack per §2).
- S0.6 Add `Replay` type and a golden-replay test harness (initially with a trivial state).
- S0.7 Add an in-app debug overlay (FPS, tick, seed, state hash) toggled by a three-finger double tap on iPad and ⌘⇧D on Mac.

**G0 checks (GLM-SELF):** CI green; `make test` passes; app launches on iPad simulator and macOS; banned-API lint triggers on a deliberate violation in a test fixture; docs skeleton present.

**P1 Rules Engine Prototype**
- S1.1 Implement the full `GameState`, `Action`, `Event`, and reducer for the rules in roadmap §4 (no UI).
- S1.2 One or more tests per rule ID; property tests for the roadmap's invariants.
- S1.3 Headless CLI `Tools/sim` that plays random-legal-move games from a seed and prints a summary and final hash.
- S1.4 Ten golden replays committed.

**G1 checks (GLM-SELF):** every rule ID has a passing test; Core coverage ≥ 90%; `make sim N=1000` completes with 0 crashes, 0 illegal states, and identical hashes on two runs; no banned APIs.

**P2 Core Loop Vertical Slice**
- S2.1 One playable mode on iPad and Mac with placeholder art in the intended palette, the primary touch interaction from the roadmap, and a mouse equivalent.
- S2.2 Basic HUD, pause, restart, and results screen.
- S2.3 One basic opponent or challenge source (simple heuristic AI or scripted scenario).
- S2.4 Save and resume mid-game (local only).
- S2.5 Build a 60-second screen recording via XCUITest + `simctl io recordVideo`, saved to `docs/media/slice.mp4`.

**G2 checks:** XCUITest plays a full match/run to the results screen on iPad and Mac; 60 fps on iPad simulator debug overlay (real-device perf comes later); the roadmap's slice-specific checks. Then GLM writes `docs/SLICE_ASSESSMENT.md`: an honest self-assessment of the slice against the roadmap's pillars (§1), using the recording and screenshots, and turns every weakness it finds into a P3 task. The maintainer may review the slice on their own; that never blocks P3.

**P3 Content and Systems** — roadmap-specific content to the counts in §5 of each roadmap; all content in JSON; `content-lint` clean; tutorial flow scripted.

**P4 AI Opponents** — difficulty tiers per roadmap §7; time budgets enforced; AI-vs-AI soak; win-rate bands recorded in `docs/BALANCE.md`.

**P5 Meta and Replayability** — run structure, unlocks, daily seed (date-derived, UTC, deterministic), statistics, and local leaderboards ready to bind to Game Center in P7.

**G5 checks:** roadmap-specific; plus all standard tests, coverage thresholds in §5, and an up-to-date `docs/HANDOFF.md` (§9).

**P6 Aesthetics and Audio Pass** — final art direction, shaders, animation, music, SFX, and haptics per roadmap §1 aesthetic spec.

**P7 Platform Features** — Pencil (hover preview, squeeze palette, pressure where specified, always with a finger fallback), Game Center (auth, leaderboards, achievements, challenges, turn-based where specified), iCloud save sync with conflict resolution, Mac menus/keyboard shortcuts/window resizing, controller support where specified.

**P8 Polish, Accessibility, and Performance** — VoiceOver labels, Dynamic Type in menus, Reduce Motion, color-blind-safe palettes (verify with simulated deuteranopia/protanopia/tritanopia), adjustable text size, left-handed layout, haptics toggle, and performance budgets in §7 on real devices.

**P9 Beta and TestFlight** — GLM prepares everything for a beta: a Release archive that builds with signing disabled (`CODE_SIGNING_ALLOWED=NO`), beta notes, a tester guide, and the telemetry-free, in-game, opt-in stats export; runs long simulator soak sessions (scripted UI tests and `Tools/sim`) as the local substitute for beta crash data; and drives balance passes from sim data. Uploading to TestFlight and running internal or external groups are maintainer items (§1.1). Feedback the maintainer records in issues is triaged into tasks.

**P10 Release Prep** — App Store metadata drafts, screenshots for all sizes (generated by UI tests on simulators), an app preview video (`simctl io recordVideo`), the privacy nutrition label (target: Data Not Collected), an age rating questionnaire draft, accessibility nutrition labels, and a press kit, all in `docs/release/`. Signing, App Store Connect, pricing, and submission are maintainer items (§1.1); GLM files one item listing everything ready and what is left.

### 8.2 Local Substitutes for Owner-Only Steps

The build machine is a Mac with Xcode and simulators only. Where a task or gate check needs more, GLM does the substitute, records the check as `SUBSTITUTED` with its evidence, and files one maintainer item for what is left (§1.1). Any gate check that names real devices, a specific iPad or iPhone model, TestFlight, testers, a survey, sandbox accounts, a playtest, or an approval is such a check; so is any task that needs TestFlight, App Store Connect, signing, real devices, or outside testers, or that the roadmap marks as a maintainer item. A `SUBSTITUTED` check counts as passed for tagging.

| Owner-only step | What GLM does locally | Left for the maintainer |
| --- | --- | --- |
| Real-device performance, memory, thermal, and download size (§7) | Measure on the iPad and iPhone simulators and on the Mac with Instruments or `xctrace`; record results in `docs/PERF.md`, marked "simulator" or "Mac"; budgets apply to the simulator figures as a proxy | A device run against §7 |
| Human playtest, feel, or approval (including "approved" assets or snapshots) | Scripted UI-test playthroughs, sim and bot metrics, screenshots and recordings in `docs/media/`, and a self-assessment against the pillars; GLM approves reference snapshots itself | A playtest |
| Apple Pencil hardware (pressure, squeeze, hover) | Code paths behind protocols with tests on the input model, plus the finger and pointer fallbacks working on the simulator | A device check |
| Game Center, iCloud, and CloudKit sandbox | Real GameKit and CloudKit code compiled, exercised through protocol fakes with tests; entitlements with placeholder identifiers | Sandbox verification |
| Signing and archiving | `xcodebuild archive` with `CODE_SIGNING_ALLOWED=NO` | Signing with real certificates |
| TestFlight and beta crash-free rate | Simulator soak sessions with crash counts | Upload and beta groups |
| App Store Connect, pricing, and submission | Everything in P10, in `docs/release/` | The record, pricing, and submission |
| Cultural advisor sign-off (`_SET2_ADDENDUM.md` §4) | The sourcing review packet, draft advisor brief, and every culturally specific item kept marked pending advisor review in `cultural_manifest.json` and in debug builds | Engaging, crediting, and paying advisors; recording their decisions |

---

## 9. Handoff Package (Kept Current at Every Gate)

`docs/HANDOFF.md` must contain, in this order:
1. **State summary** — phase, last passed gate, branch, commit SHA, and tag.
2. **How to build and run** — exact commands from a clean clone.
3. **Architecture** — link to `docs/ARCHITECTURE.md` (module diagram, data flow from input → Action → reducer → Events → render/audio, threading model, save format).
4. **Decision log** — link to `docs/DECISIONS.md`; every deviation from the roadmap is an ADR.
5. **Known issues** — `docs/KNOWN_ISSUES.md`, each with severity (S1 crash/data loss, S2 wrong rule, S3 visual/UX, S4 minor), reproduction steps, and a suspected cause.
6. **TODO map** — `docs/TODO_MAP.md`, generated by `make todo` from `// TODO(<ID>):` comments, grouped by package; every TODO carries a task ID.
7. **Test coverage report** — `docs/COVERAGE.md` per package with uncovered critical functions listed.
8. **Balance snapshot** — `docs/BALANCE.md` with sim results (win rates by faction/difficulty, average game length, and outliers).
9. **Open questions** — `docs/OPEN_QUESTIONS.md` with the default GLM chose (if any) and why.
10. **Gate evidence** — check-by-check pass/fail table with command output excerpts and media links.

---

## 10. Effort Units

Estimates in roadmaps use **engineer-days (ed)**: one focused experienced Swift engineer day. Agent wall-clock varies; treat ed as relative sizing. Each roadmap gives a per-phase range and a total.

---

## 11. Writing Style for Docs

Title Case headings, American English, and the serial (Oxford) comma in every list of three or more.


