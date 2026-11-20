# Mattang — docs/DECISIONS.md

ADR log. Toolchain facts: Xcode 27.2, Swift 6 (strict concurrency `complete`), targets iOS/iPadOS 26.0 and macOS 26.0, XcodeGen project generation, SpriteKit rendering with a Metal 4 compute visual layer planned (P6).

## ADR-0001: Toolchain (Xcode 27.2, Swift 6 strict)

Adopted the installed toolchain: Xcode 27.2 (`xcodebuild -version` recorded in docs/STATUS.md evidence), Swift 6 language mode with strict concurrency `complete` for every package and app target. Reason: `_CONVENTIONS.md` §2 requires reproducible builds on the installed toolchain; strict concurrency catches data races before P1's parallel tracing work. Consequence: closure-valued `static let` properties are rejected; shared functions are `static func` (e.g. `Hex.opposite`).

## ADR-0002: Stack per §2

Adopted the conventions stack with the roadmap's additions: one code base, SwiftUI app shell (two targets, one source set), SpriteKit in `SpriteView` for the board, MTCore/MTContent/MTAI as pure deterministic Swift packages, MTPlatform as the only layer that imports UIKit/AppKit, MTMeta for the meta layer. Dependencies: none beyond the allow-list (no third-party packages at P0).

## ADR-0003: Discrete swell model

Core models swells as discrete straight rays on the axial hex grid, integer-only, up to 3 reflections per ray and 40 steps (R-3–R-5). No continuous wave physics in Core. Reason: determinism (INV-1, INV-4), testability against fixed fixtures, and sub-millisecond field updates for AI search. The continuous interference look is render-only (ADR-0005).

## ADR-0004: Reflection and refraction table

Reflection is computed by the closed-form `(2n − d + 3) mod 6` (R-12) and cross-checked at test time against the 6×6 hand table committed in `InteractionTable.swift` (36 cases). Vertex hits reverse (`d + 3`). Refraction (R-13, R-14) turns one step toward the island, ties clockwise, resolves double-island ties by lower row-major cell index. Reason: a single closed form avoids table/maths divergence; the hand table keeps the formula honest.

## ADR-0005: Visual field decoupled from Core

The Metal compute wave-field visual (P6) is driven by Core's ray set as render-only data and is never read back into Core state. Reason: Core must stay integer-only and deterministic; the shimmer/interference look is presentation. Gate evidence (G2/G6) shows preview and committed fields matching Core exactly.

## ADR-0006: Lint toolchain reconciliation

`swift-format` 604 (as installed) with the shared `.swift-format` config; SwiftLint `--strict` with custom rules for banned APIs (`SystemRandomNumberGenerator`, `Int.random`, `Date()`, `UUID()` in Core/Content/AI) as error severity, mirrored by `Tools/check-imports.sh` grep. Reason: both linters stay green in CI on macos-latest.
