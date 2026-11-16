# Rosette — docs/HANDOFF.md

## Handoff Package

*Updated at every gate.*

### Build Instructions
1. `cd games/07-rosette`
2. `make gen` — generates the Xcode project via XcodeGen
3. `make build` — builds for iOS Simulator and macOS
4. `make test` — runs unit tests and UI tests
5. `make lint` — runs SwiftLint, swift-format, check-imports, content-lint

### Architecture
- **RSCore:** Core types (SeededRNG, Fixed), game-state model, rules engine.
- **RSContent:** Game content (rulesets, pieces, boards, scenarios).
- **RSAI:** AI opponents (random, greedy, minimax).
- **RSRender:** SwiftUI views for board, pieces, UI, menus.
- **RSAudio:** Audio engine (AVFoundation), sound effects, music.
- **RSPlatform:** Platform abstraction (haptics, settings, file I/O).
- **RSMeta:** Meta game (scores, tavern ranking, achievements).

### Gate Checklist
- [ ] G0: Setup complete, empty app builds, tests pass, CI green
- [ ] G1: Core rules engine implemented, deterministic
- [ ] G2: UI shell with board and pieces
- [ ] G3: Full game loop (turn, scoring, win/loss)
- [ ] G4: AI opponents at all levels
- [ ] G5: Audio (SFX + music)
- [ ] G6: Platform features (haptics, settings, localization)
- [ ] G7: Meta game (scores, ranking, achievements)
- [ ] G8: Content (attested, reconstructed, invented)
- [ ] G9: Polish (animations, haptics, accessibility)
- [ ] G10: Release-ready (privacy policy, copyright, app store assets)

### Maintainer Issues
- (none yet)

### Open Questions
- (none yet)
