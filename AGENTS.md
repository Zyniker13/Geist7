# Working in This Repository

This guide is for whoever works in this repository, human or agent. Read `ROADMAP.md` (how the program runs) and `STATUS.md` (where it stands) first, then `games/_shared/_CONVENTIONS.md`, `games/_shared/_SET2_ADDENDUM.md`, the current game's `games/NN-<slug>/ROADMAP.md` and `RESEARCH.md`, and its `docs/STATUS.md` and `docs/HANDOFF.md`.

## Precedence

The game roadmap set governs: `games/_shared/_CONVENTIONS.md`, `games/_shared/_SET2_ADDENDUM.md`, `games/_shared/_TEMPLATE.md`, and each `games/NN-<slug>/ROADMAP.md` with its `RESEARCH.md`. Where this file, `ROADMAP.md`, or `STATUS.md` seems to conflict with the set, the set wins; see [Precedence](ROADMAP.md#precedence).

The set governs phases P0–P10 and gates G0–G10, all owned and self-checked by the build agent, with local substitutes for owner-only steps; the technology stack; iPad-first platforms (iOS, iPadOS, and macOS); sourcing tiers and advisor review; the online and privacy choices; and the premium universal-purchase default.

## Sources of Truth

Each thing has exactly one home. Change it there; elsewhere, link to it.

| Topic | Single source |
| --- | --- |
| Process, stack, layout, architecture rules, dependency allow-list, testing, CI content, budgets, phases, gates, sign-off, owner-only steps and local substitutes, and handoff contents | `games/_shared/_CONVENTIONS.md` |
| Sourcing tiers, SRC and HIST tasks, advisor review, and set-wide technical notes | `games/_shared/_SET2_ADDENDUM.md` |
| A game's design, rules, content, modules, tasks, gate checks, and open-question defaults | `games/NN-<slug>/ROADMAP.md` |
| A game's art direction, lineage, cultural and historical context, glossary, and sources | `games/NN-<slug>/RESEARCH.md` |
| The shape of a game roadmap | `games/_shared/_TEMPLATE.md` |
| Build order, repository adaptations (paths, CI files, branches, tags, and merging), simulators, how to file maintainer issues, the program loop, game states, and copyright rules | `ROADMAP.md` |
| Current program position, game queue and states, the environment check, the fallback Needs the Maintainer list, and the program log | `STATUS.md` |
| Requests to the maintainer and their answers | GitHub issues labeled `needs-maintainer` (fallback: Needs the Maintainer in `STATUS.md`) |
| A game's phase and gate evidence | `games/NN-<slug>/docs/STATUS.md` |
| A game's decisions (ADRs), including every deviation from its roadmap | `games/NN-<slug>/docs/DECISIONS.md` |
| A game's third-party components, their licenses, and attribution text | `games/NN-<slug>/docs/THIRD_PARTY.md` |
| A game's sourcing packet and cultural manifest | `games/NN-<slug>/docs/SOURCING.md` and `cultural_manifest.json` |
| A game's open questions and answers | `games/NN-<slug>/docs/OPEN_QUESTIONS.md` |
| A game's handoff package, kept current at every gate | `games/NN-<slug>/docs/HANDOFF.md` |
| Copyright and license | `LICENSE` |
| How to report a vulnerability | `SECURITY.md` |

`games/_shared/` and each game's `ROADMAP.md` and `RESEARCH.md` are read-only for the build agent.

## Rules

- Follow the phases and gates in `games/_shared/_CONVENTIONS.md`, P0 through P10, and the [Program Loop](ROADMAP.md#program-loop). Never stop or wait: owner-only steps get a local substitute and a [maintainer issue](ROADMAP.md#issues-for-the-maintainer).
- Never perform Apple account, signing, App Store Connect, TestFlight, or payment actions, never contact cultural advisors, and never change `GEIST_BUNDLE_ID` from its placeholder.
- Before every merge to `main`, `make test` and `make lint` pass in the game's folder and CI is green on the branch. Never skip or disable a test to get green.
- Every change that alters behavior comes with tests, and every bug fix starts with a regression test.
- Work on one game touches only its folder and its workflow file, `.github/workflows/<slug>.yml`.
- Never force-push, rewrite pushed history, or move or delete a tag.
- Pin GitHub Actions to full commit SHAs and keep workflow permissions read-only.
- Use only dependencies on the allow-list in `_CONVENTIONS.md` §4.4, and only third-party assets under the terms in "Copyright and Third-Party Content" in `ROADMAP.md`.
- Keep `STATUS.md` and the game's `docs/STATUS.md` current after every meaningful step.

## Public Repository

Everything here is public, but all rights are reserved (see `LICENSE`): the repository is published for reference only and does not take outside contributions. Never commit, or put in an issue, secrets of any kind (including signing certificates, provisioning profiles, or keys that look real), email addresses, personal names, hostnames, IP addresses, local paths outside the repository, or anything about the machines or services used to develop it. Test data uses obviously fake values (`alice`, `example.com`). Commit messages describe the code only.
