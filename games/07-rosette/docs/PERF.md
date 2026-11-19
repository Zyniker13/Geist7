# Rosette — Performance Record (G8)

Budgets per `_CONVENTIONS.md` §7. Rosette is a 2D game, so the 2D column applies
(memory < 1.0 GB, download < 300 MB). Device-class frame-rate and thermal targets
(120 fps ProMotion, no `serious` thermal in 30 min) need real hardware and are
tracked as a maintainer issue; the simulator proves the 60 fps floor and the
launch/resume/memory budgets.

## Environment

| Item | Value |
| --- | --- |
| Device | iPad Pro 13-inch (M4) — iOS Simulator (`zGeist7_bot-iPad`), ProMotion device class |
| OS | iOS 27.2 (24B8117) |
| Xcode | 27.2 |
| Swift | 6.4.2 (swiftlang-6.4.2.1.9) |
| Build | Debug, `Rosette-iOS` scheme, `CODE_SIGNING_ALLOWED=NO` |
| Date | 2026-11-19 (EST) |

## §7 Budgets

| Metric | Budget | Measured | Status |
| --- | --- | --- | --- |
| Cold start to interactive main menu | < 2.0 s | **1.845 s** avg (n=5: 1.727–2.001 s, RSD 5.8%, `XCTApplicationLaunchMetric`) | ✅ within budget |
| Resume a saved game | < 1.0 s | _pending (asserted inline around the resume interaction)_ | — |
| Memory (resident) | < 1.0 GB | _pending (XCTMemoryMetric)_ | — |
| Frame rate (gameplay) | 60 fps floor (120 fps ProMotion needs hardware) | _pending (SKView `showsFPS` overlay screenshots)_ | — |
| AI think time | p95 < 1.5 s | p95 0.474 s (p50 0.080 s, max 0.981 s) | ✅ within budget |
| App download size | < 300 MB | _pending (unsigned app bundle size)_ | — |
| Thermal (no `serious` in 30 min) | — | real hardware only (maintainer issue) | ⏳ hardware |
| Crash-free sessions (beta) | ≥ 99.5% | TestFlight only (maintainer issue) | ⏳ hardware |

## AI Think Time

Benchmark: `ScratchThinkTime` (RSAI, disabled manual harness) — a headless
autoPilot match against the wired `OptimalBot` (Finkel tavern), recording the
wall time of every AI decision.

| Stat | Value |
| --- | --- |
| Decisions (n) | 2,751 |
| p50 | 0.080 s |
| p95 | 0.474 s |
| max | 0.981 s |

Budget: p95 < 1.5 s on iPad (base). **Met** — p95 is 0.474 s, ~3× under budget.
The daily opponent uses the bundled solved table (ADR-0014), so its think time
is bounded by the same expectiminimax search.

## Method

- Launch / resume / memory: `RosettePerfUITests` (XCTest metrics), run through
  `sim-lock` on the iPad Pro 13-inch (M4) simulator. These run outside `make
  test` (the Makefile skips UI tests) and are invoked explicitly.
- Frame rate: the SKView `showsFPS` overlay (`-showFPS` launch argument) renders
  the live frame rate in the board corner; screenshots are captured mid-match
  and attached to the test result.
- AI think time: headless harness (no simulator), so it is reproducible on any
  Apple silicon host.

## Hardware-Only Items (maintainer issues)

- 120 fps ProMotion sustained / p99 frame time ≤ 8.3 ms — needs a real
  ProMotion iPad.
- Thermal state over 30 minutes of play — needs a real device.
- Crash-free sessions ≥ 99.5% — TestFlight beta only.
