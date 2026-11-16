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
