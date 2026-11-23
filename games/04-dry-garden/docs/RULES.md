# Dry Garden — Rules

Authoritative rules spec, copied from `ROADMAP.md` §4 and Appendix A.1 with
rule IDs intact, then maintained here. Source: `ROADMAP.md` (the roadmap wins
on game-specific facts).

## Setup

- **R-1** The courtyard is a set of hex cells defined by `courtyards.json`
  (default "Ryōan" outline; see ADR-0004 for the built default: a 44-cell
  irregular outline with two features). Some cells are fixed features (moss or
  a basin) and cannot hold stones; they can be owned.
- **R-2** Supplies per player: 2 large, 3 medium, 4 small stones; rake lines
  unlimited but at most `rakesPerPlayer` (default 6).
- **R-3** Player 1 (basalt) moves first. The veranda edge (the viewing side)
  is the courtyard's bottom edge.

## Actions

- **R-4** `place(cell, size, facing)`: an empty non-feature cell not adjacent
  to an existing stone of the same player of the same size (prevents clumps).
  `facing` is one of 6 hex directions; it matters for R-12.
- **R-5** `rake(start, direction, length)`: a straight run of 2–5 empty,
  non-feature cells starting adjacent to one of the mover's stones. Raked
  cells cannot later receive stones. A raked cell already raked by the
  opponent cannot be raked again.
- **R-6** `pass`: legal only when the mover has no legal placement and no
  rakes left.

## Garden laws (legality)

- **R-7** Symmetry law: an action is illegal if, after it, the full set of
  stones (position and size, ignoring owner) is mirror-symmetric about any
  lattice axis of the courtyard, with ≥ 4 stones on the board.
- **R-8** Collinearity law: an action is illegal if, after it, any three
  stones lie on one straight lattice line with equal spacing.

## Influence and ownership

- **R-9** A stone of size `s` exerts influence `I_s(d)` on cells at hex
  distance `d`: large 6, 5, 4, 3, 2, 1 for d = 0…5; medium 4, 3, 2, 1; small
  3, 2, 1.
- **R-10** A rake line owned by player P adds P's influence of the anchoring
  stone at distance 1 (R-5's adjacent stone) to every cell of the line and to
  each cell adjacent to the line, undiminished along its length.
- **R-11** A cell's owner is the player with strictly greater total influence;
  ties are unowned.

## Scoring

- **R-12** Viewing face: a large or medium stone whose `facing` points toward
  the veranda (the three downward directions) adds +1 influence at distances
  1–2 in those directions (rewarding stones turned to their viewer).
- **R-13** Groups: stones of the same owner within distance 2 form a group.
  At game end, each group of odd size (1, 3, 5, or 7) scores
  `groupBonus[size]` (default 0, 4, 9, 15); even-sized groups score nothing.
- **R-14** Score = owned cells + group bonuses.
- **R-15** Game ends when both players have passed consecutively or both
  supplies and rakes are spent; highest score wins; tie → Player 2 wins.

## Invariants

- **INV-1** After any legal action, R-7 and R-8 hold.
- **INV-2** Ownership recomputed from scratch equals incremental ownership
  (1,000 random games).
- **INV-3** Stone supplies never go negative.
- **INV-4** Replay determinism.
- **INV-5** Alpha-beta equals minimax at depth ≤ 3 on 500 positions.

## Appendix A.1 additions (extended specification)

### Courtyard geometry

- **R-16** Axial coordinates use `q` (east) and `r` (south-east); hex
  distance `d(a,b) = (|dq| + |dr| + |dq + dr|) / 2`. The veranda edge is the
  set of cells with maximal `r` for each `q`.
- **R-17** Mirror axes are the 6 lattice reflection families (3 through cell
  centres, 3 through edge midpoints). An axis is "in play" for a courtyard
  only if reflecting the courtyard mask about it maps at least 70% of
  non-feature cells onto non-feature cells (precomputed at load; stored in
  `courtyards.json` as `axes`).
- **R-18** Symmetry test (R-7) compares the multiset of `(cell, size)` for all
  stones with its reflection; stones reflecting onto a wall or feature cell
  break symmetry automatically.
- **R-19** Collinearity test (R-8) applies to three stones on one straight
  lattice line with equal spacing `k ≥ 1`, regardless of owner and size.
  Spacing counts in cells along the line.

### Placement and rakes

- **R-20** A stone may not be placed on a raked cell, a feature cell, or
  adjacent to a basin (`tsukubai`-style feature) unless the courtyard sets
  `basinAdjacentAllowed`.
- **R-21** Rake lines may cross an opponent's rake line at exactly one cell;
  the crossing cell carries both rakes' influence bonuses (R-10) and belongs
  to neither rake for future crossings.
- **R-22** Rakes cannot pass through stones, features, or walls; a rake's
  `anchor` must remain adjacent to the first cell for the whole game (if the
  anchor stone is removed by a variant, the rake becomes inert).
- **R-23** Rake pattern: each rake line records a `pattern` (straight, ripple,
  wave) chosen for display only; all patterns have identical rules at launch.

### Influence detail

- **R-24** Influence is additive per player; a stone's own cell receives
  `I_s(0)`. Features receive influence and can be owned (moss and basin cells
  count as owned cells for scoring at weight 1).
- **R-25** Viewing-face bonus (R-12) applies only if no stone of the opponent
  stands between the stone and the veranda on the facing ray within distance 3
  (the "view is clear").
- **R-26** Group connectivity (R-13) uses hex distance ≤ 2 between stones of
  the same owner; groups are computed at game end only.

### Turn flow

- **R-27** A player with legal moves may not pass. If every placement is
  illegal by laws R-7/R-8 and no rakes remain, the player must pass (R-6).
- **R-28** Undo in casual mode reverts the last full turn pair; ranked, daily,
  and async modes have no undo.
- **R-29** Seasons (G5) apply their modifier at fixed turns stored in
  `seasons.json`; modifiers never change legality retroactively.
- **R-30** Resign is legal at any time and scores as a loss with margin
  recorded as the current difference.

## Additional invariants

- **INV-6** Symmetry and collinearity checks are order-independent:
  permuting the stone list never changes legality (property test, 2,000
  positions).
- **INV-7** Every axis listed in `courtyards.json` maps the courtyard to at
  least 70% of itself (content lint).
- **INV-8** Score equals owned cells + group bonuses and is recomputable from
  the final state alone.
- **INV-9** No two rakes overlap in more than one cell (R-21).
- **INV-10** `LegalMoves` never returns a move rejected by the reducer
  (fuzz 100,000 moves).
