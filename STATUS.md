# Program Status

Program: Geist7, Set Two (twenty-five games). See [`ROADMAP.md`](ROADMAP.md) for the build order and the Program Loop.

## Current

- **Game in progress:** none.
- **Next step:** run the Environment Check below and record its output, then start 07 Rosette at P0 (`games/07-rosette/ROADMAP.md`).

## Environment Check

Do this once, before the first game's P0, and record the output here:

- `xcodebuild -version` must report Xcode 27.2 (`_CONVENTIONS.md` §2).
- `xcrun simctl list runtimes` must show an available iOS simulator runtime of version 26.0 or later.
- `xcrun simctl list devices available` must include the simulators named in "Environment" in `ROADMAP.md`, or the closest models created or picked as that section says.
- `swift --version`, `brew --version`, `xcodegen --version`, `swiftlint version`, and `swift-format --version`; install missing tools with `brew install`.
- `gh auth status`: if it fails, file maintainer items with the fallback in "Issues for the Maintainer" in `ROADMAP.md`.
- The issue labels exist: `gh label list --repo Zyniker13/Geist7` shows `needs-maintainer`, `blocked`, `question`, `program`, and one label per game slug. Create any that are missing with `gh label create`.

If Xcode 27.2 or an iOS 26-or-later runtime is missing and cannot be installed without an administrator, file it as a `program` maintainer item; no game can build until it is fixed.

- (not run yet)

## Games

| Order | No. | Game | State | Last Gate | Open Maintainer Issues |
| --- | --- | --- | --- | --- | --- |
| 1 | 07 | Rosette | Not Started | — | — |
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
