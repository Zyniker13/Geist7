# Dry Garden — Coverage

Coverage is generated with `swift test --enable-code-coverage` (packages) and
`xcrun xccov`/`llvm-cov` reports, summarized here by `make coverage`.
Thresholds (`_CONVENTIONS.md` §5): Core ≥ 90%, AI ≥ 75%, Meta ≥ 75%, overall
≥ 60%.

## Current (P0)

| Package | Coverage | Notes |
| --- | --- | --- |
| DGCore | measured at G1 | P0 delivers the lattice/courtyard/laws foundation with 50 tests; the full Core suite (rules engine) lands in P1, when the ≥ 90% gate threshold first applies |

Uncovered critical functions: none yet (no rules engine yet).
