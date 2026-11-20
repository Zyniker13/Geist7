# Rosette — Beta Notes and Tester Guide

Status: draft for the maintainer's TestFlight upload (P9, local substitute per `_CONVENTIONS.md` §8.2). The app is telemetry-free: no analytics, no crash reporting, no network calls beyond Game Center (opt-in) and async online matches (opt-in).

## Beta Notes (App Store Connect "What to Test")

Rosette 0.1 beta. The Royal Game of Ur with a wager layer, in a tavern circuit from Ur to Thebes to Tenochtitlan.

What to test:

1. **Core match (Reconstructed ruleset).** Solo vs AI in the first tavern. Roll, move, rosettes (extra roll + safety), captures, bearing off. A match should take 5–15 minutes.
2. **Wager layer.** Set a stake before a match; offer/accept/decline a double mid-match; buy and play an omen token between matches.
3. **Circuit.** Play tavern to tavern; purse grows with wins; circuit completion records a stats entry.
4. **Rulesets.** Switch between Reconstructed (default) and Tablet (attested where the tablet attests).
5. **Daily match.** One seeded match per day; results persist across launches.
6. **Stats and export.** Settings → Stats shows matches, wins, losses, gammons, daily matches. Settings → Export writes a local JSON file and opens the share sheet. Nothing is uploaded.
7. **Game Center (opt-in).** Sign in, play async online matches; decline if unavailable.
8. **Resume.** Kill and relaunch mid-match; the match resumes from its snapshot.
9. **iPad and iPhone.** Layout is iPad-first; check iPhone portrait for clipped controls.
10. **macOS.** Keyboard: arrow keys + Return to move, R to roll, Esc to cancel.

Known issues (see `KNOWN_ISSUES.md`):

- UI-test accessibility snapshots can starve under the XCTest host (issue #10); does not affect normal play.
- AI move quality is heuristic + shallow search; expect fast, occasionally suboptimal play.

## Tester Guide

- Install from TestFlight (internal group). Sign in with the Apple account the maintainer provides.
- Report crashes with the device model, OS version, and what you were doing. There is no in-app crash reporting, so the TestFlight crash log is the only crash data.
- Report balance problems (a tavern that feels too hard/easy, a double that feels wrong) with the tavern name and the seed shown at match end.
- Report cultural/label issues (an Attested/Reconstructed/Invented label that looks wrong) with the screen and the rule in question.
- Do not share the TestFlight build link outside the group.

## Local Substitutes (what the build agent ran instead of a beta)

- Release archive built with `CODE_SIGNING_ALLOWED=NO` (evidence in `STATUS.md` P9).
- Full unit + UI test suites green on macOS and the iOS simulator.
- Long soak: `Tools/sim` headless matches (evidence in `STATUS.md` P9) as the local substitute for beta crash data.
- Balance pass from `Tools/sim` data against the `BALANCE.md` baseline (evidence in `STATUS.md` P9).

## Age Rating (G10 substitute draft)

The questionnaire is answered in App Store Connect by the maintainer (issue #11); these are the accurate answers to copy. Rosette has no real-money wagering, no purchasable currency, and no cash-out: the purse and stakes are in-game only.

- Contests/sweepstakes: No.
- Gambling (real money, or cash-out of in-game currency): No.
- Simulated gambling (games of chance with wagering that uses only in-game currency): **Yes** — dice and the doubling-cube wager layer are the core loop.
- User-generated content / unmoderated chat: No.
- Health, medical, or wellness claims: No.
- Age rating resulting: **12+** under Apple's rubric for simulated gambling; also mark the Game Center check where the form asks.

## Crash Data Substitute (G9 substitute record)

There is no crash-reporting SDK (by design, telemetry-free). G9's "crash-free ≥ 99.5%; no S1/S2" is substituted locally by:

- `Tools/sim` soak: 2,000 headless matches, exit 0, no exceptions (log and hash in `STATUS.md` P9 evidence).
- Full test suites green (unit 29/29 via the direct runner; UI 11/11 on the iOS simulator).
- No crash reports in the simulator `DiagnosticReports` for any session this
  phase. One historical report (2026-11-18) exists: a unit-test-runner crash
  (`RosetteUnitTests-macOS`, `MacKeyboardUnitTests.testNumberKeyAppliesLegalMove`)
  from an unguarded `legalMoves[0]` subscript in the test itself, fixed by the
  empty-moves guard now in the tree; the full bundle has run green since
  (29/29 on 2026-11-20) with no further reports. No shipping-app crash has
  occurred in any phase.

The true crash-free rate comes from TestFlight usage and is the maintainer's to read (issue #11).
