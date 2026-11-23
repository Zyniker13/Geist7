# Dry Garden — docs/SOURCING.md

## 1. Tradition and communities

Karesansui (枯山水, dry landscape gardens) are a living craft tradition of Japan:
garden designers, nursery and quarry craftspeople, and the temple and museum
staffs who maintain historic raked-gravel gardens. Dry Garden is an abstract
strategy game inspired by the design vocabulary of dry landscape gardens —
asymmetric stone composition, raked patterns, odd groupings — set in a generic,
non-temple courtyard. It does not depict, reproduce, or name any specific real
garden, and it makes no claim of teaching garden design. The game's presentation
is secular throughout: no Buddhist iconography, no monks as characters, no
chants or bells.

## 2. Primary and secondary sources

Seeded from `ROADMAP.md` §1 (Inspirations) and §14 (Sourcing Notes):

- **North American Japanese Garden Association (NAJGA), "The Dry Landscape
  Garden."** Use: the asymmetry and odd-grouping principles the game's laws
  abstract, About-screen claims.
- **NAJGA, "7 Common Raking Patterns in Japanese Dry Landscape Gardens."**
  Primary reference for the seven samon patterns (aranamimon, ichimatsumon,
  mizumon, ryūsui, sazanamimon, seigaihamon, tachinamimon) used as display-only
  rake styles (R-23). Verified in `RESEARCH.md` §1.
- **NAJGA, "Chapter 20: Garden Rocks" ("Stones: The Bones of the Garden").**
  Use: stone composition vocabulary (Sakuteiki's omo-ishi, waki-ishi, mae-ishi,
  sanzon-ishigumi) informing stone-group visuals.
- **Sakuteiki (作庭記, 11th century), the oldest garden manual.** Use:
  historical context in About (labeled Attested, secondary translation).
- **Portland Japanese Garden, "Stones: The Bones of the Garden" and its
  International Institute for Japanese Garden Arts and Culture.** Use: North
  American practice context; candidate advisor institution.
- **Wikipedia, "Japanese rock garden."** Secondary background only; never a
  sole source for a game-text claim.

## 3. Restricted or sacred elements

From `RESEARCH.md` §3 and roadmap §14, the avoid list:

- No Buddhist iconography, sutra text, chants, or temple bells.
- No monks or clergy as characters.
- No named temples and no replicas of famous layouts (Ryōan-ji's fifteen stones
  are explicitly off-limits as content).
- No "Zen" as a marketing buzzword or aesthetic descriptor in game text.
- No faux-Japanese ("chop suey") Latin typography; native-language terms use
  correct kanji/kana with romaji only where the glossary records them.
- No stone lanterns or basins presented as decor without context; the basin
  (tsukubai) is a gameplay feature cell with a glossary note, not an ornament
  (A.9: no lantern feature at launch).
- Native-language glossary terms ship only after advisor confirmation; until
  then every entry stays `pending` in `cultural_manifest.json` and English-only
  labels are used in game text.

## 4. Glossary (native spellings, diacritics, pronunciation)

Seeded from `RESEARCH.md` §5; **all spellings pending advisor confirmation** —
every entry below is `status: "pending"` in `cultural_manifest.json` until the
maintainer records advisor answers. None of these appear in release game text
before approval; they are held for the About the Tradition screen (SRC3.1).

| Key | Term | Script | Gloss | Status | Source |
| --- | --- | --- | --- | --- | --- |
| gl_karesansui | karesansui | 枯山水 | dry landscape garden | pending | NAJGA ch. 5 (Verified in research) |
| gl_ishigumi | ishigumi | 石組 | stone arrangement | pending | NAJGA ch. 20 (Verified in research) |
| gl_samon | samon | 砂紋 | raked gravel pattern | pending | NAJGA raking patterns (Verified in research) |
| gl_sakuteiki | Sakuteiki | 作庭記 | Heian-period garden manual | pending | NAJGA (Verified in research) |
| gl_tsukubai | tsukubai | 蹲踞 | stone water basin | pending | NAJGA glossary (Secondary in research) |
| gl_mizumon | mizumon | 水紋 | concentric ripple pattern | pending | NAJGA (Verified in research) |
| gl_seigaihamon | seigaihamon | 青海波紋 | overlapping-wave pattern | pending | NAJGA (Verified in research) |

## 5. Claims made in game text (each with a source)

- C-1 "Dry landscape gardens developed in medieval Japan and are strongly
  associated with Zen temples from the Muromachi period onward." → `RESEARCH.md`
  §3 (secondary: Wikipedia, NAJGA). (About; Attested.)
- C-2 "The Sakuteiki, an eleventh-century garden manual, is the oldest known
  Japanese garden manual." → `RESEARCH.md` §3; NAJGA. (About; Attested.)
- C-3 "Asymmetric composition and odd groupings are widely taught principles of
  Japanese garden design." → NAJGA chapters; `RESEARCH.md` §2. (About and the
  laws' framing; Attested as garden principles, Invented as hard rules.)
- C-4 "The influence game, stone sizes, rakes, laws, and scoring are invented
  for play." → This roadmap. (Rules screen; Invented.)
- No claim that the game teaches garden design (§1, §3).

## 6. Asset provenance

All P0 art is procedural placeholder geometry in the roadmap palette
(gravel `#E9E6DF`, moss `#5F7A3A`, plaster `#D8CDB6`, roof tile `#3E4246`).
No third-party cultural assets are bundled. The final stone art set
(photogrammetry-style 2D renders, P6) will be produced from non-temple quarry
references per `RESEARCH.md` §1. Audio: mostly silence and field ambience; any
shakuhachi/koto phrases are commissioned and credited in P6 — no temple bells
or chanting (`RESEARCH.md` §6). `cultural_manifest.json` lists every culturally
specific placeholder (`status: "pending"`).

## 7. Advisor feedback log

Empty at P0. Each maintainer-recorded advisor item is logged here with its
date, the manifest entry or text key it concerns, and the decision
(applied / changed / deferred), per SRC6.2. Until then all manifest entries
stay `pending`.

## 8. Draft messages for the maintainer

**Draft: maintainer outreach for advisor review (filed as issue
`dry-garden: cultural advisor review`; SRC6.1, §3 of the addendum).**

> Dry Garden needs a Japanese-garden cultural review before cultural content
> ships. The review covers: the seven glossary entries (karesansui, ishigumi,
> samon, Sakuteiki, tsukubai, mizumon, seigaihamon — spellings and kanji
> pending confirmation), the courtyard naming convention (neutral English
> names; pattern names only in the glossary after review, roadmap A.9), the
> About the Tradition draft text (claims C-1..C-4), the lantern exclusion
> (A.9.3), and the secular, non-temple framing. Suggested partners: North
> American Japanese Garden Association (NAJGA), Portland Japanese Garden's
> International Institute, or a university department of Japanese garden
> history. Materials: `docs/SOURCING_REVIEW_PACKET.md` (produced at P5) and
> the draft brief to be added in P6. Advisor compensation and credit wording
> are maintainer decisions, to be recorded in the same issue.
