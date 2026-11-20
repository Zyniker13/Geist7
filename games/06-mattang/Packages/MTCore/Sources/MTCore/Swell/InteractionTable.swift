// InteractionTable.swift — R-12 swell reflection table.
//
// The complete ray–island interaction table for a hex grid: a ray
// travelling in direction `d` that strikes an island face with outward
// normal direction `n` leaves in `out`. 6 incoming directions × 6
// face normals = 36 cases, enumerated by hand in Mattang ROADMAP
// Appendix A.6 and mirrored here as the literal table below.
//
// MT-P0.1 acceptance: `InteractionTable.reflect(d, n)` returns the
// hand table entry for all 36 cases, and the closed-form
// `Hex.reflect(incoming:striking:)` agrees with the table everywhere.

public enum InteractionTable: Sendable {
    /// out[d][n] — the R-12 A.6 hand table, all 36 cases.
    /// Row = incoming direction d (0–5), column = struck face normal n (0–5).
    ///
    ///   n:      0  1  2  3  4  5
    /// d = 0:   3  5  1  3  5  1
    /// d = 1:   2  4  0  2  4  0
    /// d = 2:   1  3  5  1  3  5
    /// d = 3:   0  2  4  0  2  4
    /// d = 4:   5  1  3  5  1  3
    /// d = 5:   4  0  2  4  0  2
    public static let reflect: [[Int]] = [
        [3, 5, 1, 3, 5, 1],
        [2, 4, 0, 2, 4, 0],
        [1, 3, 5, 1, 3, 5],
        [0, 2, 4, 0, 2, 4],
        [5, 1, 3, 5, 1, 3],
        [4, 0, 2, 4, 0, 2],
    ]

    /// Table lookup with precondition bounds checking.
    public static func out(incoming d: Int, striking n: Int) -> Int {
        precondition((0..<6).contains(d), "direction out of range: \(d)")
        precondition((0..<6).contains(n), "face normal out of range: \(n)")
        return reflect[d][n]
    }
}
