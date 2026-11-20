# Rosette — App Preview Video Plan

A 15–30 s preview recorded with `simctl io recordVideo` on the iPad
simulator (iPad-first), per conventions §P10. Editing/music are the
maintainer's call at submission; the raw capture and shot list are produced
here.

## Shot list (raw capture)

1. Cold start to a fresh match (stake prompt) — ~4 s.
2. Roll of the four dice; a piece moves seven; rosette banner on the
   central rosette — ~6 s.
3. A capture sends an opponent piece home; log line appears — ~4 s.
4. Doubling cube offered and accepted — ~5 s.
5. Match win: purse grows, circuit advances to the next tavern — ~6 s.

## Mechanics

- Launch the app with a fixed seed and the autoPilot/aiDelay-0 harness used
  by the perf tests so the match plays itself deterministically; record the
  full 30 s in one pass on `zGeist7_bot-iPad-Pro-13` under sim-lock.
- Export: `xcrun simctl io <device> recordVideo preview.mov` (start/stop
  around the run), then trim to the shot boundaries. The `.mov` stays out of
  the repository (binary, several MB); the trimmed file is delivered with
  the maintainer issue reference and its SHA-256 recorded here.

## Status

- [x] Plan written
- [ ] Raw capture recorded
- [ ] Trimmed and boundaries verified
- [ ] SHA-256 recorded
