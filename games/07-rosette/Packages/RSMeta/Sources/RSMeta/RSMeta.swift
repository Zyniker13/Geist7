// RSMeta — meta layer for Rosette (RS-P5.1).
//
// The meta layer sits above the deterministic core: it derives the daily
// match from a UTC date, tracks player statistics, evaluates the
// achievement catalog, keeps local leaderboards, and persists everything
// as JSON. It never calls the wall clock or a UUID generator itself —
// dates and days are parameters, so every derivation is reproducible
// (ADR-0012).
