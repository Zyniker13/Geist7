# Rosette — docs/KNOWN_ISSUES.md

Each issue: severity (S1 crash/data loss, S2 wrong rule, S3 visual/UX, S4 minor), reproduction steps, and a suspected cause.

## S4 — SwiftLint excludes `App/`

- **Severity:** S4 (tooling gap, no runtime effect)
- **Repro:** `swiftlint lint` inside `games/07-rosette` skips every file under `App/` (see `.swiftlint.yml` `excluded:`).
- **Suspected cause:** the P0-era placeholder App sources trip SwiftLint's line-length and formatting rules; they were excluded to keep lint green when the P2 App shell landed.
- **Plan:** fix the App sources' formatting and remove the exclusion in P8 polish. SwiftFormat still lints `App/`, so formatting coverage is not lost.

## S4 — `content-lint` checks are skeletons

- **Severity:** S4 (lint completeness; no content exists yet to check)
- **Repro:** `Tools/content-lint/run.sh` prints skeleton messages for its three checks (hardcoded UI strings, asset metadata, copyrighted content).
- **Suspected cause:** P0 scaffold placeholder; the real checks land with P3 content (`TODO(RS-P3.1)` markers, see `docs/TODO_MAP.md`).
