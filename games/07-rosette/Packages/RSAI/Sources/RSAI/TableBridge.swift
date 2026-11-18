import Foundation
import RSCore

/// Bridges the engine's `MatchState` to the solver's packed `UrPosition`
/// (RS-P4.1). Only the two-player Finkel layout (14 path steps, 8 shared
/// squares, 7 pieces per player) maps onto the solved table; every other
/// ruleset is played by expectiminimax instead.
///
/// The conversion mirrors `Tools/SolveUr/Inv5Check.swift`'s `tuple(from:)`
/// and is pinned by tests against it (ADR-0010).
public enum TableBridge {

    /// Whether `ruleset` is exactly the layout the solved table covers.
    public static func isTableLayout(_ ruleset: RuleSet) -> Bool {
        ruleset.id == "finkel"
            && ruleset.trackLength == UrRanking.trackLength
            && ruleset.pieces == 7
            && ruleset.rosettes == [3, 7, 13]
            && ruleset.safeRosettes == [UrRanking.safeRosette]
    }

    /// The solver position of `state`, from the perspective that the player
    /// about to roll is "player 0" of the position. Returns nil when the
    /// state's ruleset is not the table layout.
    public static func position(from state: MatchState) -> UrPosition? {
        guard isTableLayout(state.ruleset) else { return nil }
        return position(from: state.pieces, roller: state.currentPlayer)
    }

    /// The solver position for a piece list, recolouring so `roller` is the
    /// position's player 0.
    public static func position(from pieces: [Piece], roller: PlayerID) -> UrPosition? {
        var shared: UInt32 = 0
        var private0: UInt32 = 0
        var private1: UInt32 = 0
        var hand0 = 0
        var hand1 = 0
        for piece in pieces {
            let isRollerSide = piece.owner == roller
            switch piece.position {
            case -1:
                if isRollerSide { hand0 += 1 } else { hand1 += 1 }
            case -2:
                break
            case let step:
                if step >= UrRanking.sharedStart && step < 12 {
                    let digit: UInt32 = isRollerSide ? 1 : 2
                    shared |= digit << UInt32((step - UrRanking.sharedStart) * 2)
                } else {
                    let bit: UInt32 = step < 4 ? UInt32(step) : UInt32(step - 12 + 4)
                    if isRollerSide {
                        private0 |= 1 << bit
                    } else {
                        private1 |= 1 << bit
                    }
                }
            }
        }
        // Digit 3 never occurs; a malformed piece list would fail here.
        guard UrPosition.isValidShared(shared) else { return nil }
        return UrPosition(
            shared: shared, private0: private0, private1: private1,
            hand0: hand0, hand1: hand1)
    }
}
