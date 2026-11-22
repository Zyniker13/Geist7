# Mattang — Balance Record (P4)

Per `_CONVENTIONS.md` §8 P4: per-tier budgets, the AI-vs-AI soak, and
win-rate bands, all measured, nothing asserted without a run.

## Tier ladder (ROADMAP §7)

| Tier | Depth | Noise band | §7 budget |
| --- | --- | --- | --- |
| Paddler | 1 | 6 | — (depth 1, millisecond plies) |
| Sailor | 2 | 0 | — (sub-second plies measured below) |
| Navigator | 4 | 0 | 1.0 s/ply |
| Deep Water | 6 | 0 | 2.0 s/ply (name pending advisor; "Deep Water" placeholder) |

## Soak design (Tools/sim --soak)

- Charts: the probe charts (`east`, `diagonal`, `mirror`, `rotate`,
  radius 5) and `slice` — the shipped `two_swells_basic` geometry at
  radius 7 (ADR-0015). G4 bands are recorded on `slice`, the shipped
  content; probe charts isolate effects cheaply.
- Openings: each game starts from a **seeded opening prologue** (2
  placements by default, `--prologue N`), alternating seats. Zero-band
  tiers ignore the RNG (their choice is a pure function of the
  position), so without a prologue 500 seeds replay the same two games
  and the ≥75% band would be vacuous. With it, every seed opens on a
  distinct position.
- Seats alternate across seeds (even seed → higher tier is P1), so a
  seat-biased chart cannot masquerade as a tier gap.
- Every ply runs the INV-2/3/5 sweep plus INV-1 order checks (every
  6th ply); a run aborts on the first violation.

## Engine fixes found by the soak (regression-tested in MTAITests)

1. `RootSearch.run` returned its list in search order; `chooseAction`
   played `best[0]` — the *previous* iteration's best, not the final
   one. Now the list is value-sorted (test `testRootScoresAreValueSorted`).
2. `Search.apply` wiped the visited map, so the search never saw a
   third repetition (R-23) and steered into tie-break losses the R-11
   tie-break hands to P2 on the symmetric charts (test
   `testSearchAvoidsThirdRepetitionLoss`).

## Measured results (DEBUG build, M-series Mac, caps ON per ADR-0020)

Probe-chart bands (mixed tiers, `--prologue 4`, max-plies 300):

| Chart | Pair | Games | High wins | Band |
| --- | --- | --- | --- | --- |
| east | Sailor vs Paddler | 80 | 44 (29 lost, 7 split) | 0.60 FAIL |
| diagonal | Sailor vs Paddler | 6 | 4 | PASS (small n) |
| mirror | Sailor vs Paddler | 6 | 6 | PASS (small n) |
| east | Sailor vs Sailor (control) | 8 | 3/3, 2 splits | 0.50 (expected) |
| east | Paddler vs Paddler (control) | 8 | 4/4 | 0.50 (expected) |

Slice-chart reality check (Sailor vs Paddler, `--prologue 4`):

| Max plies | Games | Result | Elapsed |
| --- | --- | --- | --- |
| 300 | 20 | **20 splits** (0.0000) | 6824 s (~341 s/ply) |
| 200 | 8 | 8 splits | 1913 s (~239 s/ply) |

**The slice chart at the shipped swells is a dead-draw field for the
AI at depth ≤ 2: neither side can force a landing within 200–300
plies.** The equal-tier east control (3/3 after the engine fixes)
shows the seat parity the bands assume; the east mixed-tier band sits
at ~0.60, not ≥ 0.75.

## Open balance issues (G4 blockers, tracked in docs/STATUS.md)

1. **Slice-chart decisiveness:** games do not end. Either the charts
   need the A.4 tunables re-examined (canoesToWin, sailRange, island
   pool) or the AI needs a landing-forcing search mode; §A.4's
   "median length 24–40 plies" target is far from met (median 300+).
2. **Tier gap below the band on the probe charts:** 0.60 measured vs
   0.75 required; the diagonal/mirror small samples pass but east
   does not. The A.5 evaluation (distance-only) cannot see forced
   landings beyond the search depth; deep tiers need either more depth
   or landing-aware evaluation to open a real gap.
3. **Per-ply cost on the slice:** ~239–341 s/ply at depth ≤ 2 in
   DEBUG is far beyond the §7 budgets; even RELEASE will not fit the
   1.0 s/2.0 s tiers. ADR-0020's caps need the interior breadth raised
   on the big charts or the field update cost profiled again.

None of these can be closed by re-running: they are design-level.
Recorded here per §8.2 as measured, with the local substitutes and
the remaining work filed for the next phases.
