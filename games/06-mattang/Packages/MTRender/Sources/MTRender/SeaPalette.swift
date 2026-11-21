// SeaPalette.swift — the roadmap palette in light and dark schemes.
//
// RESEARCH.md art direction: deep sea, swell crest, pandanus,
// coconut rib, cowrie — the materials of a stick chart (coconut
// midribs, pandanus weave, cowrie shells) over the open ocean. The
// palette is data, not code: both schemes expose the same five named
// colors so the scene logic never branches on the scheme.

import SwiftUI

public struct SeaPalette: Equatable, Sendable {
    /// Open ocean behind everything.
    public let deepSea: Color
    /// Ray lines and strength shading.
    public let swellCrest: Color
    /// Island and atoll fills.
    public let pandanus: Color
    /// Canoe markers and the chart frame.
    public let coconutRib: Color
    /// Nodes, highlights, and the preview ghost outline.
    public let cowrie: Color

    public init(
        deepSea: Color, swellCrest: Color, pandanus: Color,
        coconutRib: Color, cowrie: Color
    ) {
        self.deepSea = deepSea
        self.swellCrest = swellCrest
        self.pandanus = pandanus
        self.coconutRib = coconutRib
        self.cowrie = cowrie
    }

    /// Light scheme: pale chart materials over a mid sea.
    public static let light = SeaPalette(
        deepSea: Color(red: 0.09, green: 0.31, blue: 0.43),
        swellCrest: Color(red: 0.94, green: 0.97, blue: 0.98),
        pandanus: Color(red: 0.83, green: 0.68, blue: 0.36),
        coconutRib: Color(red: 0.76, green: 0.58, blue: 0.34),
        cowrie: Color(red: 0.98, green: 0.95, blue: 0.86))

    /// Dark scheme: deep-night sea, luminous crests.
    public static let dark = SeaPalette(
        deepSea: Color(red: 0.03, green: 0.10, blue: 0.16),
        swellCrest: Color(red: 0.62, green: 0.84, blue: 0.92),
        pandanus: Color(red: 0.66, green: 0.52, blue: 0.24),
        coconutRib: Color(red: 0.56, green: 0.42, blue: 0.24),
        cowrie: Color(red: 0.93, green: 0.89, blue: 0.76))

    public static func scheme(_ isDark: Bool) -> SeaPalette {
        isDark ? .dark : .light
    }
}
