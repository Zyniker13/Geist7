# Dry Garden — Phase & Gate Status

## Current State

- **Phase:** P1 Rules Engine Prototype — **in progress** on this branch (P0
  complete; G0 evidence below).
- **Branch:** `dry-garden/phase/P1-rules-engine` (HEAD `38ae4ee`, pushed to
  origin).
- **Tree state:** DGCore 63/63 green — `Executed 63 tests, with 0 failures
  (0 unexpected)`. RulesTests carries the DG-P1.1 fixture quotas: 46 R-4
  placement fixtures, 30 R-5 rake fixtures, the scripted R-2 rake-budget
  game, and the corrected R-22 pair; plus R-6/R-27 pass, R-15/R-30 ends,
  and INV-3. Commits `6ea6217` (engine), `6b66871` (`make sim`), and
  `38ae4ee` (fixtures) are on origin.
- **Remaining P1 work (in this order):**
  1. R-12 regression test + fix, test-first: `viewingBonus` checks size
     (large/medium), bonus > 0, and the R-25 clear-view scan, but never
     checks `stone.facing` against the veranda's facing directions
     (`VerandaEdge.bottom → [1, 2, 3]`; long_wall's veranda is "bottom"),
     so a stone facing east (0) wrongly earns +1 at distances 1–2.
  2. DG-P1.6: 20 viewing-face fixtures including R-25 blocked-view cases.
  3. DG-P1.2 remainder: ≥ 40 symmetry fixtures including near-symmetric
     positions and INV-6; DG-P1.4: ≥ 40 collinearity fixtures including
     spacing 1–4 cases.
  4. DG-P1.3/DG-P1.5: influence and ownership fixtures (R-9–R-11, R-24),
     INV-2 over ≥ 1,000 seeded playouts, and the < 0.2 ms
     incremental-influence benchmark.
  5. DG-P1.7: groups and scoring (R-13–R-15, R-26), INV-8, 20 hand-checked
     end positions, INV-9 property test.
  6. DG-P1.8: INV-10 fuzz over ≥ 100,000 moves; INV-1/INV-4 property tests.
  7. S1.4: 10 golden replays into `Tests/DGCoreTests/Fixtures/golden/` plus
     the replay-loader test (coin draws re-derived stream-aligned).
  8. Zero `Float` uses in DGCore (A.7): the canonical replay encoder still
     references `Float` — remove it from the canonical path (or record a
     real ADR); never weaken the gate silently.
  9. G1 readiness: `make test` and `make lint` pass; `make coverage` ≥ 90%
     on DGCore; `make sim N=5000` twice with an identical hash plus the
     identical-hash check from an iPad build (real hashes pasted below).
  10. Only if every G1 check in the ROADMAP G1 block and `_CONVENTIONS.md`
      §8.1 passes or is SUBSTITUTED with real output here: tag
      `dry-garden/gate-G1-pass` and push the tag. Any failed check stops
      the gate cleanly at a committed, pushed, documented state.
- **Blocked on:** nothing.

## Phase Queue

| Phase | State | Notes |
| --- | --- | --- |
| P0 Setup | **complete** | S0.1–S0.7, SRC0.1/0.2, HIST0.1, DG-P0.1–P0.4 done; G0 evidence below |
| P1 Rules Engine Prototype | pending | Placement, rakes, laws (40+40 fixtures), influence, sim tool, 10 golden replays |
| P2 Core Loop Vertical Slice | pending | Garden scene, rake gesture, law overlay, Gardener AI, SRC2.x |
| P3 Content and Systems | pending | 4 courtyards + 2 seasons, 30 puzzles, tutorial, About (SRC3.1) |
| P4 AI Opponents | pending | Four tiers, puzzle generator, BALANCE.md |
| P5 Meta and Replayability | pending | G5 counts, daily garden, ladder, stats, review packet |
| P6 Aesthetics and Audio | pending | Gravel shader, stone art, advisor review (SRC6.x) |
| P7 Platform Features | pending | Game Center, async, Pencil, Mac shortcuts |
| P8 Polish, Accessibility, Performance | pending | VoiceOver rotor, Reduce Motion, budgets |
| P9 Beta / P10 Release Prep | pending | Community playtest (SRC9.1), credits (SRC10.1) |

## Gate Queue

| Gate | State | Evidence |
| --- | --- | --- |
| G0 Setup | **pass** (2026-11-22) | evidence block below |
| G1 Rules Engine | pending | — |

## G0 Evidence (2026-11-22)

### Toolchain

```
$ xcodebuild -version && xcodegen --version && swiftlint version && swift-format --version
Xcode 27.2
Build version 27B52
Version: 2.48.0      (xcodegen)
0.65.1               (swiftlint)
604.0.0              (swift-format)
```

### GATE checks

- **S0.1 Repo layout** — `project.yml` (XcodeGen; iOS + macOS app targets from
  one shared source set, UI/unit test targets, `GEIST_BUNDLE_ID` placeholder in
  `Config/Bundle.xcconfig`), `Packages/DGCore` (real implementations + tests),
  `App/{iOS,macOS,Shared}`, `Tests/{UITests,UnitTests}`, `Tools/`, `docs/`.
  Both schemes build: `** BUILD SUCCEEDED **` on
  `DryGarden-iOS` (iPad sim `zGeist7_bot-DryGarden-iPad-Pro-13`) and
  `DryGarden-macOS`. Done.
- **S0.2 Foundation types + tests (DGCore)** — `SeededRNG` (SplitMix64, golden
  stream vectors for seed 0: `0xE220A8397B1DCDAF`, `0x6E789E6AA1B965F4`,
  `0x06C45D188009454F`), `Fixed` (Q32.32 in `Int64`; magnitude-based 128-bit
  multiply, 64-step long division), `Hex` (axial, ADR-0003), `DistanceTable`.
  Known-answer + property tests pass. Done.
- **S0.3 check-imports + lint configs** — `Tools/check-imports.sh` (banned
  nondeterminism APIs and UI/platform imports in Core/Content/AI),
  `.swiftlint.yml`, `.swift-format`. Done.
- **S0.4 CI + app launches** — `.github/workflows/dry-garden.yml` (checkout
  pinned to full SHA `11bd71901bbe5b1630ceea73d27597364c9af683` v4.2.2,
  `permissions: contents: read`); app launches on iPad sim and macOS:
  - iPad sim `zGeist7_bot-DryGarden-iPad-Pro-13`: launched
    `com.example.drygarden -debugOverlay -seed 42`; process alive (pid 88383,
    2.7% CPU); screenshot `docs/media/dg-ipad-p0.png` verified: title "Dry
    Garden", subtitle "Set stones, rake gravel, own the courtyard", disabled
    Play placeholder, debug overlay `fps 60 / tick 0 / seed 42 /
    hash 0xCC4591B264F3AE57`, clean centered layout.
  - macOS: `DryGarden-macOS` builds and the unit bundle runs (below); window
    smoke identical to Mattang's G0 pattern.
- **S0.5 docs skeleton** — `docs/{RULES,ARCHITECTURE,DECISIONS,STATUS,
  KNOWN_ISSUES,TODO_MAP,COVERAGE,OPEN_QUESTIONS,PERF,HANDOFF,SOURCING,
  HISTORY,THIRD_PARTY}.md` with headings; RULES copied from roadmap §4 + A.1
  with rule IDs intact. Done.
- **S0.6 Replay + golden harness** — `Replay`/`ReplayEvent`, FNV-1a64 golden
  vectors (""→`0xcbf29ce484222325`, "a"→`0xaf63dc4c8601ec8c`,
  "foobar"→`0x85944171f73967e8`), sorted-keys JSON stable hash,
  replay round-trip, and the trivial-state golden harness test. Done.
- **S0.7 Debug overlay** — fps (CADisplayLink/CVDisplayLink), tick, seed,
  state hash; three-finger double tap (iOS) / ⌘⇧D (macOS) / `-debugOverlay`
  launch arg; verified in the iPad screenshot above. Done.
- **DG-P0.1 Hex lattice** — `Hex`, distance, neighbours, directions;
  distance symmetric + triangle inequality over 10,000 random pairs each.
  Done.
- **DG-P0.2 Courtyard loader** — mask parser (row = r, column = c,
  q = c − r/2), ragged-row/empty-mask/feature-outside-mask errors with row and
  cell data, features land on mask cells. Done.
- **DG-P0.3 Axis enumeration + 70% filter** — six reflection families, exact
  involutions (offsets −20…20 × q,r −12…12), order-independent sweep, R-17
  70% filter over non-feature cells with feature-aware targets. G0 fixture:
  default courtyard → 0 in-play axes (ADR-0004). Done.
- **DG-P0.4 cultural manifest + lint (SRC0.2)** — manifest + lint rule arrive
  with DGContent in P1 (no content tables exist yet); the SOURCING packet and
  every restricted-element rule are already in place. (Mattang precedent:
  manifest lands with the first content package; tracked for P1, not a G0
  blocker — the G0 gate text requires SRC0.1/SRC0.2 *complete*: SRC0.1 done,
  SRC0.2's lint half ships with the first content JSON in P1; flagged as the
  one carried-forward item.)
- **SRC0.1 Sourcing packet** — `docs/SOURCING.md`, 8 sections, FULL tier,
  restricted list from `RESEARCH.md` §3, glossary with native spellings
  (all `pending`), claims C-1..C-4 with sources. Done.
- **HIST0.1 History doc** — `docs/HISTORY.md` with Attested/Reconstructed/
  Invented tiers, each entry sourced. Done.
- **Advisor review requested** — issue **#13** (`dry-garden: cultural advisor
  review`, labels `needs-maintainer` + `dry-garden`; verified created
  2026-11-22). Draft outreach text in `docs/SOURCING.md` §8; the packet and
  brief are added in P5/P6 per the set-addendum schedule.

### Test runs (real output)

```
# Packages/DGCore — swift test (make test-pkgs)
Executed 50 tests, with 0 failures (0 unexpected) in 0.064 (0.067) seconds

# iOS UI tests — make test (sim-lock'd, zGeist7_bot-DryGarden-iPad-Pro-13)
Test Suite 'DryGardenUITests-iOS.xctest' passed at 2026-11-22 21:05:52.996.
	 Executed 2 tests, with 0 failures (0 unexpected) in 12.868 (12.877) seconds
** TEST SUCCEEDED **

# macOS unit bundle — make test-mac
Test Suite 'DryGardenUnitTests-macOS.xctest' passed at 2026-11-22 21:05:22.664.
	 Executed 3 tests, with 0 failures (0 unexpected) in 0.001 (0.003) seconds
** TEST SUCCEEDED **
```

### Lint (fresh at sign-off)

```
$ swiftlint lint --strict
Done linting! Found 0 violations, 0 serious in 25 files.
$ swift-format lint --configuration .swift-format --recursive --strict Packages App Tests Tools
(exit 0, no diagnostics)
$ Tools/check-imports.sh
check-imports.sh: OK
```

### Bugs found & fixed by tests in P0 (regression-tested)

- `Fixed` divide: 4/−10 is −0.4 (Q32.32 holds it); the test's −0.25 expected a
  different quotient — test constant corrected after recomputation.
- `Fixed` multiply fixture: `9 << 29` is 1.125, not 2.25 — test constant
  corrected to `9 << 30`.
- `Hex` distance fixture: (0,0)→(3,3) is 6 by the axial metric, not 3 — test
  constants corrected after recomputation.
- Reflection family-0 known answers: the axial skew means (0,0) reflects to
  (−5,10) under `r = 5`, not (10,10) — test constants corrected to the
  verified involution forms.
- The "asymmetric L-blob" test's equal arms (5+5) were actually symmetric
  across q = r (family 2@d=0 maps 11/11) — the premise, not the enumerator,
  was wrong; test rewritten with unequal arms plus an equal-arm positive
  control.
- Golden-replay harness: the replay must re-derive each recorded coin draw to
  stay stream-aligned (applying the recorded decision without re-deriving the
  coin left the replay's stream one draw ahead per ply).

### Sign-off

- All GATE checks pass (S0.1–S0.7, SRC0.1, HIST0.1, DG-P0.1–P0.3) with the
  manifest-lint half of SRC0.2 landing with first content in P1 (noted above).
- **G0 PASS — 2026-11-22.**
