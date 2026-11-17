# Rosette — Vertical Slice Self-Assessment (G2)

Written at the end of P2 per the GATE G2 check, with every weakness turned
into a concrete P3 task. Reviewed again at G3: the P3 tasks below are
delivered (see the status notes per section).

## The slice

A complete Finkel match against a heuristic opponent: SpriteKit board with
tap-to-move, legal-move highlights, dice roll, doubling cube with
offer/accept/decline, an omen played before the roll, the odds panel
("Chance to capture next roll: N%"), autosave/resume, and a results
overlay. Verified by a UI test that completes a full match with a double
accepted on iPad and Mac, plus 200-state odds-panel agreement tests.

## Pillar 1 — Fair dice, honest odds

- **Delivered in the slice:** exact odds panel for the capture heuristic;
  χ² battery (INV-2) over 10⁶ rolls; INV-7 stream separation so UI actions
  cannot perturb the dice stream.
- **Weakness → P3 task:** the odds panel existed only for the Finkel
  tetra4 dice; the variant dice (astragal4, stick4, beans5) had no
  distribution tests.
  **Status: done in P3** — DiceModelTests covers weights-sum-to-denominator
  (R-17), resolution by id, and 100k-roll frequency agreement per variant;
  the content vs engine dice agreement is pinned in RSContentTests.
- **Weakness → P3 task:** the odds panel does not yet state the dice model's
  own weights in-game (R-17's "stated in the odds panel").
  **Status: deferred to P4 with the odds-panel rework** (it needs the
  RS-P4 AI's equity work in the same panel); tracked in docs/TODO_MAP.md.

## Pillar 2 — The wager is the strategy

- **Delivered in the slice:** cube UI with offer/accept/decline at the
  correct legality windows (R-21), stake ledger reconciling the purse
  (RS-P2.3), one tavern match vs a personality.
- **Weakness → P3 task:** the slice had one hardcoded tavern and one
  personality; the circuit (R-13/R-14), omen shop, and tells were missing.
  **Status: done in P3** — content-driven 12-tavern circuit, six-omen shop
  with costs 5–40, tell purchase revealing cube thresholds (R-24), omens
  held per side and travelling into matches.
- **Weakness → P3 task:** the heuristic AI has no cube policy; doubles are
  answered by a borne-off comparison, not equity.
  **Status: P4 (RS-P4.1)** — cube policies by personality are the P4 task;
  the UI hook points (`shouldOfferDouble`, `aiRespondToDouble`) are isolated
  for replacement.

## Pillar 3 — History labelled

- **Delivered in the slice:** nothing visible in-game (labels existed only
  in engine types).
- **Weakness → P3 task:** in-game history surfaces.
  **Status: done in P3** — the match info panel shows the ruleset's name
  and label on every table (HIST3.1/R-15); the Rules & History screen lists
  all six rulesets with label badges and quoted sources plus an About card;
  taverns, omens, and opponents carry their labels and notes in the circuit
  UI; docs/HISTORY.md lists Attested/Reconstructed/Invented with
  `ruleset:<id>` markers that content-lint cross-checks (A.7).

## Pillar 4 — Five-minute matches

- **Delivered in the slice:** a Finkel match runs 60–150 plies against the
  heuristic; the UI test completes in seconds with fast timers.
- **Weakness → P3 task:** no match-length telemetry beyond the outcome's
  ply count; the 4–9-minute median target is unmeasured for humans.
  **Status: deferred to P4/P5** (needs playtest data — maintainer item);
  the ply counter is already in the outcome record.

## Weaknesses carried forward (not P3 scope)

- Variant move generators have no dedicated UI art (P6 board art per
  region).
- The circuit economy needs tuning before the G4 completion-rate gate
  (OQ-004 in docs/OPEN_QUESTIONS.md).
- The macOS menu screenshot requires a display server (maintainer issue
  #4); slice recording was captured as stills pending that fix.
