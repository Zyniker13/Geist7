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

## Raw capture session (2026-11-20)

Recorded on `zGeist7_bot-iPad-Pro-13` under sim-lock: app launched with
`-startMatch -seed 7 -autoPilot -aiDelay 0.35` (the deterministic
self-playing harness), a content probe (screenshot ≥ 300 KB) confirmed the
board was rendering, then `simctl io recordVideo` for ~20 s.

- Raw file: `rosette-preview-raw.mov` (4.07 MB, 19.46 s, 2064×2752, hevc)
- SHA-256: `9424518dac63ee0099745f6049ceb8efb1d252b0779f99fba4729d1c9ea9c735`
- Content verified by frame inspection: mid-match board with pieces in
  play, score bar at 0/7, active roll. Kept out of the repository per the
  plan; the maintainer trims to shot boundaries at submission.
- First recording attempt produced a white cold-boot launch screen only —
  discarded; the second waits for a rendering probe before recording.

## Status

- [x] Plan written
- [x] Raw capture recorded (19.46 s, SHA-256 above)
- [ ] Trimmed and boundaries verified (maintainer, at submission)
- [ ] Maintainer delivers trimmed file with issue #11 reference
