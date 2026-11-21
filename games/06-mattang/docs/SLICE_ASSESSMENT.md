# Slice Assessment — Mattang (P2)

Written at the end of P2 per GATE G2's check, with every weakness turned
into a concrete P3 task. Evidence: the auto-pilot UI test
(`testAutoPilotCompletesGameVsSailor`, seed 7), the pause unit suite,
and the S2.5 recording (`docs/media/slice.mp4`).

## Pillars (from ROADMAP.md §1)

Mattang's pillars: the swell-field tracer (rays that refract, reflect,
and meet in nodes) made **legible**; island placement that **deforms**
the field; a turn-based game of landings and becalming on top of the
field; and Marshallese stick-chart **lineage** carried by neutral
placeholder names until advisor review.

## What the slice delivers

- **Sea scene**: the full tracer field (rays, nodes, refraction,
  reflection) renders live on iPad and macOS from the same
  `SeaSceneModel`/`SeaSceneView`; rays and node rings toggle.
- **Placement deformation**: tapping an ocean cell arms a ghost island
  whose field preview is computed by the engine's own
  `FieldUpdate.applyIslandPlacement` — the preview equals the committed
  field, pinned by a 500-randomized-placement test.
- **Full action set vs Sailor**: place, launch, sail (path legality),
  becalm/tow, pass — the complete P1 rules engine exposed through taps,
  with path highlight and Sail/Place/Pass/Cancel controls.
- **Sailor AI opponent**: 1-ply greedy heuristic on its own task after
  a configurable delay; auto-pilot drives both sides for tests and
  captures.
- **HUD and controls (S2.2)**: status line, view toggles (rays, nodes,
  Marshallese names), restart, pause/resume with overlay, results
  screen with Play again/Menu.
- **Save/resume (S2.4)**: the match persists after every action to
  `mattang.match.v1`; a session without `-startMatch` resumes it.
- **Cultural posture**: every swell name, glossary term, and canoe art
  is `pending` in the manifest; DEBUG builds carry the "Pending advisor
  review" corner mark (SRC2.1), release compiles it out; the content
  deny-list (SRC2.2) passes on real content and fails all three
  restricted-term fixtures.

## Weaknesses → P3 tasks

1. **One chart, one pool size.** The slice runs a single chart
   (`two_swells_basic`) and one pool. → **P3 MT-P3.1**: content-driven
   G3 charts and puzzles with per-chart pools.
2. **Sailor is 1-ply greedy.** No search, no tiers, no latency budget,
   no balance data. → **P3/P4 MT-P4.x**: tier ladder (Paddler → Deep
   Water), time budgets enforced, AI-vs-AI soak, win-rate bands in
   `docs/BALANCE.md`.
3. **No tutorial flow.** The menu has Play only; lessons exist as
   content but no flow surfaces them. → **P3 MT-P3.x**: tutorial flow
   scripted from `tutorial.json` lessons.
4. **No voyages campaign.** No run structure beyond a single match. →
   **P3 MT-P3.1**: voyages campaign (6) wired into the meta layer.
5. **Placeholder art.** Procedural placeholder canoe/island art and
   neutral swell labels. → **P6** carries the real art pass; the
   advisor review gates the cultural terms (maintainer issue #16).
6. **No in-game history.** Plies persist but no move list or replay UI
   exists. → **P3 MT-P3.x**: in-game history surface (plies list with
   swell-state context); deeper replay UI stays with P5 meta/replay.
7. **No audio, no haptics.** Silent slice. → **P6 (MT-P6.x)**: the
   MTAudio package is scaffolded but unwired; waves/meeting chime are
   the P6 scope.
8. **Pause is model-true but unstyled.** The pause overlay is a bare
   card; a P8 polish pass should restyle HUD/overlay chrome across the
   game (P8 carries visual polish).
9. **Mystery of the two swells.** The chart's swell set is fixed; no
   chart variety or swell-cycling rule surfaces yet. → **P3 content**:
   G3 charts carry varied swell sets (MT-P3.1).
10. **No on-device performance telemetry beyond the overlay.** The G2
    probe found and fixed three render-loop defects (main-actor AI
    think, meter recreation, timer rebuild — see `docs/STATUS.md` G2
    evidence); the sustained-60 fps check now passes at real play
    pace, but the max-pace auto-pilot stress (no explicit `-aiDelay`)
    still dips to ~11 fps on the simulator, and P6's animated Metal
    field (ADR-0016) must re-verify the budget. → **P8 perf pass**
    (§7 budgets measured from real captures per the perf skill; P6
    re-measures with the wave field).

## Not weaknesses (verified in the slice)

- Preview == committed field (engine-owned preview; 500-placement test).
- Every committed action routes through the reducer (ADR-0005).
- Determinism: seed → identical replay; state hash stable (G1
  invariants carry over; the debug overlay shows the live hash).
- Save/resume mid-game works and is regression-tested (S2.4).
- Pause is S2.2-complete with unit-pinned semantics; restart and
  results verified in UI tests.
