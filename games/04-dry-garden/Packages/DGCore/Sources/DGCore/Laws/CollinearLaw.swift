// CollinearLaw.swift — R-8, R-19: the collinearity law.
//
// An action is illegal if, after it, any three stones lie on one
// straight lattice line with equal spacing k ≥ 1 — regardless of owner
// and size (R-19; "spacing counts in cells along the line", so k = 1
// means three adjacent stones).

public enum CollinearLaw {

    /// R-8/R-19: true when any three of the stones share one lattice
    /// line with equal spacing. The three lattice line families are the
    /// constant-r rows, the constant-(q+r) columns, and the constant-q
    /// diagonals... in pointy-top axial coordinates the three line
    /// directions are the hex directions themselves, and a line is
    /// characterized by one of three scalar keys:
    ///   family 0 (E/W runs):      constant r
    ///   family 1 (SE/NW runs):    constant q
    ///   family 2 (SW/NE runs):    constant q + r
    /// Stones on one line sort by their along-position; the check is
    /// whether any three positions form an arithmetic progression
    /// (x, x+k, x+2k with k ≥ 1). The incremental formulation checks
    /// only lines through the NEW stone when `newStone` is given —
    /// a triple not involving the new stone existed before the action
    /// and already failed legality then (the laws are invariant under
    /// legal play, INV-1).
    public static func violated(_ stones: [Stone], newStone: Stone? = nil) -> Bool {
        if let added = newStone {
            return linesThrough(added, in: stones)
        }
        // Full check: any triple anywhere (used by tests and the
        // INV-1 audit).
        for direction in 0..<3 {
            var lines: [Int: [Int]] = [:]
            for stone in stones {
                let (key, t) = lineKeyAndPosition(stone.cell, direction: direction)
                lines[key, default: []].append(t)
            }
            for positions in lines.values where positions.count >= 3 {
                if hasArithmeticTriple(positions) {
                    return true
                }
            }
        }
        return false
    }

    /// The incremental check: only triples that INCLUDE `added` can be
    /// new. For each line family, gather the stones on `added`'s line
    /// and test whether `added`'s position completes an arithmetic
    /// triple with two of them.
    static func linesThrough(_ added: Stone, in stones: [Stone]) -> Bool {
        for direction in 0..<3 {
            let (key, addedT) = lineKeyAndPosition(added.cell, direction: direction)
            var positions: [Int] = []
            for stone in stones {
                let (otherKey, otherT) = lineKeyAndPosition(stone.cell, direction: direction)
                if otherKey == key && stone.cell != added.cell {
                    positions.append(otherT)
                }
            }
            guard positions.count >= 2 else { continue }
            // addedT completes a triple when two positions satisfy
            // 2·p_mid = addedT + p_other with the right ordering, in
            // either arrangement: added as first, middle, or last.
            for i in 0..<positions.count {
                for j in (i + 1)..<positions.count {
                    let a = positions[i]
                    let b = positions[j]
                    // added first: addedT, a, b with a − addedT == b − a
                    if a - addedT == b - a && a != addedT {
                        return true
                    }
                    // added middle: a, addedT, b
                    if addedT - a == b - addedT && addedT != a {
                        return true
                    }
                    // added last: a, b, addedT
                    if b - a == addedT - b && b != addedT {
                        return true
                    }
                }
            }
        }
        return false
    }

    /// Family key (which line) and along-position for one direction.
    /// Family 0: lines of constant r, position = q.
    /// Family 1: lines of constant q, position = r.
    /// Family 2: lines of constant q + r, position = q (r is derived).
    private static func lineKeyAndPosition(
        _ cell: Hex, direction: Int
    ) -> (key: Int, position: Int) {
        switch direction {
        case 0: return (cell.r, cell.q)
        case 1: return (cell.q, cell.r)
        default: return (cell.q + cell.r, cell.q)
        }
    }

    /// True when three of the sorted positions form an arithmetic
    /// progression: x, x+k, x+2k with k ≥ 1.
    static func hasArithmeticTriple(_ positions: [Int]) -> Bool {
        guard positions.count >= 3 else { return false }
        let sorted = positions.sorted()
        var i = 0
        while i < sorted.count - 2 {
            var j = i + 1
            while j < sorted.count - 1 {
                let needed = 2 * sorted[j] - sorted[i]
                var lo = j + 1
                var hi = sorted.count - 1
                while lo <= hi {
                    let mid = (lo + hi) / 2
                    if sorted[mid] == needed { return true }
                    if sorted[mid] < needed { lo = mid + 1 } else { hi = mid - 1 }
                }
                j += 1
            }
            i += 1
        }
        return false
    }
}
