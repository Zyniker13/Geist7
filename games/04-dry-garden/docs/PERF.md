# Dry Garden — Performance

Budgets from `_CONVENTIONS.md` §7; measurements recorded per device/OS/build/
date. P0 has no gameplay loop yet, so the table below holds the placeholder
budgets and will be filled from P2 captures (screen recording, debug overlay
fps, XCTest `measure`, Instruments).

| Metric | Target | Current (P0) |
| --- | --- | --- |
| Frame rate (gameplay) | 120 fps on iPad Pro 13" (M5), p99 ≤ 8.3 ms | n/a (menu only; overlay reads 60 fps on the sim's 60 Hz panel) |
| Frame rate floor | 60 fps on iPad (base) / mini | n/a |
| Mac | 120/60 fps by display | n/a |
| Cold start to menu | < 2.0 s | n/a (measured in P2) |
| Memory (resident) | < 1.0 GB (2D) | n/a |
| App download size | < 300 MB (2D) | n/a |
| AI think time | p95 < 1.5 s default; roadmap Master 1.0 s / Ancient 2.0 s | n/a (P4) |
