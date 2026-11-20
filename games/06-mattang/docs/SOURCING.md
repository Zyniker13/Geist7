# Mattang — docs/SOURCING.md

## 1. Tradition and communities

Marshallese wave piloting — the reading of ocean swells for landfall, taught on land with stick charts (mattang, meddo, rebbelib, wapepe) — is a living, protected knowledge tradition of the Marshall Islands (Majel). Knowledge holders are Marshallese navigators, elders, and their communities. Mattang (this game) does not teach or claim to teach actual navigation knowledge: it is an abstract strategy game about reading swells. Charts were memorised on land, not carried at sea; navigators held them as teaching tools (Genz et al. 2009; Ascher 1995). No claim of real navigation instruction is made anywhere in the game, its store copy, or its About screen.

## 2. Primary and secondary sources

Seeded from `ROADMAP.md` §1 (Inspirations) and §14 (Sourcing Notes):

- **Genz, Aucan, Merrifield, Finney, Joel, and Kelen, "Wave Navigation in the Marshall Islands" (Oceanography, 2009).** Primary scholarly account of wave piloting and its contemporary revival. Use: swell reading concepts (booj, okar, dilep, kaelep), About-screen claims, glossary.
- **Genz (2011)** — follow-up work on Marshallese navigation revival (glossary cross-check).
- **Ascher, "Models and Maps from the Marshall Islands" (1995).** Stick-chart mathematics (Ising, 1998); use: reflection/refraction abstraction framing, About-screen claims.
- **Smithsonian collections notes** on stick charts. Use: historical context, asset provenance framing.
- **Waan Aelõñ in Majel (WAM) canoe program.** Living practice of canoe building and sailing; the partner community context for the advisor relationship and revenue share. No WAM content is used without advisor approval.

## 3. Restricted or sacred elements

- No replication of specific family charts (any chart held by a family or museum is depicted only as an abstract, generic frame; no tracing, no naming of makers or holdings).
- No claims of teaching navigation (MT-P0.1; stated in §1 and in About).
- No religious or chiefly titles in game text (no iroij-derived honorifics).
- **ri-meto** ("person of the ocean") is a title conferred by an iroij — it must not be used for AI tiers, ranks, achievements, or any in-game label.
- Swell names use only advisor-approved glossary entries; until approval, neutral names ("East swell").
- No depiction of wapepe-style wave models unless advisors suggest it (A.9.2).
- Depictions of specific stick charts held by families or museums are restricted (MT-P0.1): the UI's chart-frame echo is a generic construction of ribs and shells, not a replica of any specific chart.

## 4. Glossary (native spellings, diacritics, pronunciation)

Verified against Genz et al. 2009 and Genz 2011; **all spellings still pending advisor confirmation** — every entry below is `status: "pending"` in `cultural_manifest.json` until the maintainer records advisor answers.

| Key | Term | Gloss | Notes |
| --- | --- | --- | --- |
| gl_booj | booj | knot; the node where swells meet | also written boot or bōt; core node concept |
| gl_okar | okar | root; a line of nodes | chain-of-nodes gameplay concept |
| gl_dilep | dilep | backbone; the wave path between islands | ray path concept |
| gl_kaelep | kaelep | western swell | swell name |

Chart-type terms (context only, in About; not gameplay labels): mattang, meddo, rebbelib, wapepe. Marshallese orthography uses diacritics (ā, ļ, m̧, n̄, o̧, ō, ū); SF Pro Rounded must be verified to render them before any term ships (P6 typography check).

## 5. Claims made in game text (each with a source)

- C-1 "Charts were memorised on land, not carried at sea; navigators used them to teach." → Genz et al. 2009; Ascher 1995. (About screen; HIST0.1 Attested.)
- C-2 "Islands bend wave directions by reflection and refraction; swells cross and form knots." → Genz et al. 2009; Ascher 1995 (mathematical model). (About screen; the game mechanic, not the physics, is the claim's referent.)
- C-3 "Mattang, meddo, rebbelib, and wapepe are chart types." → Genz et al. 2009; Smithsonian collections notes. (About screen; labeled Attested.)
- C-4 "The scoring game, canoes, island pool, and win conditions are invented for play." → This roadmap. (Rules screen; labeled Invented.)
- No claim that the game teaches navigation (§1, §3).

## 6. Asset provenance

All art and audio is procedural, theme-driven, and asset-free (no third-party cultural assets are bundled). Theme anchors: cowrie shells (islands), pandanus fibre / coconut rib (chart frame, swell ribs), atoll sand and lagoon palette (roadmap §1 aesthetic spec). The generic chart-frame UI echoes stick-chart construction without copying any specific chart. No Marshallese music is used (roadmap §1: only with advisor approval and licensing — default none). `cultural_manifest.json` in `Packages/MTContent/Sources/MTContent/Resources/Content/` lists every culturally specific placeholder (`status: "pending"`).

## 7. Advisor feedback log

Empty at P0. Each maintainer-recorded advisor item is logged here with its date, the manifest entry or text key it concerns, and the decision (applied / changed / deferred), per SRC6.2. Until then all manifest entries stay `pending`.

## 8. Draft messages for the maintainer

**Draft: maintainer outreach for advisor review (filed as issue `mattang: cultural advisor review`; SRC6.1, §3 of the addendum).**

> Mattang needs a Marshallese cultural review before cultural content ships. The review covers: the four glossary entries (booj, okar, dilep, kaelep — spellings pending confirmation), the working title "Mattang" (a chart-type name; advisors may prefer another; fallback "Swellmark"), the About the Tradition draft text (four claims, C-1..C-4), the generic chart-frame UI concept, and the no-real-navigation-training framing. Suggested partners: Waan Aelõñ in Majel (WAM) or a Marshallese cultural organisation; a revenue-share agreement is proposed (percentage to be decided — see the revenue-share issue). Materials: `docs/SOURCING_REVIEW_PACKET.md` (produced at P5) and the draft brief below.
>
> Draft brief (will accompany the packet): "Mattang is an abstract strategy game inspired by Marshallese wave piloting. Two players shape an ocean of swells by placing islands, and race canoes between home atolls. It does not teach navigation. We would like your review of the Marshallese terms, the title, and how the tradition is described, and we propose a revenue share for your approval of that use."
