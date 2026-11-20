# Mattang — Handoff Package

Kept current at every gate (`_CONVENTIONS.md` §7). Filled in at G0 sign-off and re-verified each gate.

## State at handoff

- Game: 06 Mattang; phase P0 (G0 pending at first entry).
- Branch/HEAD: `mattang/phase/P0-setup` (tag at each gate: `mattang/gate-Gn-pass`).
- How to build: `cd games/06-mattang && xcodegen generate && make build-mac` (iOS: `make build-ios`); tests: `make test`; lint: `make lint`.
- Where things are: docs/TODO_MAP.md maps roadmap tasks to code; docs/ARCHITECTURE.md documents layering.
- Open items: docs/OPEN_QUESTIONS.md, docs/KNOWN_ISSUES.md, maintainer issues (see docs/STATUS.md).
- Cultural review state: all manifest entries `pending` (docs/SOURCING.md).
