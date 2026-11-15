# 01 — Ebru Roadmap

> Two marblers float pigment on a tray of thickened water, and every drop you add shoves your rival's color aside; when the paper is laid down, whoever owns more of the sheet wins.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 in full before starting. This roadmap adds only what is specific to Ebru.

Research: [`RESEARCH.md`](RESEARCH.md) (art direction, design lineage, cultural context, advisor institutions, verified glossary, and audio direction).

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 01 · `ebru` |
| Code prefix | `EB` (packages `EBCore`, `EBContent`, `EBAI`, `EBRender`, `EBAudio`, `EBPlatform`, `EBMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Fluid area-control abstract (two players, perfect information) |
| Difficulty tier | Approachable |
| Scope | Solo-indie |
| Session length | 5–12 minutes |
| Renderer | SpriteKit shell + Metal 4 fragment pass that rasterizes paint polygons with a paper and pigment shader (`EBRender/Bath`) |
| Players | Solo vs AI; local pass-and-play; async online (GameKit turn-based) |
| Simulation | Turn-based; continuous geometry in `Fixed` (no tick loop) |
| Sourcing tier | `FULL` (Ottoman and Turkish ebru, a living craft on UNESCO's Intangible Cultural Heritage list) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 and [`_SET2_ADDENDUM.md`](../_shared/_SET2_ADDENDUM.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** see above.
- **Summary:** A rectangular bath holds a thickened size. Two players alternate actions: drop pigment (three sizes) or draw a stroke (a stylus line or a comb of parallel tines). Mathematical marbling transformations move all existing paint: a drop pushes every point outward radially while preserving area; a stroke drags paint along its line with displacement that decays with distance. After a fixed move count, the paper is "laid" and the bath is scored by area per player, plus motif bonuses. The board is fully deterministic and every transformation can be previewed by scrubbing.
- **Pillars (gate and self-assessment tests):**
  1. **The bath is the board.** No grid, no hidden numbers; the visible paint is the complete game state. A reviewer can estimate the leader within 5 seconds of looking at a screenshot.
  2. **Every move moves everything.** Each action visibly changes the whole sheet; there are no local-only moves.
  3. **Preview before commit.** Every action can be previewed exactly (same math as Core) before it is committed.
  4. **A print worth keeping.** Every finished match exports as a 4096 px image a player would want to share.
  5. **Learn in one minute.** Two action types, one scoring rule, three motif cards.
- **Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Paper cream `#F2E8D5`, size (bath) `#E7DCC4`, Player 1 madder `#A8322D`, Player 2 indigo `#23395B`, neutral saffron `#E0A526` (motif accents and neutral drops in variants), oak-gall black `#2B2522` (combs, UI ink), shimmer highlight `#FFF7E6` (alpha 0.15). Color-blind alternates in P8 add hatching textures per player. |
| Shapes | Soft-edged pigment polygons with a 1–2 px darker rim (the "halo" ebru shows where pigment meets size); comb tines as thin oak-gall lines. |
| Typography | A humanist serif for titles (default: New York, system); SF Pro for UI numerals. |
| Motion | Drops bloom over 450 ms with an ease-out; strokes play at finger speed; the paper lay is a 1.2 s lift-and-peel animation. |
| Music | Solo ney flute improvisations over a soft tanbur drone; three stems added as the match progresses. |
| SFX | Brush tap per drop (pitch by size), water lap, comb drag hiss, paper peel. |
| Haptics | Light transient on drop; continuous texture while combing (Pencil Pro canvas haptics in P7); a long soft pulse on paper lay. |

- **Inspirations:** Ottoman marbling (water-based ebru before about 1617, gum-based baths from about 1608), Aubrey Jaffer's published mathematical marbling transformations, Yavalath's rule tension, Opus Magnum's GIF-friendly outputs and histograms, and Go's area-control clarity.

## 2. Tech Stack Decision

Per `_CONVENTIONS.md` §2 and `_SET2_ADDENDUM.md` §6, plus:

- **Paint model.** Each pigment drop is a closed polygon of `N` vertices (default 256) stored in `Fixed` coordinates in a bath of 1024 × 768 units. Transformations are applied to every vertex of every polygon, then polygons are adaptively resampled (insert a vertex where an edge exceeds `maxEdge`, remove where three consecutive vertices are within `minEdge` and collinear within tolerance) to keep shapes smooth. Paint order is a stack; later drops sit on top.
- **Ownership raster.** Scoring rasterizes the polygon stack into a 256 × 192 ownership grid (integer scanline fill, top-most polygon wins). Scoring is on this grid, so it is exact and deterministic.
- **Renderer.** A Metal fragment shader draws polygons from a vertex buffer with a paper texture, pigment granulation noise (seeded, not random), and rim darkening. Render reads Core polygons; it never transforms paint itself.
- **No tick loop.** Animations interpolate between the pre- and post-action polygon sets emitted in `[Event]`.
- ADRs to create in P0: ADR-0003 polygon paint model and resampling; ADR-0004 `Fixed.sqrt` and `Fixed.exp2` implementations with error bounds; ADR-0005 ownership raster resolution; ADR-0006 Metal paint shader contract (read-only from Core).

## 3. Repository Structure (Game-Specific Additions)

```
Packages/EBCore/Sources/EBCore/
  Foundation/  SeededRNG.swift, Fixed.swift, FixedMath.swift (sqrt, exp2, lookup tables), Vec2.swift
  Paint/       PaintPolygon.swift, PaintStack.swift, Resampler.swift, Shoelace.swift
  Transforms/  DropTransform.swift, LineStrokeTransform.swift, CombTransform.swift, Transform.swift (protocol)
  Score/       OwnershipRaster.swift, AreaScore.swift, Motif.swift, MotifDetectors.swift
  Engine/      GameState.swift, Action.swift, Event.swift, Reducer.swift, Variant.swift, RuleError.swift, LegalMoves.swift
Packages/EBContent/Sources/EBContent/ VariantDef.swift, MotifDef.swift, TrayDef.swift, PuzzleDef.swift, Loader.swift, Validation.swift
Packages/EBAI/Sources/EBAI/ CandidateGenerator.swift, Evaluator.swift, BeamSearch.swift, Minimax.swift, PuzzleSolver.swift, DailySheetGenerator.swift
Packages/EBRender/Sources/EBRender/ BathView.swift, Bath/PaintShader.metal, Bath/PaintRenderer.swift, PreviewOverlay.swift, PaperLayAnimation.swift, PrintExporter.swift
Packages/EBAudio/Sources/EBAudio/ NeyStems.swift, BrushSFX.swift
Packages/EBPlatform/Sources/EBPlatform/ GameCenterService.swift, TurnBasedService.swift, CloudSave.swift, PencilAdapter.swift, Haptics.swift
Packages/EBMeta/Sources/EBMeta/ DailySheet.swift, Histogram.swift, Ladder.swift, Stats.swift, PrintGallery.swift
Resources/Content/ variants.json, trays.json, motifs.json, puzzles.json, balance.json, tutorial.json, achievements.json, cultural_manifest.json
```

## 4. Core Rules Specification

Copy verbatim to `docs/RULES.md` in S0.5. Units: bath coordinates in `Fixed`; the bath is `W × H` (default 1024 × 768).

**Setup**
- R-1 The bath is empty at start. Player 1 (madder) moves first. The variant sets `movesPerPlayer` (default 9), the tray shape (rectangle by default; see `trays.json`), viscosity `v` (default 1.0), and the three motif cards dealt face up from `motifs.json` by seed.
- R-2 Each player has a drop inventory: 3 large, 4 medium, and 6 small drops by default, and unlimited strokes (subject to R-9).

**Actions** (exactly one per turn)
- R-3 `drop(center c, size s)`: `c` must lie inside the tray at least `r_s` from its edge (`r_small = 40`, `r_medium = 64`, `r_large = 96` units). Consumes one drop of size `s`.
- R-4 Drop transformation: for every vertex `p` of every existing polygon, `p' = c + (p − c) · sqrt(1 + r² / |p − c|²)`. A new polygon of the player's color, a circle of radius `r` around `c` with `N` vertices, is pushed on top of the stack. (Area of every existing polygon is preserved.)
- R-5 `stroke(from a, to b)`: a straight stylus line with `|b − a| ≥ 64`. For every vertex `p`, with `d` the perpendicular distance from `p` to the infinite line through `a` and `b` and `u` the unit vector from `a` to `b`: `p' = p + u · z · λ / (d + λ)`, where `z = strokeShift` (default 80) scaled by viscosity (`z = z₀ / v`) and `λ = strokeFalloff` (default 32).
- R-6 `comb(from a, to b, tines k, spacing g)`: `k` parallel strokes (k from 3 to 7, spacing g from 48 to 128 units) applied as one transformation where `d` is the distance to the nearest tine line. Combs cost a comb token; each player has 2 per game (variant-dependent).
- R-7 Strokes and combs must start and end inside the tray.
- R-8 `pass` is legal only if the player has no legal drop and no comb tokens and declines a stroke (UI hides it otherwise).
- R-9 Stroke ko: a player may not make a stroke whose direction is within 10° of exactly reversing the opponent's immediately preceding stroke along a line within 16 units of it (prevents undo loops).

**Resampling and clipping**
- R-10 After each transformation, every polygon is resampled (ADR-0003 tolerances). Vertices outside the tray are clamped to the tray boundary (paint piles at the tray wall). Polygons whose area falls below `minArea` (default 16 square units) are removed.

**End and scoring**
- R-11 The game ends after both players have taken `movesPerPlayer` turns. The paper is laid: the stack is rasterized into the ownership grid (R-12).
- R-12 Ownership grid: 256 × 192 cells; each cell takes the color of the top-most polygon covering its center, or `none`.
- R-13 Base score = number of owned cells.
- R-14 Motif bonuses (each card states its points): `tulip` (a single connected region of your color with exactly one concavity pointing to the tray bottom, detected per §7 algorithm), `comb band` (a horizontal strip ≥ 200 units wide where your color alternates with the rival's at least 6 times), `island` (a region of your color fully enclosed by the rival's color, area ≥ 2% of the tray), `margin` (you own the most cells in the outer 10% border). Each motif can be scored once per player.
- R-15 Highest total wins; tie → fewer drops used; tie → Player 2 wins (verify in sims).

**Invariants**
- INV-1 A drop transformation preserves each existing polygon's area within 0.5% before clamping (property test on 1,000 random seeds).
- INV-2 No polygon self-intersects after resampling (checked with a sweep-line test in debug and in property tests).
- INV-3 Owned cells for both players plus empty cells equal 256 × 192.
- INV-4 Replay determinism: same seed, variant, and actions produce the same polygon hash and score on every platform.
- INV-5 Preview equals commit: the preview path and the reducer produce identical polygon hashes for 1,000 random actions.

## 5. Data Schemas and Content Tables

```swift
struct Vec2: Codable, Hashable, Sendable { var x: Fixed; var y: Fixed }
struct PaintPolygon: Codable, Hashable, Sendable { var owner: PlayerID?; var vertices: [Vec2]; var bornTurn: Int }
struct GameState: Codable, Hashable, Sendable {
  var variantID: String; var tray: TrayShape; var viscosity: Fixed
  var stack: [PaintPolygon]; var toMove: PlayerID; var turn: Int
  var drops: [PlayerID: DropInventory]; var combTokens: [PlayerID: Int]
  var lastStroke: StrokeRecord?; var motifs: [String]; var rng: SeededRNG
}
enum Action: Codable, Hashable { case drop(Vec2, DropSize), stroke(Vec2, Vec2), comb(Vec2, Vec2, tines: Int, spacing: Fixed), pass }
enum Event: Codable { case dropped(PlayerID, Vec2, DropSize), stroked(PlayerID, Vec2, Vec2), combed(PlayerID, Vec2, Vec2, Int, Fixed),
  polygonsRemoved([Int]), paperLaid(OwnershipSummary), motifScored(PlayerID, String, Int), gameOver(PlayerID?, ScoreBreakdown) }
```

Content tables and required counts (G3 / G5):

| Table | G3 | G5 | Sample row |
| --- | --- | --- | --- |
| `variants.json` | 4 | 10 | `{ "id": "classic", "movesPerPlayer": 9, "tray": "rect_4x3", "viscosity": 1.0, "drops": {"large":3,"medium":4,"small":6}, "combTokens": 2, "motifCount": 3 }` |
| `trays.json` | 3 | 8 | `{ "id": "rect_4x3", "kind": "polygon", "points": [[0,0],[1024,0],[1024,768],[0,768]] }` |
| `motifs.json` | 4 | 10 | `{ "id": "tulip", "points": 60, "detector": "tulip_v1", "cultural": true, "nameKey": "motif.tulip" }` |
| `puzzles.json` | 20 | 80 | `{ "id": "p001", "variant": "classic", "start": "<GameState>", "goal": "win_by_10", "plies": 2, "solution": [ ... ] }` |
| `tutorial.json` | 5 lessons | 6 lessons | `{ "id": "t1_drop", "steps": [ {"prompt": "tut.drop.1", "expect": {"action":"drop"}} ] }` |

Variant families required by G5: Classic, Gum Thick (viscosity 1.6: strokes move less), Gum Thin (0.7), Hatip (center-only drops), Comb Duel (4 comb tokens, fewer drops), Bouquet (neutral saffron drops pre-placed), Long Sheet (2:1 tray), Round Tray, Short (6 moves), and Seeded (parameters drawn within ranges by seed).

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| `movesPerPlayer` | 9 | 6–12 | `variants.json` |
| `r_small / r_medium / r_large` | 40 / 64 / 96 | 24–128 | `balance.json` |
| `strokeShift z₀` | 80 | 40–140 | `balance.json` |
| `strokeFalloff λ` | 32 | 16–64 | `balance.json` |
| `combTokens` | 2 | 0–4 | `variants.json` |
| `motif points` | 40–80 | 20–120 | `motifs.json` |
| `polygon N` | 256 | 128–512 | `balance.json` |

Targets (Strong vs Strong, 2,000 games per variant): first-player win rate 47–53%; median final margin 4–12% of the tray; motif points decide 15–35% of games; no single action type used more than 70% of the time by the Strong AI.

## 7. AI Approach

- **Candidate generation.** Moves are continuous, so `CandidateGenerator` samples a fixed lattice plus targeted points: drop centers on a 16 × 12 lattice, plus centroids of rival regions, plus boundary points between colors; strokes along 8 directions through the top 12 boundary points; combs at 4 orientations × 3 spacings. About 300–600 candidates per position, generated deterministically.
- **Evaluation (integers):** owned cells × 10 on a coarse 64 × 48 raster; plus motif progress estimators (tulip concavity score, island enclosure ratio); minus exposure (own area within one stroke falloff of a straight rival boundary) × 4; plus remaining drop inventory × per-size weights.
- **Tiers:** Apprentice (1-ply greedy over 100 sampled candidates, 20% noise among top 5), Journeyman (1-ply over all candidates), Master (2-ply beam search, beam 24, 1.0 s budget), Usta (3-ply beam 16 with full raster for the last two plies, 2.0 s). Deterministic for a fixed node budget; time budget only truncates at iteration boundaries.
- **Puzzle generator.** From Master-vs-Master games, pick positions with ≤ 2 moves left where the best move beats the second-best by ≥ 5% of the tray; verify by exhaustive evaluation of the full candidate set at both plies; store with rating by margin gap.
- **Daily sheet.** Seed per `_SET2_ADDENDUM.md` §6 selects variant, tray, motifs, and the AI's opening drop. Everyone plays the same sheet against Master; the score is the final margin. Histograms (not leaderboards) show where you landed.

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7, SRC0.1, SRC0.2, and HIST0.1.
- EB-P0.1 `Fixed.sqrt`, `Fixed.exp2`, and reciprocal with known-answer vectors (≥ 200 values each) and max error documented in ADR-0004. Acceptance: relative error ≤ 2⁻²⁴ over the bath's numeric range.
- EB-P0.2 `Vec2` and shoelace area with 128-bit intermediates. Acceptance: exact area for 50 integer polygons.

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks
  [ ] Fixed math vectors pass; ADR-0004 records error bounds
  [ ] SRC0.1, SRC0.2, and HIST0.1 files exist; manifest lint fails on the deliberate fixture
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- EB-P1.1 Drop transform (R-3, R-4) with area-preservation property test (INV-1). Deliverable: `DropTransform.swift`, tests.
- EB-P1.2 Stroke and comb transforms (R-5 to R-7), stroke ko (R-9). Acceptance: 40 hand-checked vertex fixtures.
- EB-P1.3 Resampler and clamping (R-10) with self-intersection checker (INV-2). Acceptance: 1,000 random 9-move games with zero self-intersections.
- EB-P1.4 Ownership raster and scoring (R-11 to R-15), including the four motif detectors with ≥ 8 positive and 8 negative fixtures each.
- EB-P1.5 `Tools/sim` prints final ownership as ASCII art for debugging.

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-15 tagged tests pass; INV-1…INV-4 hold over 1,000 seeds
  [ ] EBCore coverage ≥ 90%
  [ ] make sim N=1000: 0 crashes; identical hashes on two runs and on macOS vs iOS simulator
  [ ] A full 18-action game resolves in < 40 ms CPU on the Mac CI runner
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5, SRC2.1, and SRC2.2.
- EB-P2.1 `BathView` with the Metal paint shader (placeholder quality) drawing Core polygons at 120 Hz.
- EB-P2.2 Input: press and hold to grow a drop through the three sizes (size ring shows), release to preview, tap the confirm chip to commit; drag to draw a stroke; a comb button switches drag mode to comb with a tines/spacing dial. Mac: click-hold for drops, drag for strokes, scroll to change size.
- EB-P2.3 Live preview using the Core transform on a copy (INV-5); scrub slider to replay the match's history.
- EB-P2.4 Opponent: Journeyman AI.
- EB-P2.5 Paper-lay animation and score screen with area bars and motif ticks.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test plays a full Classic game vs Journeyman to the score screen on iPad and Mac
  [ ] INV-5 (preview equals commit) passes on 1,000 random actions
  [ ] Paint renders at ≥ 60 fps in the iPad simulator debug overlay with 30 polygons
  [ ] Resume mid-game to an identical hash
  [ ] Cultural manifest covers all placeholders; deny-list lint passes
  [ ] `docs/SLICE_ASSESSMENT.md` written: self-assessment against the pillars, with every weakness turned into a P3 task (`_CONVENTIONS.md` §8.1)
Sign-off: GLM-SELF
```

### P3 Content and Systems
- EB-P3.1 Four variants, three trays, and four motifs (G3 counts) with a rules card per variant.
- EB-P3.2 Tutorial: five lessons (drop, push, stroke, comb, motif) from `tutorial.json`; no text walls, each lesson ≤ 3 prompts.
- EB-P3.3 Pass-and-play with a "hand over" screen and board rotation on iPad.
- EB-P3.4 Casual undo (one step), disabled in ranked, daily, and async.
- EB-P3.5 About the Tradition screen (SRC3.1) and HIST3.1 labels on every historical note.
- EB-P3.6 Print export: 4096 × 3072 PNG of the final sheet with a small signature cartouche (player names, date, and variant).

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts in §5 for G3 met; content-lint 0 errors
  [ ] 1,000-game sims per variant: 0 crashes, motif detectors fire in 5–60% of games each
  [ ] Tutorial UI test passes; print export snapshot approved
Sign-off: GLM-SELF
```

### P4 AI Opponents
- EB-P4.1 All four tiers (§7) with deterministic node budgets.
- EB-P4.2 Puzzle generator and solver; `Tools/sim puzzles --count 200`.
- EB-P4.3 `docs/BALANCE.md` with win rates by variant and tier.

```
GATE G4 — AI
Checks:
  [ ] Each tier beats the tier below ≥ 70% over 500 games
  [ ] Master p95 ≤ 1.0 s and Usta p95 ≤ 2.0 s (Mac measured; iPad simulator reported)
  [ ] 500-game soak per tier: 0 illegal actions
  [ ] First-player win rate 47–53% on Classic (or ADR with tuning)
  [ ] ≥ 120 verified puzzles generated
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- EB-P5.1 Daily sheet with local histogram (bucketed margins from a precomputed 10,000-game Master-vs-Master distribution, replaced by Game Center data in P7).
- EB-P5.2 Ladder of 12 named marbling studios (AI tiers plus variants); each win unlocks a paper texture or pigment set (cosmetic only).
- EB-P5.3 Remaining variants, trays, motifs, and puzzles to G5 counts; Seeded variant mode.
- EB-P5.4 Print Gallery of saved sheets (local, up to 200) and 24 achievements.
- EB-P5.5 SRC5.1 sourcing review packet.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Daily sheet identical across devices for 30 simulated dates
  [ ] G5 content counts met; all variants pass 1,000-game sims
  [ ] Ladder completes in a scripted UI test with the debug auto-win flag
  [ ] Coverage thresholds met (Core ≥ 90%, AI ≥ 75%, Meta ≥ 75%)
  [ ] docs/SOURCING_REVIEW_PACKET.md lists 100% of manifest entries; zero restricted elements
  [ ] docs/HANDOFF.md complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- EB-P6.1 Final paint shader: granulation, rim halo, paper fiber, and tilt-based shimmer (Core Motion, cosmetic only).
- EB-P6.2 Drop bloom and paper-lay animations polished; Reduce Motion variants.
- EB-P6.3 Ney and tanbur stems recorded or licensed (any spend is a maintainer item filed as an issue; placeholders until then); SFX set.
- EB-P6.4 SRC6.1 and SRC6.2: advisor review (a practicing ebru artist; the maintainer engages through a `needs-maintainer` issue); motif names and the About text revised.

```
GATE G6 — Aesthetics
Checks:
  [ ] 120 fps on iPad Pro 13-inch (M5) with 60 polygons; 60 fps on iPad (base)
  [ ] Snapshot set approved by GLM against the §1 aesthetic spec (`_CONVENTIONS.md` §8.2)
  [ ] Advisor review filed as a `needs-maintainer` issue (SUBSTITUTED, `_SET2_ADDENDUM.md` §4); every entry still pending advisor review listed in that issue
Sign-off: GLM-SELF
```

### P7 Platform Features
- EB-P7.1 Game Center: daily-sheet leaderboard (margin), ladder progress, 24 achievements, and a daily Game Center challenge.
- EB-P7.2 Turn-based async matches (state is small: actions list plus seed).
- EB-P7.3 iCloud sync for profile, ladder, gallery metadata, and in-progress games.
- EB-P7.4 Pencil: hover previews drop or stroke; pressure controls drop size as an alternative to hold; Pencil Pro barrel roll rotates the comb; canvas haptics as tines cross color boundaries. Finger fallback for all.
- EB-P7.5 Mac: menus, ⌘Z casual undo, window resizing (bath letterboxes), and share-sheet print export.

```
GATE G7 — Platform
Checks:
  [ ] Async match between two sandbox accounts completes
  [ ] iCloud round-trip iPad ↔ Mac preserves an in-progress game hash
  [ ] Every Pencil feature has a finger equivalent (checklist in docs/STATUS.md)
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- EB-P8.1 Player colors also distinguished by texture (madder diagonal hatch, indigo dots) toggled in Settings and on by default under Differentiate Without Color.
- EB-P8.2 VoiceOver: "Score: you 41%, rival 37%"; a coarse 8 × 6 region rotor announcing owner and contested regions; actions via a VoiceOver custom action menu (drop at selected region center, stroke from region to region).
- EB-P8.3 One-finger alternatives for every gesture; adjustable hold duration; Reduce Motion.
- EB-P8.4 Real-device performance per conventions §7.

```
GATE G8 — Polish
Checks:
  [ ] Simulated deuteranopia, protanopia, and tritanopia screenshots reviewed
  [ ] VoiceOver completes a full game in a UI test
  [ ] Performance budgets met; cold start < 2.0 s
Sign-off: GLM-SELF
```

### P9 Beta and TestFlight
- Standard P9 tasks; SRC9.1 community playtest prepared (tester guide, build notes) and filed as a `needs-maintainer` issue.
- EB-P9.1 Re-rate puzzles and retune motif points from opt-in stats exports.

```
GATE G9 — Beta
Checks:
  [ ] Crash-free sessions ≥ 99.5%; no open S1/S2 issues
  [ ] First-player win rate in beta games 45–55%
Sign-off: GLM-SELF
```

### P10 Release Prep
- Standard P10 tasks; SRC10.1.
- EB-P10.1 App preview video built from real exported matches; screenshots show finished prints.

```
GATE G10 — Release
Checks:
  [ ] Store assets approved; final CI green
  [ ] SRC10.1 credits draft complete and filed as a `needs-maintainer` issue
Sign-off: GLM-SELF
```

## 9. Fragile Areas and Priorities

- **Fragile areas:** resampling tolerances (too coarse and motifs misfire; too fine and performance drops); clamping at tray walls; stroke ko geometry; preview/commit parity.
- **Priorities for P6–P10:** Metal shader performance with many polygons; VoiceOver action menu; async payload format; motif point values, viscosity variants, and AI candidate coverage (watch for the AI ignoring combs).

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Fixed-point drift creates platform hash mismatches | Medium | High | All math in `Fixed`; cross-platform golden replays in CI | GLM |
| Late strokes dominate (last-mover advantage) | High | High | Stroke ko, comb tokens, Player 2 tie-break, and sims | GLM |
| AI too weak in continuous space | Medium | Medium | Targeted candidates plus beam search; puzzles test it | GLM |
| Players cannot read who leads | Medium | High | Live area bar and contested-region shimmer | GLM |
| Cultural flattening of ebru | Medium | High | `FULL` sourcing tier; advisor review issue filed in P0; content stays pending until answered | GLM |

## 11. Out of Scope

Free-form painting mode without rules; more than two players; real fluid simulation (Navier–Stokes); physical print-on-demand; online chat; Vision Pro.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 2–3 |
| P1 | GLM | 6–9 |
| P2 | GLM | 7–10 |
| P3 | GLM | 5–7 |
| P4 | GLM | 6–9 |
| P5 | GLM | 5–7 |
| P6 | GLM | 8–12 |
| P7 | GLM | 5–7 |
| P8 | GLM | 4–6 |
| P9 | GLM | 4–6 |
| P10 | GLM | 2–3 |
| **Total** | | **54–79** |

## 13. Open Questions

1. Should a single-player "free marbling" sandbox ship? Default: no for v1.0.
2. Should the daily sheet be one attempt or unlimited? Default: one ranked attempt, unlimited practice.
3. Which advisor(s) and what compensation or revenue share? Default: GLM prepares the packet and files a `needs-maintainer` issue; the maintainer decides.

## 14. Sourcing Notes

- **Tradition:** Ottoman and Turkish ebru (paper marbling), inscribed by UNESCO as Intangible Cultural Heritage of Türkiye in 2014.
- **Sources to seed `docs/SOURCING.md`:** Netherlands Institute in Turkey lecture on the early development of paper marbling in the Islamic world; DergiPark articles on early Ottoman archival ebru; Jaffer's mathematical marbling papers (for the transforms).
- **Restricted elements:** do not reproduce calligraphic religious texts (for example, verses or divine names) inside marbled borders; do not use the names of living masters without consent.
- **Glossary seeds (statuses in the research file; pending advisor):** ebru, ebrucu (marbler), tekne (tray), battal (base pattern), gelgit (back-and-forth pattern), öd (ox gall) — verified; hatip ebrusu, lale (tulip) ebrusu, taraklı (combed), and kitre (gum tragacanth) — secondary sources.
- **Historical labels:** water-based early ebru and the shift to gum baths are Attested; motif scoring rules are Invented for play.
