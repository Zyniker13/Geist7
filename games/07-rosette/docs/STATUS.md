# Rosette — Phase & Gate Status

## Current State
- **Current Phase:** P1 (Core Rules) — RS-P1.4 complete; G1 gate evidence next
- **Next Step:** Run the G1 gate block (make test/lint, INV-1–INV-5 evidence, tag, merge to main), then P2 UI Shell
- **Last Update:** 2026-11-16

## Phase Queue
| Phase | Status | Last Updated |
| --- | --- | --- |
| P0 Setup | ✅ Complete | 2026-11-16 |
| P1 Core Rules | 🔄 In Progress | 2026-11-16 |
| P2 UI Shell | ⏳ Pending | — |
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
| G1 | ⏳ Pending | — |
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
