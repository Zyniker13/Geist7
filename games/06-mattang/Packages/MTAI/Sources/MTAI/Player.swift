// Player.swift — the opponent handle the UI and the sim tool drive.
//
// A Player pairs a Tier with the dispatch to its engine: Paddler and
// up all run AlphaBeta (the tiers differ by budget and noise band),
// and the P2-era 1-ply greedy Sailor remains available as `sailorPly1`
// for the P2 UI tests and the tier-gap baseline. Everything flows
// from the caller's SeededRNG (S0.2/INV-1).

import MTCore

public struct Player: Sendable {
    public let tier: Tier

    public init(tier: Tier) { self.tier = tier }

    /// The action this player takes in `state`; always legal.
    public func chooseAction(in state: GameState, rng: inout SeededRNG) -> Action {
        AlphaBeta(tier: tier).chooseAction(in: state, rng: &rng)
    }
}

/// The P2 1-ply greedy reader (MT-P2.2), kept as the Sailor baseline.
public struct SailorPly1: Sendable {
    public init() {}

    public func chooseAction(in state: GameState, rng: inout SeededRNG) -> Action {
        Sailor().chooseAction(in: state, rng: &rng)
    }
}
