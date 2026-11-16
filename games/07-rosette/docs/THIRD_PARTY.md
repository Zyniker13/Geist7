# Rosette — docs/THIRD_PARTY.md

## Third-Party Components

### RoyalUr solved-value tables (verification evidence)

- **What:** The published solved-value tables `finkel.rgu` (7-piece) and
  `finkel2p.rgu` (2-piece) from the RoyalUr project, used only as
  verification evidence for RS-P1.4: a 512-entry evenly-spaced sample of
  the two-piece table is committed at
  `Packages/RSCore/Tests/RSCoreTests/Fixtures/Tables/rgu2p-sample.json`
  and asserted against this package's own solver in
  `SolveTests.testTable_MatchesRoyalUrPublishedSample`.
- **Source:** https://huggingface.co/datasets/sothatsit/RoyalUrModels
  (file `finkel2p.rgu`), produced by the RoyalUr.net solved analysis.
- **License:** MIT (royalur-java and the RoyalUrModels distribution, verified
  via the upstream licence files on 2026-11-16).
- **Copyright:** Padraig Lamont / RoyalUr contributors.
- **Use:** Sample data embedded in a test fixture (not shipped in the app);
  the full tables are downloaded during development only and are not
  committed.

### Allowed Dependencies
Per `_CONVENTIONS.md` §4.4, all dependencies must be on the allow-list:
- None (core Swift standard library only). The tables above are test
  evidence data, not a code dependency.

### Attribution
The RoyalUr project (https://royalur.net) by Padraig Lamont and
contributors publishes the solved-value tables used as verification
evidence above, under the MIT licence. This project's solver, rules
engine, and tables are independent implementations; the published data is
used solely to verify correctness.
