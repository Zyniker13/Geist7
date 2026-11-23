// SymmetryLaw.swift — R-7, R-17, R-18: the symmetry law.
//
// An action is illegal if, after it, the full set of stones (position
// and size, ignoring owner — ADR-0004's reading of R-7) is
// mirror-symmetric about any in-play axis of the courtyard, when at
// least `symmetryMinStones` stones stand on the board. The test
// compares the multiset of (cell, size) pairs against its reflection
// (R-18): stones reflecting onto a wall or a feature cell break
// symmetry automatically, because no stone can stand there.

/// Reason an action was rejected (A.3 `IllegalReason`; the reducer
/// throws these and the UI explains them, DG-P2.3).
public enum IllegalReason: String, Codable, Hashable, Sendable, Error {
    case occupied
    case raked
    case feature
    case offCourtyard
    case sameSizeAdjacent
    case basinAdjacent
    case noSupply
    case symmetry
    case collinear
    case rakeNotStraight
    case rakeBadLength
    case rakeBlocked
    case rakeNoAnchor
    case rakeCrossing
    case rakeAnchorOwned
    case mustMove
    case gameOver
}

public enum SymmetryLaw {

    /// R-7/R-18: true when the stone multiset of (cell, size) — owner
    /// ignored — is mirror-symmetric about `axis`. A stone whose
    /// reflection is not a stone's cell breaks symmetry (that covers
    /// reflections onto walls and features, R-18, since no stone can
    /// stand there).
    public static func isSymmetric(
        _ stones: [Stone], about axis: Axis
    ) -> Bool {
        var byCell: [Hex: StoneSize] = [:]
        for stone in stones {
            byCell[stone.cell] = stone.size
        }
        // A mirror needs a fixed point count parity check only for
        // centre families with an odd stone count on the axis; instead
        // of special-casing, pair every stone with its reflection.
        var remaining = byCell
        for (cell, size) in byCell {
            guard remaining[cell] != nil else { continue }  // already paired
            let image = axis.reflect(cell)
            if image == cell {
                // A stone on the axis pairs with itself.
                remaining[cell] = nil
                continue
            }
            guard remaining[image] == size else {
                return false
            }
            remaining[cell] = nil
            remaining[image] = nil
        }
        return remaining.isEmpty
    }

    /// R-7: the law against the resulting position — illegal when the
    /// stones mirror about ANY axis in play, at `symmetryMinStones`
    /// stones or more. Order-independent by construction (it works on
    /// dictionaries, INV-6).
    public static func violated(
        stones: [Stone], courtyard: Courtyard, balance: Balance
    ) -> Bool {
        guard stones.count >= balance.symmetryMinStones else { return false }
        guard !courtyard.axes.isEmpty else { return false }
        for axis in courtyard.axes {
            let candidate = Axis(family: axis.family, offset: axis.offset)
            if isSymmetric(stones, about: candidate) {
                return true
            }
        }
        return false
    }
}
