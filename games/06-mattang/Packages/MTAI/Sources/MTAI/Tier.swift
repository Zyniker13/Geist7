// Tier.swift — the §7 difficulty ladder.
//
// Four tiers per ROADMAP.md §7: Paddler (depth 1, noise), Sailor
// (depth 2), Navigator (depth 4), and the top tier, named "Deep Water"
// until the advisor approves a Marshallese name (§4 open-question
// default 1: neutral tier names; ri-meto is never a tier name — it is
// a title conferred by an iroij). All tiers share AlphaBeta's search;
// a tier is a search budget plus a noise band.
//
// Determinism (ADR-0018): a tier is depth-primary. The search always
// completes its recorded depth — there is no wall-clock cutoff — so
// identical seeds produce identical moves everywhere (INV-1). The §7
// latency budgets (Navigator 1.0 s, Deep Water 2.0 s) are verified as
// measured p95 bounds in docs/BALANCE.md, not enforced in the search.

import MTCore

public struct Tier: Hashable, Sendable {
    /// Stable identifier (the name shown in the UI).
    public let id: String
    /// Iterative-deepening target depth in plies.
    public let depth: Int
    /// Paddler only: root actions scoring within this band of the best
    /// are chosen uniformly by the seeded RNG. 0 = exact best.
    public let noiseBand: Int

    public init(id: String, depth: Int, noiseBand: Int) {
        self.id = id
        self.depth = depth
        self.noiseBand = noiseBand
    }

    /// §7: depth 1 with a noise band, the approachable tier.
    public static let paddler = Tier(id: "Paddler", depth: 1, noiseBand: 6)
    /// §7: depth 2 — the slice's Sailor gains its depth here.
    public static let sailor = Tier(id: "Sailor", depth: 2, noiseBand: 0)
    /// §7: depth 4 with a deterministic root-breadth cap (ADR-0020:
    /// the 1.0 s budget is a measured p95 bound).
    public static let navigator = Tier(id: "Navigator", depth: 4, noiseBand: 0)
    /// §7's top tier, "Deep Water" until the advisor names it: depth 6
    /// with the same root cap (ADR-0020; the 2.0 s budget is a
    /// measured p95 bound).
    public static let deepWater = Tier(id: "Deep Water", depth: 6, noiseBand: 0)

    /// The ladder in strength order.
    public static let ladder: [Tier] = [paddler, sailor, navigator, deepWater]

    /// The tier with `id`, or nil (launch-argument parsing).
    public static func named(_ id: String) -> Tier? {
        ladder.first { $0.id == id }
    }
}
