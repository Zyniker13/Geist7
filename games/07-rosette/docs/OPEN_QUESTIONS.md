# Rosette — docs/OPEN_QUESTIONS.md

## Open Questions

| # | Question | Answer | Source |
| --- | --- | --- | --- |
| OQ-001 | Which ancient games will be in the circuit? | See ROADMAP.md §4 for the list. | Roadmap |
| OQ-002 | How many AI levels? | Default: 5 (Random, Novice, Intermediate, Expert, Master). | Roadmap §13 |
| OQ-003 | What is the scoring formula? | Default: base score × difficulty multiplier + streak bonus + victory margin. | Roadmap §13 |
| OQ-004 | (P4) The circuit economy is currently uncompletable: Σbuy-ins (198) far exceeds the 40-chip starting purse while match stakes are even-money, so no run can reach the mexica region, and the G3 simulation records 0 full completions in 1,000 runs (clean terminations only). G4's balance task must make wins fund later buy-ins (raise stakes above buy-ins, lower later buy-ins, or add omen/gammon upside) and tune to the roadmap target: optimal bot completes 55–70%, naive 5–15%. | **Resolved in P4** (ADR-0011): starting purse raised 40 → 80 (roadmap-tunable 20–80), opponent strengths calibrated Sumer 3 / Egypt 4 / Mexica 4, and re-challenge seeds indexed by attempt. Measured: optimal completes 0.583 (28/48, band 55–70%), naive 0.083 (2/24, band 5–15%). Wins fund later buy-ins through the cube and gammon settlements. | G4 gate evidence, 2026-11-18 |
| OQ-005 | (HIST) The astragal4 face odds (10/40/40/10) are a flagged placeholder: the tablet attests astragal use but not the face-to-value mapping. Needs review against scholarship before release; the content note marks it Reconstructed. | Open — revisit in HIST review (P6 fact-check). | ROADMAP Appendix A.3, R-16 |
