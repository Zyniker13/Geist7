# Set Two Addendum: Respectful Sourcing, Historical Labeling, and Set-Wide Notes

Version 2.0 · 2026-11-15 · Applies to every game roadmap at `../NN-<slug>/ROADMAP.md` (`01`–`25`). Read after [`_CONVENTIONS.md`](_CONVENTIONS.md) and before the game roadmap.

`_CONVENTIONS.md` remains the authority for process, stack, standards, and gates. This addendum adds two families of standard tasks (`SRC` and `HIST`), the advisor-review owner-only step, and a few set-wide technical notes. It never adds a stop: every gate stays `GLM-SELF` (`_CONVENTIONS.md` §1). A roadmap states which families apply in its §0 Metadata (`Sourcing tier`).

---

## 1. Why This Exists

Set Two deliberately builds on living traditions (Ottoman marbling, Mughal Ganjifa, East African mancala, Japanese gardens and printmaking, Marshallese navigation, Malagasy Fanorona, Persian and Central Asian tilework, Andean khipu, Hawaiian and Māori games, Gujarati kite flying, and Indigenous fire practice) and on ancient ones (Mesopotamia, the Late Bronze Age Aegean, and Han China). The design principle from the concepts Page is:

> Respectful sourcing: cultural advisors, credit, revenue share where a living tradition is drawn on, secular rather than sacred imagery, and clear labels on what is reconstructed or invented.

GLM cannot hire, contact, or pay advisors. It prepares everything an advisor needs, keeps culturally specific assets clearly marked as pending advisor review, files the review as a maintainer issue, and keeps building.

## 2. Sourcing Tiers

| Tier | Meaning | Families that apply |
| --- | --- | --- |
| `FULL` | Draws on a living tradition, community, or craft for mechanics, art, music, names, or text | `SRC` + `HIST` |
| `HISTORICAL` | Draws on an ancient or historical culture with no single living steward, or on historical European art | `HIST` only |
| `NONE` | Original or generic setting | Neither |

## 3. Advisor Review Is an Owner-Only Step

| Who | Responsibility |
| --- | --- |
| Cultural advisors, engaged, credited, and paid by the maintainer | Review the sourcing packet; approve, request changes, or veto culturally specific assets, names, rules, and text. |

Advisor review follows `_CONVENTIONS.md` §1.1, item 1, and the "Cultural advisor sign-off" row of §8.2. GLM never contacts advisors, communities, museums, or rights holders directly. It drafts the advisor brief and any outreach text in `docs/SOURCING.md` §8, files one `needs-maintainer` issue per game for the review (labels `needs-maintainer` and the slug; title `<slug>: cultural advisor review`), records the gate check as `SUBSTITUTED`, and continues. GLM files that issue in P0 (linking the roadmap, `RESEARCH.md`, and its candidate institutions) so outreach can start early, then adds the packet and brief to it in P6. Until the maintainer records an answer in that issue, every affected manifest entry stays `pending`, the debug "Pending advisor review" mark stays on, and the About text stays marked `DRAFT`. Compensation, credit wording, and any revenue share are maintainer decisions, filed in the same issue.

## 4. Standard Tasks: `SRC` (Tier `FULL`)

| ID | Phase | Owner | Task | Acceptance |
| --- | --- | --- | --- | --- |
| SRC0.1 | P0 | GLM | Create `docs/SOURCING.md` with sections: 1 Tradition and communities; 2 Primary and secondary sources (seeded from the roadmap's §1 Inspirations and §14 Sourcing Notes); 3 Restricted or sacred elements (seeded from the roadmap); 4 Glossary with native-language spellings, diacritics, and pronunciation notes; 5 Claims made in game text, each with a source; 6 Asset provenance; 7 Advisor feedback log; 8 Draft messages for the maintainer. | File exists with all eight headings; §3 and §4 populated from the roadmap. |
| SRC0.2 | P0 | GLM | Create `Resources/Content/cultural_manifest.json` (schema below) and a `content-lint` rule: every asset, string key, rule name, or content ID tagged `cultural: true` in any table must have a manifest entry. | Lint fails on a deliberate fixture with a missing entry. |
| SRC2.1 | P2 | GLM | Tag every culturally specific placeholder (art, audio, names, and text) in the manifest with `status: "pending"`. In debug builds, draw a small "Pending advisor review" corner mark on screens that show pending assets. | Snapshot test shows the mark in debug and its absence in release configuration. |
| SRC2.2 | P2 | GLM | Avoid every element in the roadmap's restricted list. Add a `content-lint` deny-list of restricted terms and asset tags. | Lint fails on a fixture containing a restricted term. |
| SRC3.1 | P3 | GLM | Build an "About the Tradition" screen (reachable from the main menu and the credits) with draft text marked `DRAFT`, every factual claim linked to a `docs/SOURCING.md` §5 entry, and the glossary. | UI test opens the screen; lint confirms every claim key has a source. |
| SRC5.1 | P5 | GLM | Produce `docs/SOURCING_REVIEW_PACKET.md`: screenshots of every screen with cultural content, a table of every manifest entry, all game text that names or describes the tradition, rule names, music and sound descriptions, and open questions for the advisor. | Packet lists 100% of manifest entries (script check). |
| SRC6.1 | P6 | GLM | Draft the advisor brief from the packet in `docs/SOURCING.md` §8 and add it and the packet to the `<slug>: cultural advisor review` issue filed in P0 (§3). | Issue number recorded in `docs/STATUS.md`; brief lists every `pending` manifest entry. |
| SRC6.2 | P6 and later | GLM | When the maintainer records advisor feedback in the issue, log each item in `docs/SOURCING.md` §7, apply it, and flip manifest entries to `approved`, `changed`, or `removed`. Until then, keep entries `pending`. | Every logged feedback item has a decision; every remaining `pending` entry is listed in the open issue. |
| SRC9.1 | P9 | GLM | Prepare a community playtest drawn from the tradition (tester guide, build notes, and questions) and file a `needs-maintainer` issue for the maintainer to recruit and run it; the local substitute is the scripted playthroughs and recordings in `_CONVENTIONS.md` §8.2. | Issue filed; any findings the maintainer records are triaged, with S1/S2 cultural issues fixed. |
| SRC10.1 | P10 | GLM | Draft the final credits (advisors, artists, and source institutions), the About the Tradition text, and the revenue-share or donation note in `docs/release/`, and file them for the maintainer in a `needs-maintainer` issue. | Drafts present; issue filed and listed in the G10 maintainer item. |

**Gate additions (every `FULL` roadmap includes these checks in its gate blocks):**

- **G0:** SRC0.1 and SRC0.2 done; the `<slug>: cultural advisor review` issue filed (§3).
- **G2:** manifest covers every culturally specific placeholder; restricted deny-list lint passes.
- **G5:** `docs/SOURCING_REVIEW_PACKET.md` complete; zero manifest gaps; zero restricted elements.
- **G6:** advisor review filed as a `needs-maintainer` issue (`SUBSTITUTED`), with every entry still `pending` listed in that issue and still marked pending advisor review in content; any advisor feedback already received is applied.
- **G10:** SRC10.1 drafts complete and filed. Release-facing cultural content that is still `pending` is listed in the G10 maintainer item; the maintainer decides whether it ships.

`cultural_manifest.json` schema:

```json
{
  "id": "card_suit_crown",
  "kind": "art | audio | text | name | rule | music | font",
  "tradition": "mughal_ganjifa",
  "description": "Crown suit pip, round card",
  "source_refs": ["src_ignca_ganjifa"],
  "status": "pending | approved | changed | removed",
  "advisor_notes": "",
  "credit": ""
}
```

## 5. Standard Tasks: `HIST` (Tiers `FULL` and `HISTORICAL`)

| ID | Phase | Owner | Task | Acceptance |
| --- | --- | --- | --- | --- |
| HIST0.1 | P0 | GLM | Create `docs/HISTORY.md` with three lists: Attested (with source), Reconstructed (with the reconstruction's basis), and Invented for play. | File exists; seeded from the roadmap. |
| HIST3.1 | P3 | GLM | Every in-game historical note carries a label (Attested, Reconstructed, or Invented) in its content row; `content-lint` requires the field. | Lint passes; UI shows the label in the info panel. |
| HIST6.1 | P6 | GLM | Fact-check pass of all historical text against `docs/HISTORY.md` and the sources in the game's `RESEARCH.md`. | Entry in `docs/STATUS.md` listing each text key checked and its label. |

## 6. Set-Wide Technical Notes

1. **Fixed-point geometry.** Several Set Two games (Ebru, Mattang, Dry Garden, Girih, Patang, Delta-v, and Backburn) need square roots, trigonometry, or continuous geometry in Core. Use the shared `Fixed` (Q32.32) type, an integer Newton square root (`Fixed.sqrt`, tested against known-answer vectors), and committed lookup tables for sine and cosine (4096 entries per turn) generated by a tool in `Tools/` and checked into `Core/Foundation/`. `Double` remains banned in Core.
2. **Area and polygon math** uses the shoelace formula on `Fixed` vertices with 128-bit intermediate products (`Int64.multipliedFullWidth`).
3. **AI personalities** (auctions, negotiation, and coalitions) are data in `ai_personalities.json`, never hard-coded branches, so GLM can tune them from sim data in P5 and P9.
4. **Bots for multi-faction games** follow published flowcharts encoded as data (`bot_flowcharts.json`), so each bot decision can be traced in tests and logs.
5. **No large language models at runtime.** Negotiation and diplomacy AIs use structured offers and utility functions only.
6. **Daily seeds** use `SplitMix64(fnv1a64("<PFX>-daily-" + yyyyMMdd UTC))` in every game, so all players share a seed.

## 7. Writing Style

Title Case headings, American English, the serial comma, and native-language names with correct diacritics (Mū tōrere, Hōkūleʻa, Ganjifa) as recorded in each game's glossary.

## 8. Research Files

Each game folder holds `RESEARCH.md` beside `ROADMAP.md`: art direction references, design lineage, cultural and historical context (including what to avoid), candidate advisor types and institutions (no private contact details), a glossary with a status per term (Verified, Secondary, or Unverified), audio direction, the corrections already applied to the roadmap, and source URLs. GLM seeds `docs/SOURCING.md` and `docs/HISTORY.md` from it in P0 and never promotes an Unverified term to game text without a source.
