import Foundation

/// Game-facing copy for the About the Tradition screen (MT-P3.2,
/// SRC3.1). Every claim carries its sourcing key from docs/SOURCING.md
/// §5 so the release-string lint can check that no Marshallese term
/// appears outside a glossary key (G3 sharpened check) and that each
/// claim key is present.
///
/// Advisor placeholders: the Marshallese terms below appear only as
/// chart-type context from the Attested list (SRC §4); every glossary
/// term stays pending advisor review (SRC §4/§7), so no pending term is
/// rendered here — neutral names only. The advisor-written passage is
/// a placeholder marked in its doc comment.
enum AboutText {
    /// SRC §5 C-1 (Genz et al. 2009; Ascher 1995).
    static let chartsMemorisedOnLand =
        "Stick charts were memorised on land, not carried at sea; navigators used them to teach."

    /// SRC §5 C-2 (Genz et al. 2009; Ascher 1995 — the mathematical
    /// model, not a physics claim). The referent is the game mechanic.
    static let islandsBendSwells =
        "Islands bend wave directions by reflection and refraction; swells cross and form knots."

    /// SRC §5 C-3 (Genz et al. 2009; Smithsonian collections notes).
    static let chartTypes =
        "Mattang, meddo, rebbelib, and wapepe are chart types."

    /// SRC §5 C-4 (this roadmap — labeled Invented).
    static let rulesAreInvented =
        "The scoring game, canoes, island pool, and win conditions are invented for play."

    /// SRC §1/§3 (MT-P0.1): the game must not claim to teach navigation.
    static let noTeachingNavigation =
        "Mattang is an abstract strategy game about reading swells, not a navigation trainer."

    /// Placeholder for advisor-written text (SRC §7): the passage ships
    /// only after the advisor review records it; until then the screen
    /// renders this placeholder marker.
    static let advisorParagraph =
        "[Advisor-written introduction to the tradition — pending cultural review.]"
}
