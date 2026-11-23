# Dry Garden — Handoff

Kept current at every gate (`_CONVENTIONS.md` §9).

## 1. State summary

- **Phase:** P0 Setup — complete pending G0 sign-off.
- **Last passed gate:** none yet (G0 evidence in `docs/STATUS.md`).
- **Branch:** `dry-garden/phase/P0-setup`.
- **Commit:** see the latest `feat(app)`/`feat(core)` commit on that branch.
- **Tag:** none yet (the parent signs gates).

## 2. How to build and run

From a clean clone:

```sh
cd games/04-dry-garden
xcodegen generate                       # or: make generate
xcodebuild build -scheme DryGarden-iOS \
  -destination 'platform=iOS Simulator,name=<iPad simulator>' build
xcodebuild build -scheme DryGarden-macOS -destination 'platform=macOS' build
swift test --package-path Packages/DGCore   # 50 tests
make test        # packages + iOS UI tests (needs a booted iPad-class sim)
make lint        # swiftlint + swift-format + check-imports
```

## 3. Architecture

See `docs/ARCHITECTURE.md` (module map, determinism contract, dependency
direction enforced by `Tools/check-imports.sh`).

## 4. Decision log

See `docs/DECISIONS.md`. ADR-0001 toolchain, ADR-0002 stack, ADR-0003 hex
convention, ADR-0004 default-courtyard geometry (44 cells, zero in-play axes;
deviation from the roadmap's 113-cell working mask).

## 5. Known issues

`docs/KNOWN_ISSUES.md` — none open at P0.

## 6. TODO map

`docs/TODO_MAP.md` — hand tally at P0; `make todo` arrives with the P1 tree.

## 7. Test coverage report

`docs/COVERAGE.md` — coverage measurement begins at G1 (Core ≥ 90%).

## 8. Balance snapshot

`docs/BALANCE.md` — arrives at P4 with the first sim data.

## 9. Open questions

`docs/OPEN_QUESTIONS.md` — roadmap defaults plus the ADR-0004 flag.

## 10. Gate evidence

`docs/STATUS.md` — check-by-check pass table with pasted command output.
