# Rosette — docs/BALANCE.md

Sim results from `make sim` (`Tools/sim` — random-legal-move matches, Finkel ruleset, doubling cube accepted per the sim's policy). Regenerate with `make sim N=<count>`.

## 2026-11-16 — P2 snapshot (N=200, seeds 2–201)

```
player0 wins: 92
player1 wins: 108
gammons: 9
average plies: 219.43
FINAL HASH: 12791293766259663953
```

- Distribution: 46.0% / 54.0% over 200 games. Random play does not separate the players strongly; the slight player1 edge is within the range expected from random-legal play under Finkel rules (player1 moves second but also bears off second).
- Average length: ~219 plies (roughly 55 turns per side at ~4 plies/turn with extra rolls).
- Gammon rate: 4.5% of games.
- Determinism: the FINAL HASH is stable across repeated runs with the same arguments (INV-4); two runs printed the same hash.

## 2026-11-16 — G1 evidence (N=1000, deterministic)

Recorded at the G1 gate: `make sim N=1000` completed with 0 crashes, 0 illegal states, and identical hashes on two consecutive runs (see `docs/STATUS.md`, P1 G1 line).

## Notes

- Balance targets arrive in P4 (`RS-AI` difficulty tiers, win-rate bands per roadmap §7); this snapshot is the random-play baseline the tiers will be measured against.
- The engine's R-3 entry semantics were corrected during P2 (entry at step roll−1); all numbers above reflect the corrected engine.

## 2026-11-18 — G4 calibration harness (ADR-0011)

The P4 completion-rate bands are measured on the real content circuit (12 taverns, content opponents at region strengths: Sumer 3, Egypt 4, Mexica 4), settling each match at stake × final cube value with R-11 gammon doubling where the tavern enables it. Bots play omenless matches. Re-challenges mix the attempt index into the match seed (deterministic bots would otherwise replay an identical match).

**Calibrated starting purse: 80** (`circuit.json startPurse`, within the roadmap's tunable 20–80 range). Sweep results (48/24-run concurrent samples):

| Purse | Strength map | Optimal completion | Naive (careful s2) completion |
| --- | --- | --- | --- |
| 40 | (3,3,4) | 0.375 | 0.0 |
| 40 | (3,4,4) | — | 0.0 |
| 60 | (2,3,4) | 0.417 | — |
| 60 | (3,4,4) | 0.333 | — |
| 80 | (2,3,4) | 0.458 | — |
| 80 | (3,3,4) | 0.500 | — |
| 80 | (3,4,4) | **0.583** (28/48) | **0.083** (2/24) |
| 80 | (4,4,4) | 0.625 (30/48) | — |

(3,4,4) @ 80 is the accepted calibration: optimal 0.583 is inside 55–70%; naive 0.083 is inside 5–15%. (4,4,4) @ 80 also fits (0.625) but leaves no headroom. Gate values land in `docs/STATUS.md`; the regression tests pin wide plausibility bands only (24 runs each, concurrent: optimal ≥ 0.40, naive ≤ 0.30). Manual sweeps live in the disabled `ScratchCircuitRun` tests.
