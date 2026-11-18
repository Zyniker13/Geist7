# Program Status

Program: Geist7, Set Two (twenty-five games). See [`ROADMAP.md`](ROADMAP.md) for the build order and the Program Loop.

## Current

- **Game in progress:** 07 Rosette — P6 (Aesthetics and Audio Pass) in progress: RS-P6.1 board art per region + tavern backdrops done (ADR-0013), RS-P6.2 music/SFX done (RSAudio 24/24), HIST6.1 fact-check done (two unhedged UI claims fixed); snapshot review fixing rendering bugs (board sizing, invisible pieces, autoPilot launch, HUD scrim).
- **Next step:** finish G6 snapshot approval (vision model was briefly down on the provider side; retrying), full `make test`/`make lint`, tag `rosette/gate-G6-pass`, merge to main, begin P7 (Platform Features).

## Environment Check

Do this once, before the first game's P0, and record the output here:

- `xcodebuild -version` must report Xcode 27.2 (`_CONVENTIONS.md` §2).
- `xcrun simctl list runtimes` must show an available iOS simulator runtime of version 26.0 or later.
- `xcrun simctl list devices available` must include the simulators named in "Environment" in `ROADMAP.md`, or the closest models created or picked as that section says.
- `swift --version`, `brew --version`, `xcodegen --version`, `swiftlint version`, and `swift-format --version`; install missing tools with `brew install`.
- `gh auth status`: if it fails, file maintainer items with the fallback in "Issues for the Maintainer" in `ROADMAP.md`.
- The issue labels exist: `gh label list --repo Zyniker13/Geist7` shows `needs-maintainer`, `blocked`, `question`, `program`, and one label per game slug. Create any that are missing with `gh label create`.

If Xcode 27.2 or an iOS 26-or-later runtime is missing and cannot be installed without an administrator, file it as a `program` maintainer item; no game can build until it is fixed.

- `xcodebuild -version`: Xcode 27.2, Build 27B52 ✓
- `xcrun simctl list runtimes`: iOS 27.2 (27.2 - 24B8117) ✓
- `xcrun simctl list devices available`: iPad Pro 13-inch (M5) ✓, iPad Pro 11-inch (M5) ✓, iPad (A16) ✓, iPad mini (A20 Pro) ✓, iPhone 18 Pro Max ✓
- `swift --version`: 6.4.2 ✓
- `brew --version`: 7.0.13 ✓
- `xcodegen --version`: 2.46.0 ✓
- `swiftlint version`: 0.65.1 ✓
- `swift-format --version`: 604.0.0 ✓
- `gh auth status`: authenticated via `GH_TOKEN` from `~/.hermes/profiles/geist7/gh-token` (token added by the maintainer 2026-11-17; `gh auth status` says logged in to Zyniker13 when run with the variable). Maintainer items now file directly as GitHub issues.
- `gh label list`: verified 2026-11-17 — all required labels exist (`needs-maintainer`, `blocked`, `question`, `program`, and all 25 game slugs).

## Games

| Order | No. | Game | State | Last Gate | Open Maintainer Issues |
| --- | --- | --- | --- | --- | --- |
| 1 | 07 | Rosette | P6 in progress (G5 passed) | G5 | #4 |
| 2 | 06 | Mattang | Not Started | — | — |
| 3 | 04 | Dry Garden | Not Started | — | — |
| 4 | 24 | Patang | Not Started | — | — |
| 5 | 01 | Ebru | Not Started | — | — |
| 6 | 11 | Vienna Method | Not Started | — | — |
| 7 | 23 | Stratum | Not Started | — | — |
| 8 | 03 | Seedfall | Not Started | — | — |
| 9 | 17 | Precinct | Not Started | — | — |
| 10 | 15 | The Long Cloth | Not Started | — | — |
| 11 | 09 | Rova | Not Started | — | — |
| 12 | 18 | Hanmoto | Not Started | — | — |
| 13 | 22 | Backburn | Not Started | — | — |
| 14 | 12 | Girih | Not Started | — | — |
| 15 | 19 | Mandate of Heaven | Not Started | — | — |
| 16 | 13 | The Glaziers' Guild | Not Started | — | — |
| 17 | 08 | Turncoat | Not Started | — | — |
| 18 | 14 | Carceri | Not Started | — | — |
| 19 | 02 | Eight Suits | Not Started | — | — |
| 20 | 21 | Congress | Not Started | — | — |
| 21 | 20 | The Sum of Small Wars | Not Started | — | — |
| 22 | 05 | Watered Stock | Not Started | — | — |
| 23 | 10 | The Long Drought | Not Started | — | — |
| 24 | 25 | Delta-v | Not Started | — | — |
| 25 | 16 | Khipu | Not Started | — | — |

## Needs the Maintainer

Fallback only, when `gh` is not authenticated (`ROADMAP.md`, "Issues for the Maintainer"). One bullet per item: labels in brackets, then the title, then the body.

- (none)

## Log

- 2026-11-15: Roadmap set written; no code yet.
- 2026-11-16: Added `AGENTS.md`, `LICENSE` (all rights reserved), `SECURITY.md`, `.gitignore`, the Environment Check, and the issue labels; the program is ready to start.
- 2026-11-16: 07 Rosette P0 complete — 48 files committed, iOS+macOS build green, all 7 package tests pass, SwiftLint/swift-format/check-imports clean, CI configured, G0 tagged.
- 2026-11-16: 07 Rosette P1 complete on branch `rosette/phase/P1-rules-engine` — rules engine R-1–R-12/R-16–R-23 with rule-tagged tests, headless sim CLI + ten golden replays, pluggable move generators (Senet-like/Patolli-like), and RS-P1.4: value-iteration solver + ranking + table codec, verified against RoyalUr's published solved tables (full 2P cross-check max |Δ| 7.66e-6 on all 12,990 entries; 7P entry count reconciles exactly; INV-5 engine-bridge probe 10,000 states max |Δ| 8.8e-13). RSCore: 91 tests green. Two rule corrections during the solve: R-3 entry lands on step roll−1; decided positions carry forced boundary values.
- 2026-11-16: 07 Rosette G1 gate passed — `make test` + `make lint` green, INV-1–INV-5 evidence recorded, tag `rosette/gate-G1-pass` pushed. Merged to main.
- 2026-11-16: 07 Rosette G2 gate passed — `make test` (104 RSCore tests) + `make lint` green, iPad screenshot captured, UI tests skipped per _CONVENTIONS §8.2, tag `rosette/gate-G2-pass` pushed. Proceeding to P3.
- 2026-11-16: 07 Rosette P3 in progress — RSCore Def types (TavernDef, OpponentDef, OmenDef, RulesetDef) moved to RSCore, RSContent ContentLoader written, 6 JSON content files committed, build green, 104 tests pass.
- 2026-11-17: gh token added by the maintainer — maintainer items now file as GitHub issues directly. Filed #4 (rosette: macOS screenshot needs a display server; the G2 log claimed it filed but it was not). Closed #3 (rosette CI Set up job) after runs 43943449329/43943537985/43999403187 all went green on main.
- 2026-11-17: 07 Rosette P3 complete — content systems (single canonical content location; 6 rulesets / 12 taverns / 12 opponents / 6 omens / 4 fortunes / 3 lessons), circuit match engine (BotMatch, Fortune, dice model, tavern progression), UI (CircuitView, HistoryView, TutorialView), docs (HISTORY, SLICE_ASSESSMENT). G3 gate passed: `make test` (139 tests: RSContent 11, RSCore 126, RSRender 2; 0 failures) + `make lint` green; 1,000 bot circuit runs without softlocks; every tavern reachable; HISTORY/labels agreement. Tag `rosette/gate-G3-pass` pushed. Proceeding to P4.
- 2026-11-18: 07 Rosette P4 (AI) in progress on branch `rosette/phase/P4-ai` — MatchBot abstraction with OptimalBot (budgeted expectiminimax, ADR-0010), NaiveBot, TableBot, VariantBot; RSAI package with 44 tests. Two cube-validity bugs found via instrumented mirrors and fixed with red/green regression tests: R-21 second-double-in-one-turn (`hasDoubledThisTurn` guard) and R-10 offer-by-non-owner (`notOwner` — the earlier crash at plies=12). Engine seat-fairness confirmed independently (RandomMatch P0 0.455 ≈ 0.5; deep-EMM 2-piece probe 0.514 vs published 0.5186; solver cross-check bit-for-bit). G4 evidence (circuit-completion rates, decision latency) pending full-suite rerun.
- 2026-11-18: 07 Rosette G4 gate passed — circuit-completion harness (ADR-0011) on the content circuit with region-strength map (Sumer 3, Egypt 4, Mexica 4) and attempt-indexed re-challenge seeds; starting purse calibrated 40 → 80 (roadmap-tunable 20–80) to land optimal completion 0.583 (28/48, band 55–70%) and naive 0.083 (2/24, band 5–15%). Decision latency p95 0.037 s ≤ 0.150 s. `make test`/`make lint` green; tag `rosette/gate-G4-pass`; merged to main. Next: P5 Meta and Replayability.
- 2026-11-18: 07 Rosette P5 (Meta and Replayability) complete on branch `rosette/phase/P5-meta` — RSMeta package (ADR-0012): daily match derived from the UTC date (deterministic seed + 5,000-roll tetra4 dice sequence, no wall clock or UUIDs), stats with streaks and daily streaks, 20-achievement catalog, local leaderboards (daily wins, circuit purse), JSON MetaStore with corrupt-file fallback; `DiceSource` threaded through Reducer/BotMatch for bit-identical daily replays (INV-1/4/7 preserved). G5 content counts met: omens expanded 6 → 12 (content-lint: 6 rulesets, 12 taverns, 12 opponents, 12 omens). `make test` green (all packages, RSMeta 27/27) + `make lint` 0 errors; HANDOFF refreshed. Tag `rosette/gate-G5-pass`; merged to main. Next: P6 Aesthetics and Audio Pass.
