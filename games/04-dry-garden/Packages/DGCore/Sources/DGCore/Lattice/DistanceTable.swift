// DistanceTable.swift — precomputed hex-distance lookup per courtyard.
//
// The roadmap (§2 Tech Stack) calls for a precomputed distance table per
// courtyard: influence (R-9) queries distances constantly during search,
// and a flat table turns each query into two array reads.

public struct DistanceTable: Sendable {
    /// Flattened square table indexed by [fromIndex * count + toIndex].
    private let distances: [Int]
    /// Row-major cell order, matching the input list exactly.
    public let cells: [Hex]
    private let index: [Hex: Int]

    /// Builds the table over the given cells with the axial cube
    /// distance (R-16).
    public init(cells: [Hex]) {
        precondition(!cells.isEmpty, "distance table needs cells")
        self.cells = cells
        var map: [Hex: Int] = [:]
        for (i, cell) in cells.enumerated() { map[cell] = i }
        self.index = map
        let count = cells.count
        var table = [Int](repeating: 0, count: count * count)
        for i in 0..<count {
            for j in 0..<count {
                table[i * count + j] = cells[i].distance(to: cells[j])
            }
        }
        self.distances = table
    }

    public var count: Int { cells.count }

    /// Distance between two cells; both must belong to the table.
    public func distance(from a: Hex, to b: Hex) -> Int {
        guard let i = index[a], let j = index[b] else {
            preconditionFailure("distance table: cell not in courtyard")
        }
        return distances[i * count + j]
    }

    /// Distance from a cell to every cell, as a sparse map (convenience
    /// for influence sums over a radius).
    public func distances(from a: Hex) -> [Hex: Int] {
        guard let i = index[a] else {
            preconditionFailure("distance table: cell not in courtyard")
        }
        var result: [Hex: Int] = [:]
        for j in 0..<count {
            result[cells[j]] = distances[i * count + j]
        }
        return result
    }

    /// True when both cells belong to the table's courtyard.
    public func contains(_ cell: Hex) -> Bool {
        index[cell] != nil
    }
}
