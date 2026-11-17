# Rosette — Rules

Copied from the game roadmap §4 and its extended rule list (§Appendix), which
is the single source of truth. This page restates them for in-game reference.

## The Game

The Royal Game of Ur played in a smoky tavern circuit, where the dice are
fair but the stakes are not. Solo vs AI in the circuit, local pass-and-play,
and async online matches (online arrives in a later phase).

## Board and Pieces

- **R-1** *(Reconstructed: piece count from the excavated Ur sets, not the
  tablet)* Each player has 7 pieces off-board at start. Each player's path:
  4 private squares, 8 shared middle squares, 2 private squares, then off
  (bear off with exact roll). Rosettes at private squares 4 and 14 and
  shared square 8 (indices per `rulesets.json`).
- **R-2** *(Reconstructed: dice from the excavated Ur sets; the tablet uses
  astragals)* Dice: 4 binary tetrahedra; roll = number of marked tips up
  (0–4) with probabilities 1/16, 4/16, 6/16, 4/16, 1/16.

## Moves

- **R-3** On a roll `n > 0`, the player must move one piece exactly `n`
  squares along its path, if any legal move exists; otherwise the turn
  passes. A roll of 0 passes.
- **R-4** A piece cannot land on a square occupied by its own piece.
- **R-5** Landing on a shared square occupied by an opponent captures it
  (sent off-board to start), unless that square is the central rosette
  (safe; the move is illegal).
- **R-6** Landing on any rosette grants another roll.
- **R-7** Bearing off requires the exact number to move one past the last
  square.
- **R-8** First player to bear off all 7 pieces wins the match.

## Wager Layer

- **R-9** Match stake `S` is agreed before the match (circuit: set by tavern
  minimum and player purse).
- **R-10** Cube: before rolling, a player who owns the cube (or anyone if
  centred) may offer a double. The opponent accepts (stake ×2, cube passes
  to them) or concedes (loses current stake). Max cube 64.
- **R-11** Gammon-equivalent: if the loser has borne off zero pieces, they
  lose 2× stake (toggle per tavern).
- **R-12** Omens: each player may hold up to 2 omens; one per match; played
  before the roll. Examples: "Re-roll once", "Treat central rosette as
  unsafe this turn", "Move two pieces splitting the roll". Omen effects are
  data with a closed set of effect kinds.

## Circuit

- **R-13** The circuit has 3 regions × 4 taverns. Each tavern has an
  opponent, ruleset, minimum stake, and buy-in. Purse below the cheapest
  available buy-in ends the run.
- **R-14** Between matches, the player may buy omens or pay to learn an
  opponent's tell (shows its cube policy).

## Variants, Assists, and Tells

- **R-15** Every match states its ruleset and label on the table cloth
  before play. Default circuit ruleset: Finkel/RoyalUr (Reconstructed). The
  Tablet ruleset unlocks in region 2 with an About card explaining what the
  tablet attests and what is filled in.
- **R-16** Tablet ruleset (each element labelled): 5 pieces per player
  (Attested); astragal dice, modelled as 4 knucklebones whose faces map to
  move values (Attested that astragals were used; the face-to-value mapping
  and face probabilities are Reconstructed parameters in `dice.json`);
  fortunes attached to specific squares, implemented as omen draws when a
  piece lands there (Attested that squares carry fortunes; the in-game
  effects are Invented); route and safety identical to Finkel/RoyalUr
  (Reconstructed).
- **R-17** The Tablet dice model is a data table of `(outcome, weight)`
  pairs; weights must sum to the model's denominator and are stated in the
  odds panel.
- **R-18** When several pieces can move, the player chooses; when exactly
  one legal move exists, Assist mode auto-plays it after 0.6 s (toggle).
- **R-19** A rosette extra roll may chain without limit.
- **R-20** A capture on a rosette other than the central rosette is legal
  only in rulesets where `safeRosettes` excludes that square (data).
- **R-21** A double may be offered only before rolling and only once per
  turn; an omen and a double may both be used in one turn, omen first.
- **R-22** The "Crawford" rule applies in circuit finals: when a player is
  one match from elimination, the cube is dead for the next match.
- **R-23** Omen effects may never change dice probabilities; they act only
  on choices (re-roll, split, safety toggles). This keeps the fairness
  pillar honest.
- **R-24** Tavern tells reveal the opponent's doubling and take thresholds
  rounded to 5%.

## Invariants

- **INV-1** Piece conservation (off-board + on-board + borne off = pieces
  per side).
- **INV-2** Dice distribution: χ² test over 10⁶ seeded rolls matches R-2 at
  p > 0.01.
- **INV-3** Purse never negative; cube value ∈ {1, 2, 4, …, 64}.
- **INV-4** Replay determinism.
- **INV-5** Solved table: expectiminimax at depth 2 never finds a move with
  higher win probability than the table's choice on 10,000 random positions
  (within 1e-6 when converted).

## Balance Parameters (defaults; §6)

| Name | Default | Range | File |
| --- | --- | --- | --- |
| Starting purse | 40 | 20–80 | `balance.json` |
| Omen costs | per row | 5–40 | `omens.json` |
| Cube max | 64 | 8–64 | `balance.json` |
| Gammon rule | per tavern | — | `taverns.json` |

Targets: Finkel first-player win rate matches the published solved value
(slightly above 50%); circuit completion rate for an "optimal" bot 55–70%
and for a "naive" bot 5–15%; median match length 4–9 minutes for humans.

## Privacy

No network communication; no telemetry; all data stored locally. The purse
is in-game only — no real money is involved anywhere.
