# Mattang — Architecture

## Packages

| Package | Role | Imports allowed |
| --- | --- | --- |
| MTCore | Deterministic rules: grid, swells, engine, replay | Foundation only |
| MTContent | Content defs + bundled JSON resources | Foundation, MTCore |
| MTAI | Evaluation, search, puzzle generation | Foundation, MTCore, MTContent |
| MTRender | SpriteKit scene, Metal wave field (P6) | SpriteKit, Metal, MTCore, MTContent |
| MTAudio | Sound and music (P6) | AVFoundation, MTRender |
| MTMeta | Daily chart, voyages, stats | Foundation, MTCore, MTContent |
| MTPlatform | Device glue: haptics, launch args bridge | UIKit/AppKit, everything above |

App targets (`Mattang-iOS`, `Mattang-macOS`) share `App/Shared` sources. Tests: SPM tests under `Packages/*/Tests`, app smoke/UI tests under `Tests/`.

## Rules of the layering

- MTCore never imports Foundation date/random APIs; all randomness is `SeededRNG`, all math is `Fixed` (ADR-0003).
- Only MTPlatform imports UIKit/AppKit; `check-imports.sh` enforces this.
- MTContent owns all JSON resources; nothing else reads the bundle (single content home).
- The Metal visual layer consumes Core output only (ADR-0005).
