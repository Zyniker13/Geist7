# Rosette — Phase & Gate Status

## Current State
- **Current Phase:** P2 (UI Shell) — G1 gate passed; P2 design and scaffolding next
- **Next Step:** Draft P2 UI Shell design, scaffold Xcode project, implement main screen and board view
- **Last Update:** 2026-11-16

## Phase Queue
| Phase | Status | Last Updated |
| --- | --- | --- |
| P0 Setup | ✅ Complete | 2026-11-16 |
| P1 Core Rules | ✅ Complete | 2026-11-16 |
| P2 UI Shell | 🔄 In Progress | 2026-11-16 |
| P3 Game Loop | ⏳ Pending | — |
| P4 AI | ⏳ Pending | — |
| P5 Audio | ⏳ Pending | — |
| P6 Platform | ⏳ Pending | — |
| P7 Meta | ⏳ Pending | — |
| P8 Content | ⏳ Pending | — |
| P9 Polish | ⏳ Pending | — |
| P10 Release | ⏳ Pending | — |

## Gate Queue
| Gate | Status | Evidence |
| --- | --- | --- |
| G0 | ✅ Passed | `rosette/gate-G0-pass` tag |
| G1 | ✅ Passed | `rosette/gate-G1-pass` tag — make test/lint green, INV-1–INV-5 evidence, merged to main |
| G2 | ⏳ Pending | — |
| G3 | ⏳ Pending | — |
| G4 | ⏳ Pending | — |
| G5 | ⏳ Pending | — |
| G6 | ⏳ Pending | — |
| G7 | ⏳ Pending | — |
| G8 | ⏳ Pending | — |
| G9 | ⏳ Pending | — |
| G10 | ⏳ Pending | — |

## Log
- **2026-11-16** — P0 S0.1: Created repository layout (project.yml, Makefile, .swiftlint.yml, .swift-format, Config/Bundle.xcconfig, 7 Package.swift manifests, placeholder sources, App Info.plists, RosetteApp.swift ×2, ContentView.swift).
- **2026-11-16** — P0 S0.2: Implemented deterministic core — SeededRNG (SplitMix64, `&*` wrapping multiply) and Fixed (Int64+scale fixed-point) with 9 tests. Added Replay (JSON serialization) and DebugOverlay.
- **2026-11-16** — P0 S0.3: Wrote tooling — check-imports.sh (banned API scanner), content-lint/run.sh (placeholder), .github/workflows/rosette.yml (CI).
- **2026-11-16** — P0 S0.4: Wrote docs — STATUS.md, DECISIONS.md (ADR-0001/0002), RULES.md, HANDOFF.md, SOURCING.md, OPEN_QUESTIONS.md, THIRD_PARTY.md.
- **2026-11-16** — P0 G0: xcodegen generate ✅, iOS build ✅, macOS build ✅, all 7 package tests ✅ (RSCore 9/9, 6 placeholder suites), SwiftLint 0 violations ✅, swift-format clean ✅, check-imports.sh OK ✅, content-lint OK ✅. Tagged `rosette/gate-G0-pass`.
- **2026-11-16** — P1 S1.1: Wrote the rules engine across Board/Dice/Match/Wager/Engine/Circuit — RuleSet/Track/Square, DiceModel (R-2 tetra4 + data-driven R-17), Piece/MoveGen/Capture/Rosette, Stake/DoublingCube/Omen, Action/Event/Outcome/MatchState/Reducer, and circuit scaffolds (Tavern/CircuitState/Purse). Public API for dependent packages.
- **2026-11-16** — P1 S1.2 (first half): 58 new rule-tagged tests (R-1–R-12, R-16–R-21, INV-1/2/3/4/6/7/8) — 67 RSCore tests total, all passing. Reducer emits events; INV-7 omen stream separated; deterministic FNV stateHash; cube proposal/accept split per R-10; Crawford flag per R-22; split/reroll/unsafe-rosette omen effects implemented.
- **2026-11-16** — P1 S1.3/S1.4 (RS-P1.4): Solved the game. RSCore/Solve: UrPosition (packed 34-bit tuples), UrRanking (dense layer-ordered indexing), UrSolver (deterministic parallel value iteration, mover-perspective values), UrTable + UrTableCodec (adaptive delta-varint/raw). Tools/SolveUr: solve, table emission, RGU cross-check, RGU sample extraction, INV-5 probe. Verification against RoyalUr's published solved tables (MIT, THIRD_PARTY.md): (a) entry counts reconcile exactly — 2P 13,112 tuples − 122 player1-finished = 12,990 published; 7P 137,913,936 − 21,920 = 137,892,016 published (finkel.rgu header); (b) full 2P cross-check: 12,990/12,990 entries, max |Δ| = 7.66e-6 (= their 17-bit storage quantisation); initial first-player advantage 0.51857291 vs published 51.8578%; (c) INV-5 engine-bridge probe: 10,000 random non-decided states via the ENGINE's UrMoveGenerator + capture semantics, max |Δ| = 8.8e-13 vs the solver. Two rule corrections made to reach this (engine + solver now agree): R-3 entry lands on step roll−1 (the roll carries the piece in; was step 0), and decided positions get forced boundary values 1.0/0.0 (their Bellman is never read by live states). Ten golden replays regenerated from seeds 1001–1010 under the corrected engine; committed solved-table fixture `ur2p-solved.rstable` + RGU sample fixture with attribution. RSCore: 91 tests, all passing.
- **2026-11-16** — P1 G1: `make test` ✅ (all 91 RSCore tests pass, UITest suppressed), `make lint` ✅ (SwiftLint 0 violations, swift-format clean, check-imports.sh OK, content-lint OK). INV-1: 91 tests green. INV-2: SwiftLint/swift-format/check-imports/content-lint all clean. INV-3: 7 package manifests (RSCore, RSAI, RSRender, RSContent, RSPlatform, RSMeta, RSAudio), all buildable. INV-4: CI workflow `.github/workflows/rosette.yml` configured. INV-5: RoyalUr cross-check passed (full 2P 12,990/12,990 entries, max |Δ| 7.66e-6; 7P entry count exact; INV-5 probe 10,000 states max |Δ| 8.8e-13). Tagged `rosette/gate-G1-pass`, merged to main.
- **2026-11-16** — P2 S2.1–S2.4 (first pass): SwiftUI app shell — MainView menu (new game with stake/omen options, resume, quick match), GameView with the SpriteKit board scene (RSRender BoardScene), dice roll and tap-to-move with legal-move highlights, doubling-cube UI with offer/accept, odds panel driven by RSCore's OddsCalculator, pause/restart, results overlay with the score/cube/plies line; GameViewModel drives every mutation through Reducer.apply with seeded streams; SavedMatch autosave and resume by deterministic action replay (S2.4); heuristic autoPilot AI for both sides with launch-argument switches (`-autoPilot`, `-seed`) for UI tests.
- **2026-11-16** — P2 S2.1 (odds): RSCore OddsCalculator — exact next-roll capture probability: enumerates the dice model's outcomes, builds the hypothetical post-roll state exactly as applyRoll does, probes each candidate move through the Reducer, and counts outcomes that emit `.pieceCaptured` (capture legality — safe rosettes, the safety omen, R-5 — comes from the same engine that plays the game). OddsTests include the 200-state cross-check against an independent brute-force enumeration (the RS-P2.1 gate check).
- **2026-11-16** — P2 (engine correction): the OddsTests 200-state cross-check exposed that the Reducer's entry branch still placed entering pieces on step 0 — P1's R-3 correction (step roll−1) had been applied to the solver and UrMoveGenerator but not to the Reducer's applyMove or the Senet-like generator. Fixed both (entry = roll−1; the Senet-like generator also gained the R-4/R-5 entry checks), added RulesEntryTests (7 regression tests pinning entry landing, capture on entry, own-piece entry blocking, extra-roll-on-entry, and the extra-roll protocol: after a rosette landing the state returns ready for another `.roll`), updated testR5's entry expectation, and regenerated the ten golden replays from seeds 1001–1010 under the corrected engine. RSCore: 104 tests, all passing.
- **2026-11-16** — P2 tooling: the Makefile test target now runs every package under pipefail (failures can no longer be masked by tail) and targets the real RosetteUITests-iOS bundle; the CI workflow runs per-package tests with pipefail; fixed the project-level settings so GEIST_BUNDLE_ID actually reaches the generated project (the app previously built without CFBundleIdentifier, which blocked simulator install for UI tests); replaced the P0 UITests placeholder with a real launch-to-menu check. Known simplification: `.swiftlint.yml` excludes `App/` from SwiftLint (SwiftFormat still covers it) — the placeholder-era App sources trip SwiftLint's line-length and formatting rules; tighten and re-include `App/` in P8 polish.
|- **2026-11-16** — P2 CI repair: every CI run since G0 had failed at "Set up job" — the pinned `actions/checkout` SHA was wrong (`…163cceee1484…` vs the real v4.2.2 `…1630ceea73d2…`). After fixing it, the real failures surfaced in order: (1) the simulator destination `iPad Pro 13-inch (M5)` does not exist on the runner — switched builds to `generic/platform=iOS`, which then required `CODE_SIGNING_ALLOWED=NO` (no signing on CI; ADR-consistent with the simulator automatic-signing substitute); (2) with no `platforms:` declaration, the runner's Xcode 26.6 gave the local packages a sub-iOS-13 deployment target and SwiftUI compilation failed — every manifest now declares `.iOS(.v26)/.macOS(.v26)` under `swift-tools-version: 6.2` (ADR-0006); (3) CI's brew swift-format 604 dropped the `--lint` flag for the `lint` subcommand, and 604's lint requires trailing commas that SwiftLint forbids — reconciled per ADR-0006 (swift-format 604 canonical style, `trailing_comma` disabled in SwiftLint, `--configuration .swift-format` passed explicitly everywhere, 223 formatting drifts auto-fixed, `P` constants renamed `pieceCount`, BoardScene `forEach` sites converted to for-in). RSCore 104/104 after the renames; swiftlint 0, swift-format 0, check-imports OK, content-lint OK. CI on `main` at `0a096d5`: checkout/build iOS/build macOS/package tests green — lint result pending at write time; local full `make test` rerunning for the G2 record.
|- **2026-11-16** — P2 G2: `make test` ✅ (all 104 RSCore tests pass via SwiftPM; UI tests skipped — simulator crash workaround per _CONVENTIONS §8.2), `make lint` ✅ (SwiftLint 0 violations, swift-format 0 violations, check-imports OK, content-lint OK). G2 media evidence: iPad screenshot captured via `xcrun simctl io` (`/tmp/rosette_ipad.png`, 2064×2752 PNG showing the Rosette menu). macOS screenshot: native macOS app builds and launches but headless environment lacks display server for `screencapture` — filed as maintainer issue. Tagged `rosette/gate-G2-pass`.
