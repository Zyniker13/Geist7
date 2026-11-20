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
| Resume a saved game | < 1.0 s | **0.648 s** app-side (menu → board first frame; `-autoResume -boardDebug` probe, replay 79 actions) | ✅ within budget |
| Memory (resident) | < 1.0 GB | **65–67 MB** peak physical during a live autoPilot match (`XCTMemoryMetric`) | ✅ within budget |
| Frame rate (gameplay) | 60 fps floor (120 fps ProMotion needs hardware) | 60 fps on the simulator overlay (screenshots below); 120 fps sustained + p99 ≤ 8.3 ms needs hardware | ✅ floor / ⏳ hardware |
| AI think time | p95 < 1.5 s | p95 0.474 s (p50 0.080 s, max 0.981 s) | ✅ within budget |
| App download size | < 300 MB | **4.7 MB** (Debug `.app`, iOS simulator) — orders of magnitude under budget | ✅ within budget |
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

## Resume a Saved Game (0.648 s)

The §7 budget is a user-perceived resume latency, so it is measured **app-side,
harness-free**: launch the app with `-autoResume -boardDebug` on a simulator
holding an autosave, and read the timeline `BoardDebug` appends to
`Documents/boardDebug.txt`. Each line is elapsed-since-process-launch.

```
+0.000 s | menu onAppear
+0.006 s | resume tapped (auto)
+0.009 s | vm snapshot init: replay begin (79 actions)
+0.010 s | vm snapshot init: replay done
+0.131 s | makeUIView begin
+0.132 s | makeScene begin
+0.137 s | makeScene end
+0.137 s | makeUIView end (scene presented)
+0.648 s | scene first frame
```

Resume interaction: `resume tapped` → `scene first frame` = **0.642 s**
(wall: menu appears at 0.000, board is interactive at 0.648 s) — **within the
1.0 s budget**. The SpriteKit scene itself builds in ~5 ms; the remaining time
is SwiftUI navigation + the SKView render pipeline's first frame.

The `RosettePerfUITests.testResumeSavedMatch` UI test measures the same
interaction through XCTest, where tap synthesis, idle-waiting, and snapshot
polling add ~1.2 s of harness overhead; it therefore asserts a 2.5 s
harness-inclusive ceiling as the coarse end-to-end gate, with this probe as the
budget evidence.

## Frame-Rate Floor: 60 fps (fixed: off-main AI)

The first measured run showed the floor **failing**: the SKView overlay read
**31.6 fps** mid-play. An Instruments Time Profiler trace on the app process
showed the AI's expectiminimax move search (`OptimalBot.chooseMove`, depth 3,
thousands of node visits) executing **on the main thread** inside
`GameViewModel.aiTurn()`, freezing the SpriteKit render loop for the whole
think.

Fix (RS-P8): `MatchBot` is now `Sendable`; `aiTurn` captures a Sendable
snapshot of the state, legal moves, RNG, and generation counter, runs
`bot.chooseMove` in a detached background task, and the decision lands back on
the main actor through `finishBotMove(_:advancedRng:generation:)`. A decision
computed against a superseded state (generation mismatch — the human acted
during the think) is discarded and the turn rescheduled; RNG advancement and
`aiThinking` are applied atomically at landing, so the single-chain replay
order of the daily match is preserved.

Evidence after the fix — `-autoPilot -seed 42 -aiDelay 5 -startMatch -showFPS`,
two mid-play screenshots (during the AI's think):

```
nodes:412  60.0 fps
nodes:388  60.0 fps
```

The frame-rate floor is **met**: 60.0 fps during active gameplay including
background AI thinking. Regression coverage:
`Tests/UnitTests/AsyncBotDecisionUnitTests.swift` (slow-bot decision lands;
superseded decision is discarded) plus the autoPilot UI suites, which now
exercise the async chain end-to-end.

## Hardware-Only Items (maintainer issues)

- 120 fps ProMotion sustained / p99 frame time ≤ 8.3 ms — needs a real
  ProMotion iPad.
- Thermal state over 30 minutes of play — needs a real device.
- Crash-free sessions ≥ 99.5% — TestFlight beta only.
