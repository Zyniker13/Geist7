# Mattang — Phase & Gate Status

## Current State

- **Phase:** P0 Setup (in progress)
- **Branch:** `mattang/phase/P0-setup`
- **Last done:** MTCore 38/38 tests pass (Fixed, SeededRNG, Hex, InteractionTable, Replay); RULES/SOURCING/HISTORY/DECISIONS written; CI workflow added; macOS app build running for S0.4 evidence.
- **Next step:** finish S0.4 (app launches on iPad + Mac, screenshots), S0.7 overlay, docs skeletons, make test + lint, commit, CI green, file advisor issue, G0 sign-off + tag.
- **Blocked on:** nothing.

## Phase Queue

| Phase | State | Notes |
| --- | --- | --- |
| P0 Setup | in progress | S0.1–S0.3 done; S0.4–S0.7, SRC0.1/0.2 done or in flight; HIST0.1 done; G0 pending |
| P1 Rules Engine Prototype | pending | Tracer (R-3..R-6, R-12..R-14), turns (R-7..R-11), INV-1..5 |
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
| G0 Setup | pending | this file + repo-root STATUS.md |
| G1 Rules Engine | pending | — |

## Open Maintainer Items

- `mattang: cultural advisor review` — to be filed at G0 (SRC0.1 §8 brief; advisor arranged by maintainer).
- Revenue share (roadmap §13.2) — to be filed with the advisor item at P6; default none set.

## Toolchain (ADR-0001 evidence)

- Xcode 27.2 (see G0 evidence block below for `-version` output).
- iOS Simulator devices used by this game are prefixed `zGeist7_bot-` (never shared).

## Log

- 2026-11-20 — P0 started on `mattang/phase/P0-setup`. Scaffold, packages, tests written; two real bugs found and fixed by tests (Fixed multiply/divide sign handling; see DECISIONS ADR-0004 rationale); 38/38 green.
