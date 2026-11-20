# Rosette — Accessibility Nutrition Labels Draft

Draft for App Store Connect's accessibility section (maintainer submits;
issue #11). Every claim maps to an implemented feature and a test in the
accessibility suite (P8, `docs/STATUS.md`).

| Label | Answer | Evidence |
| --- | --- | --- |
| Voice Control | Fully accessible | Every control is a labelled accessibility element; the board exposes legal destinations as custom a11y actions; UI test `RosetteAccessibilityUITests` verifies the roster |
| VoiceOver | Fully accessible | RSPlatform announcer narrates rolls, moves, captures, rosettes, and completion; piece and square traits are set; UI tests verify the a11y tree mid-match (smoke level, see issue #10) |
| Dynamic Type | Supported | All UI text scales with the content size category; the board scales non-text pieces to the layout; P8 suite covers XXL |
| Bold Text | Supported | Uses the system font with weight-following styles |
| Reduce Motion | Supported | RSPlatform motion settings gate all non-essential animation; tested |
| Increase Contrast | Supported | Piece/rosette shapes stay distinguishable without color alone (P8 shape tokens); tested with increased-contrast setting |
| Reduce Transparency | Supported | No translucent overlays required for play |
| Captions | N/A | No audio/video content in 1.0 |
| Differentiate Without Color | Supported | Shapes distinguish pieces for color-vision deficiency (P8 color-vision simulator checks) |
| Switch Control | Supported | Board interactions work through the a11y action roster |
| Larger Accessibility Sizes | Supported | Layout reflows to the largest Dynamic Type sizes |
