# Mattang — Phase & Gate Status

## Current State

- **Phase:** P0 complete → G0 signed off. Starting P1 (Rules Engine Prototype) next.
- **Branch:** merged to `main` (61830b9) after local `make test` + `make lint` green. Tag `mattang/gate-G0-pass` pushed once main CI is green. (Game CI workflows trigger on `main` pushes only — the issues-only token cannot open PRs, so branch CI runs as main CI post-merge, matching the Rosette precedent.)
- **Blocked on:** nothing.

## Phase Queue

| Phase | State | Notes |
| --- | --- | --- |
| P0 Setup | **complete** | S0.1–S0.7, SRC0.1/0.2, HIST0.1 done; G0 signed off 2026-11-20 |
| P1 Rules Engine Prototype | next | Tracer (R-3..R-6, R-12..R-14), turns (R-7..R-11), INV-1..5 |
| P2 Core Loop Vertical Slice | pending | Sea scene, preview, Sailor AI; SRC2.x |
| P3 Content and Systems | pending | G3 charts, voyages, tutorial, About (SRC3.1) |
| P4 AI Opponents | pending | Four tiers, puzzle miner, BALANCE.md |
| P5 Meta and Replayability | pending | G5 counts, daily, stats, review packet, HANDOFF |
| P6 Aesthetics and Audio | pending | Metal field, advisor review (SRC6.x) |
| P7 Platform Features | pending | Game Center, async, Pencil hover, Mac keyboard |
| P8 Polish, Accessibility, Performance | pending | VoiceOver, Reduce Motion, budgets |
| P9 Beta / P10 Release Prep | pending | Community playtest (SRC9.1), credits (SRC10.1) |

## Gate Queue

| Gate | State | Evidence |
| --- | --- | --- |
| G0 Setup | **pass** (2026-11-20) | evidence block below |
| G1 Rules Engine | pending | — |

## G0 Evidence (2026-11-20)

### Toolchain

```
$ xcodebuild -version && xcodegen --version && swiftlint version && swift-format version
Xcode 27.2
Build version 27B52
Version: 2.46.0      (xcodegen)
0.65.1               (swiftlint)
0.65.1               (swift-format)
```

### GATE checks

- **S0.1 Packages scaffold** — 7 packages under `Packages/` (MTCore, MTContent, MTAI, MTRender, MTAudio, MTMeta, MTPlatform), each with Package.swift + at least one source file; MTCore has real implementations + tests. Done.
- **S0.2 Makefile + lint configs** — `Makefile` with build-mac / test-mac / lint targets; `.swiftlint.yml` (incl. `banned_api` custom rule), `.swift-format`, `Config/Bundle.xcconfig`. Done.
- **S0.3 MTCore core types + tests** — Fixed (Q32.32), SeededRNG (SplitMix64), Hex (axial, R-12), InteractionTable (6×6), Replay/StateHashing (FNV-1a64). Done.
- **S0.4 App launches on iPad + Mac** —
  - iPad sim `zGeist7_bot-iPad-Pro-13`: app launched with `-debugOverlay -seed 42`; screenshot verified (`mattang-ipad-p0.png`): title "Mattang", subtitle, debug overlay `fps 60, tick 0, seed 42, hash 0x4CC4591B26F3AE57`. PASS.
  - macOS: app window confirmed onscreen via CGWindowList (win# 139, layer 0) with overlay enabled. `screencapture` is TCC-blocked on this machine (same limitation as rosette issue #4) → **SUBSTITUTED**: CGWindowList window check + iPad screenshot as visual evidence.
- **S0.5 Content resources + cultural manifest** — 8 JSON stubs under `MTContent/Resources/Content/`; `cultural_manifest.json` with 4 entries, all `status: "pending"`; glossary 9 terms. Verified by content-lint. Done.
- **S0.6 Replay/state-hash utility** — FNV-1a64 over sorted-keys JSON; golden vectors `""`→`0xcbf29ce484222325`, `"a"`→`0xaf63dc4c8601ec8c`, `"foobar"`→`0x85944171f73967e8`; TrivialState golden `0x9D3B73F0768E6046`; Replay JSON round-trip + golden harness tests pass. Done.
- **S0.7 Debug overlay** — fps (CVDisplayLink/CADisplayLink), tick, seed, state hash; three-finger double tap (iOS) / ⌘⇧D (macOS) / `-debugOverlay` launch arg; verified in both apps' screenshots/window checks. Done.
- **SRC0.1 Sourcing packet** — `docs/SOURCING.md`, 8 sections, FULL tier, no-teaching-navigation stance (AboutText constant, unit-tested). Done.
- **SRC0.2 Cultural manifest** — content-lint verifies manifest entries vs. referenced asset IDs, negative fixture proves it can fail. Done.
- **HIST0.1 History doc** — `docs/HISTORY.md` with Attested/Reconstructed/Invented tiers. Done.
- **Advisor review requested** — issue #12 (`mattang: cultural advisor review of Marshallese content (G0 request)`, label `needs-maintainer`). Filed 2026-11-20.

### Test runs (real output)

```
# Packages/MTCore — swift test
Executed 38 tests, with 0 failures (0 unexpected) in 0.005 (0.007) seconds

# macOS make test-mac (unit bundle) — proc run 2026-11-20
Executed 7 tests, with 0 failures (0 unexpected)   [App unit: LaunchArguments 5 + AppSmoke 2]

# iOS make test (sim-lock, zGeist7_bot-iPad-Pro-13) — 2026-11-20 11:20
Test Suite 'MattangUITests-iOS.xctest' passed ... Executed 2 tests, with 0 failures (0 unexpected) in 252.995 (253.002) seconds
** TEST SUCCEEDED **

# macOS UI tests — NOT RUNNABLE on this machine
"Timed out while enabling automation mode" (same machine limitation as rosette issue #8)
→ SUBSTITUTED: iOS UI tests cover the same placeholder-launch + overlay assertions;
  macOS window verified via CGWindowList (above).
```

### Lint (all fresh at sign-off)

```
$ swiftlint lint --strict        → Done linting! Found 0 violations, 0 serious in 40 files.
$ swift-format lint …            → (clean, no output)
$ Tools/check-imports.sh         → check-imports.sh: OK
$ Tools/content-lint/run.sh      → content-lint: OK (10 manifest entries, 9 glossary terms, 0 charts)
```

### Bugs found & fixed by tests in P0 (regression-tested)

- Fixed multiply/divide negative-operand sign handling (magnitude, not bitPattern).
- Hex cube-distance off-by-one in a test constant (expected value corrected after recomputation).

### Sign-off

- All GATE checks pass or are SUBSTITUTED with justification above (§8.2 substitutes).
- **G0 PASS — 2026-11-20.** Tag: `mattang/gate-G0-pass`.

## Open Maintainer Items

- Issue #12 `mattang: cultural advisor review of Marshallese content (G0 request)` — advisor review is a release gate (G10), not a build gate; manifest entries stay `pending` until answered.
- Revenue share (roadmap §13.2) — to be filed with the advisor item at P6; default none set.

## Toolchain (ADR-0001 evidence)

- Xcode 27.2 (Build 27B52) — see G0 evidence block.
- iOS Simulator devices used by this game are prefixed `zGeist7_bot-` (never shared).

## Log

- 2026-11-20 — P0 started on `mattang/phase/P0-setup`. Scaffold, packages, tests written; two real bugs found and fixed by tests (Fixed multiply/divide sign handling; see DECISIONS ADR-0004 rationale); 38/38 green.
- 2026-11-20 — S0.4 verified on iPad sim (screenshot) + macOS (CGWindowList); UI-test fix (`starts(withText:)` → NSPredicate); lint suite clean; `make test` green on iOS (2 UI tests) and macOS unit (7 tests). Mac UI tests SUBSTITUTED (automation-mode timeout, issue #8 precedent). Advisor issue #12 filed. **G0 signed off.**
