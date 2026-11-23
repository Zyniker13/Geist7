# Dry Garden — Open Questions

From the roadmap §13 and Appendix A.9, with the defaults GLM builds to unless
the maintainer overrides. Each open question also carries the default chosen.

1. Include a free garden sandbox? → **Default: post-launch** (roadmap §13.1).
2. Ship music at all, or silence plus SFX? → **Default: optional music, off by
   default** (roadmap §13.2; `RESEARCH.md` §6 audio direction).
3. Allow 3-player free-for-all on large courtyards? → **Default: no** (A.9.1).
4. Name courtyards after raking patterns (`samon`) or neutral English names?
   → **Default: neutral English names, with pattern names only in the glossary
   after advisor review** (A.9.2).
5. Include a lantern feature? → **Default: no at launch** (A.9.3; stone
   lanterns carry religious associations).

New questions raised by P0 work:

6. (ADR-0004) The roadmap's default "Ryōan" outline is 113 cells, which
   measures 11 in-play mirror axes at R-17's 70% filter — the symmetry law
   would fire from geometry alone on the named default. GLM built a 44-cell
   irregular outline with zero in-play axes instead, preserving the design
   intent (asymmetry is the aesthetic; the law must bite on stone mirrors,
   not the yard). Recorded as ADR-0004; flagged here so the maintainer can
   override if a historical-outline fidelity matters more than the law feel.
