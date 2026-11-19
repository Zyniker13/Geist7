# Rosette — docs/HANDOFF.md

## Handoff Package

*Updated at every gate. Last updated: G7 (2026-11-18).*

### Build Instructions
1. `cd games/07-rosette`
2. `make gen` — generates the Xcode project via XcodeGen
3. `make build` — builds for iOS Simulator and macOS
4. `make test` — runs every package's tests (RSCore, RSAI, RSRender, RSContent, RSPlatform, RSMeta, RSAudio) plus the app UI tests
5. `make lint` — runs SwiftLint, swift-format, check-imports, content-lint

### Architecture
- **RSCore:** Deterministic core — `SeededRNG` (SplitMix64), `Fixed` fixed-point, the rules engine (`Board`/`Dice`/`Match`/`Wager`/`Engine`), the Ur solver and solved-table codec (`Solve`), the circuit economy (`Circuit`), headless match drivers (`Sim`: `BotMatch`, `RandomMatch`), and the odds calculator. `Reducer.apply` accepts an optional `DiceSource` so a fixed dice sequence can drive a match (daily-match replay, ADR-0012).
- **RSContent:** All content JSON in one home (`Resources/Content/`): 6 rulesets, 12 taverns, 12 opponents, 12 omens, 4 dice models, 4 fortune decks, 3 tutorial lessons, circuit + balance data. Loaded only through `ContentLoader`; validated by `content-lint` and `RSContentTests`.
- **RSAI:** `MatchBot` bots — `OptimalBot` (budgeted expectiminimax with table-equity fallback, ADR-0010), `VariantBot` (rollout-based), `RosetteBot` (heuristic, 3 personalities × strengths). G4 calibrated on the content circuit (ADR-0011): optimal completes 0.583, naive 0.083 at purse 80.
- **RSRender:** SpriteKit board scene + SwiftUI views (menu, game, circuit, history, tutorial, results). P6: `RegionTheme` per-region palettes (Ur pinned to RESEARCH.md §1) and `BoardArt` procedural board background + tavern backdrop, all geometry-only (ADR-0013).
- **RSAudio:** Procedural audio engine (AVFoundation) — `Synth` seeded instruments (lyre, drum, reed pipe, dice, chime, stinger), `MusicScore.tavernLoop` original D-Dorian loop, `AudioController` SFX + music with mute; headless-safe (silent no-op without an audio device).
- **RSPlatform:** Platform abstraction — `GameCenterService` (`GameCenterLike` protocol + `MockGameCenter`; real GameKit behind an entitlement, maintainer issue), `CloudStore` (`CloudStoreLike` + `InMemoryCloudStore`/`FileCloudStore` local stores; real CloudKit behind a container, maintainer issue), `AsyncMatchEngine` + `LocalMatchTransport` (server-agnostic async matches with the cube), `SolvedTableProvider` (ODR-shaped source with offline EMM fallback), `DailyResultStore` (30-day local daily results), haptics, settings, file I/O.
- **RSMeta:** Meta layer (ADR-0012) — `DailyMatch` (UTC-date-derived seed + 5,000-roll dice sequence; no wall clock, no UUIDs), `PlayerStats`, 20-achievement `AchievementCatalog`, `LocalLeaderboard` (daily wins, circuit purse), `MetaStore` (JSON persistence with corrupt-file fallback).

### Gate Checklist
- [x] G0: Setup complete, empty app builds, tests pass, CI green
- [x] G1: Core rules engine implemented, deterministic (INV-1–INV-5 evidence; RoyalUr cross-check)
- [x] G2: UI shell with board and pieces (iPad screenshot evidence)
- [x] G3: Full game loop (turn, scoring, win/loss); content counts met; 1,000 bot circuit runs without softlocks
- [x] G4: AI opponents at all levels (optimal circuit completion 0.583 in 55–70%; naive 0.083 in 5–15%; latency p95 0.037 s)
- [x] G5: Meta and replayability (daily identical for 30 dates; counts met: 6 rulesets, 12 taverns, 12 opponents, 12 omens; HANDOFF complete)
- [x] G6: Aesthetics and audio pass (SFX + music)
- [ ] G7: Platform features (Game Center daily + circuit purse, async matches with cube, iCloud, ODR solved table with offline fallback, Mac keyboard)
- [ ] G8: Polish, accessibility, and performance
- [ ] G9: Beta and TestFlight
- [ ] G10: Release-ready (privacy policy, copyright, app store assets)

### Maintainer Issues
- #5 rosette (P7): real Game Center account + leaderboard setup (`circuit-purse`, daily wins).
- #6 rosette (P7): CloudKit container + iCloud capability for real sync.
- #7 rosette (P7): ODR upload of the solved-table resource to App Store Connect.
- Earlier: macOS screenshot capture in headless CI.

### Open Questions
- OQ-004 (G4 purse calibration) — resolved in P4 (ADR-0011): purse 80, strengths Sumer 3 / Egypt 4 / Mexica 4.
- See `docs/OPEN_QUESTIONS.md` for the rest.
