# Rosette — Privacy Nutrition Label Draft

Target: **Data Not Collected**. Design refusals that back every line below
are in the roadmap's privacy choices and ARCHITECTURE.md; the app has no
analytics SDK, no advertising SDK, no crash reporter, and no network
telemetry.

## Answers for App Store Connect

| Question | Answer | Basis |
| --- | --- | --- |
| Does the app collect data from this app? | No | No analytics, ads, or tracking SDKs are linked; no data leaves the device except user-initiated Game Center/social surfaces owned by Apple |
| Contact info | Not collected | — |
| Identifiers | Not collected | — |
| Usage data | Not collected | — |
| Diagnostics | Not collected | Crash reporting is deliberately absent (issue #10 notes the UX cost) |
| Location | Not collected | — |
| User content | Not collected | Save files and stats live in the app's local storage; the Settings > Export action shares a JSON file the user explicitly sends |
| Purchase history | Not collected | Payments are processed by Apple; the app never sees them |

## Data handling statements

- **Stats are on-device.** The stats store (`RSMeta.Stats`) is a local JSON
  file in Application Support; the only export path is the user-initiated
  ShareLink in Settings.
- **Online async matches** (post-launch) use Game Center's turn-based
  infrastructure where possible; any direct netcode must be re-reviewed
  against this page before shipping.
- **No third-party code** in the app links against any advertising, analytics,
  or attribution framework (see THIRD_PARTY.md for the full dependency list).
