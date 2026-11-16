# Program Status

Program: Geist7, Set Two (twenty-five games). See [`ROADMAP.md`](ROADMAP.md) for the build order and the Program Loop.

## Current

- **Game in progress:** 07 Rosette (P2 UI Shell) — P2 UI implemented (MainView/GameView/GameViewModel/SaveManager, odds panel, UI-test autopilot); CI root causes fixed (wrong action SHA, signing, package platforms, swift-format 604 CLI); ADR-0006 records the lint reconciliation.
- **Next step:** Confirm CI green on main + local `make test`/`make lint` green, then G2 media evidence (screenshots on iPad + Mac), gate G2, proceed P3.

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
- `gh auth status`: NOT authenticated (no token file at ~/.hermes/profiles/geist7/gh-token). Using fallback: maintainer items go to "Needs the Maintainer" in STATUS.md.
- `gh label list`: NOT CHECKED (gh not authenticated). Labels will be created when gh is available.

## Games

| Order | No. | Game | State | Last Gate | Open Maintainer Issues |
| --- | --- | --- | --- | --- | --- |
| 1 | 07 | Rosette | In Progress (P2) | G1 | — |
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
