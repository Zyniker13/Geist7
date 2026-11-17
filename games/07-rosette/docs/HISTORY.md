# Rosette — History

Per HIST0.1: three lists — Attested (with source), Reconstructed (with the
reconstruction's basis), and Invented for play. Grounded in `RESEARCH.md`
and the roadmap's §14 Sourcing Notes. The `ruleset:<id>` markers are read by
`Tools/content-lint/run.sh` to keep this file and `rulesets.json` labels in
agreement (Appendix A.7); every marker line must state the row's label.

## Attested

- The Royal Game of Ur boards from the Royal Cemetery at Ur (c. 2600–2400
  BCE), excavated by Leonard Woolley, held at the British Museum and Penn
  Museum: the board layout, 20 squares, rosette squares, and the 7-piece
  sets with four binary tetrahedra per player.
- The cuneiform tablet BM 33333B, written by the scribe Itti-Marduk-balāṭu
  (177–176 BCE), British Museum: five pieces per player, astragal
  (knucklebone) dice, and squares that carry fortunes (Finkel 2007).
- Senet boards and equipment from many Egyptian sites; Patolli as described
  by Diego Durán (16th century): the games existed and were played for
  stakes.

## Reconstructed

- ruleset:finkel — label: reconstructed — The modern playable ruleset
  (7 pieces, 4 binary tetrahedra counting marked tips, rosettes grant an
  extra roll, the central shared rosette is safe, captures send a piece
  home, exact bear-off): a modern reconstruction combining the excavated
  equipment with Finkel's reading of the later tablet (Finkel 2007;
  popularised by RoyalUr.net). Not attested as a rule set on any ancient
  source.
- ruleset:tablet — label: reconstructed — The Tablet ruleset: five pieces
  and astragal dice are attested (BM 33333B); the face-to-value mapping and
  face odds (10/40/40/10), the route, and the safety/capture details are
  filled in from the modern ruleset and flagged for HIST review (A.9).
- ruleset:masters — label: reconstructed — "The Masters' Long Route": a
  longer-track variant reconstructed from modern scholarship; not attested.
- ruleset:senet_like — label: reconstructed — The Senet-like variant uses
  Kendall's Senet reconstruction (four two-sided throw sticks, no
  captures). Senet has many reconstructions and none is authoritative; this
  is one of several, labelled as such.
- ruleset:patolli — label: reconstructed — The Patolli variant (52-space
  cross, five beans, bump-back captures) is reconstructed from Durán's
  account; the exact track and piece counts are not attested.
- Dice odds for the astragal model (astragal4): the tablet attests astragal
  dice but not the face odds; 10/40/40/10 is a placeholder pending HIST
  review (A.9 default).
- The doubling cube and stake conventions: borrowed from backgammon
  (introduced in 1920s New York) and applied to an ancient race game.

## Invented (for play)

- ruleset:house_rules — label: invented — "Tavern House Rules": no safe
  rosettes and inexact bear-off, designed for the circuit's spice.
- The wager layer beyond the stake: the doubling cube in this game, omen
  tokens (reroll, split, safety suspension), prices, tells, and the
  buy-in/purse economy are invented for play. The tablet's fortunes on
  squares inspired the omen idea; wagering and omen mechanics are Invented
  (roadmap §14).
- Every tavern, opponent, and their historical notes in the circuit
  (taverns.json, opponents.json): fiction. No historical person is
  depicted. The in-game "purse" is play money only; nothing of real value
  is wagered anywhere in the game.
- The tutorial's text (tutorial.json): game-authored, labelled Invented.
- Fortune-square effects (fortunes.json): the tablet attests that squares
  carry fortunes; which squares and what the effects do in this game are
  Invented (ADR-0008).
