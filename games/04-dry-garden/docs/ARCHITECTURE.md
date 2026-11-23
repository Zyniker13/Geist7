# Dry Garden — Architecture

P0 skeleton; the data-flow diagram grows with each phase.

## Modules

```
App (SwiftUI, iOS + macOS from one shared source set)
  ├── ContentView        placeholder menu; debug overlay host
  ├── LaunchArguments    -seed/-debugOverlay/-scenario/-startMatch parsing
  ├── DebugOverlay       S0.7: fps, tick, seed, state hash
  └── FPSMeter           CADisplayLink / CVDisplayLink frame counter
Packages/DGCore          pure Swift rules foundation (stdlib + Foundation only)
  ├── Foundation/        SeededRNG (SplitMix64), Fixed (Q32.32), Arithmetic
  ├── Lattice/           Hex (axial, ADR-0003), Axis (6 reflection families),
  │                      DistanceTable, Courtyard (mask parser, features, axes)
  └── Engine/            Replay, StateHashing (FNV-1a64 over sorted-keys JSON)
```

## Dependency direction (`_CONVENTIONS.md` §3.1)

`Core` ← `Content` ← `AI` ← `Meta` ← `Render`/`Audio`/`Platform` ← `App`.
DGCore imports nothing beyond the Swift standard library and Foundation
(`Codable`/`Data` only); `Tools/check-imports.sh` fails the build on any UI or
platform import, any banned nondeterminism API (`Date()`, `UUID()`,
`Int.random(in:)`, `SystemRandomNumberGenerator`), and (when the engine
arrives) any `Float`/`Double` computation in Core.

## Determinism contract (S0.2, S0.6)

All engine math runs on integer or `Fixed` (Q32.32 in `Int64`); randomness
only from `SeededRNG` (SplitMix64), passed explicitly. Every game records a
`Replay { seed, version, events, finalHash }`; `StateHashing.stableHash`
serializes with sorted keys and hashes with FNV-1a 64 — process-stable, so
replays verify byte-identical state across runs and devices.

## Threading model

UI on the main actor; the rules engine is synchronous and pure (no locks in
Core). The fps meter counts platform display-link callbacks off the main
thread behind an `NSLock` and publishes nothing.

## Save format

Codable JSON in Application Support (P2+, S2.4); the `Replay` type doubles as
the transport format for recorded games.
