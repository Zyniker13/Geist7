// Axis.swift — mirror-axis enumeration over a hex lattice (R-17).
//
// A reflection family maps a cell onto its mirror image in the lattice:
// point symmetry through cell centres is a point map, while the
// edge-midpoint families are its "half-step" counterparts. Each family
// is indexed by one integer `offset`, so an axis is (family, offset)
// and enumerating every axis within a bounding box is a bounded loop.
//
// Reflection formulas (verified as exact involutions on Z²):
//   family 0, edge (0 deg):    (q, r) -> (q + r − k, 2k − r)
//   family 1, centre (90 deg): (q, r) -> (e − q − r, r)
//   family 2, centre (30 deg): (q, r) -> (r + d, q − d)
//   family 3, edge (60 deg):   (q, r) -> (2n − q, q + r − n)
//   family 4, edge (120 deg):  (q, r) -> (n − r, n − q)
//   family 5, centre (150 deg):(q, r) -> (q, −q − r + e)
//
// The centre families fix a cell (the axis runs through it) when the
// offset matches the cell's position; the edge families fix an edge
// midpoint. The formulas above are the exact lattice reflections; a
// sweep that tries every offset of every family therefore visits every
// mirror axis of the lattice, in both senses A.1 R-17 admits.

public enum AxisFamily: Int, Codable, Sendable, CaseIterable {
    case horizontal = 0
    case vertical = 1
    case diagonal30 = 2
    case diagonal60 = 3
    case diagonal120 = 4
    case diagonal150 = 5
}

/// One mirror axis: which of the six reflection families, and the
/// family's offset along it (stored in `CourtyardDef.axes`, R-17).
public struct Axis: Hashable, Codable, Sendable {
    public var family: Int
    public var offset: Int

    public init(family: Int, offset: Int) {
        self.family = family
        self.offset = offset
    }

    /// Reflect a hex through this axis (exact lattice reflection).
    public func reflect(_ h: Hex) -> Hex {
        let q = h.q
        let r = h.r
        let k = offset
        switch family {
        case 0: return Hex(q + r - k, 2 * k - r)
        case 1: return Hex(k - q - r, r)
        case 2: return Hex(r + k, q - k)
        case 3: return Hex(2 * k - q, q + r - k)
        case 4: return Hex(k - r, k - q)
        case 5: return Hex(q, -q - r + k)
        default:
            preconditionFailure("unknown axis family \(family)")
        }
    }
}

public enum AxisEnumeration {
    /// Every axis (family, offset) whose reflection keeps at least
    /// `threshold` of `cells` on the lattice itself (R-17: 70% of
    /// non-feature cells mapping onto non-feature cells). Offsets run
    /// over the full axial bounding box of the cells, so the result is
    /// independent of the order the cells are listed in (INV-6's
    /// order-independence applies to the axis set too).
    public static func axesInPlay(
        cells: [Hex],
        threshold: Double = 0.70,
        areTargets: ((Hex) -> Bool)? = nil
    ) -> [(family: Int, offset: Int, mapped: Int)] {
        precondition(!cells.isEmpty, "axis enumeration needs cells")
        precondition(threshold >= 0 && threshold <= 1, "threshold is a fraction")
        let total = cells.count
        let lattice = Set(cells)
        // A reflection target counts only when `areTargets` accepts it;
        // nil means the whole cell set (the plain-lattice sweep).
        let accepts = areTargets ?? { lattice.contains($0) }

        var qMin = Int.max
        var qMax = Int.min
        var rMin = Int.max
        var rMax = Int.min
        for cell in cells {
            qMin = min(qMin, cell.q)
            qMax = max(qMax, cell.q)
            rMin = min(rMin, cell.r)
            rMax = max(rMax, cell.r)
        }
        // Bounds are generous: each family's offset sweeps its whole
        // bounding interval, so no axis is missed by a boundary cell.
        let ranges: [[Int]] = [
            Array(rMin - 3...rMax + 3),  // family 0 (k)
            Array((2 * qMin + rMin - 3)...(2 * qMax + rMax + 3)),  // family 1 (e = 2q + r)
            Array((qMin - rMax - 3)...(qMax - rMin + 3)),  // family 2 (d = q − r)
            Array(qMin - 3...qMax + 3),  // family 3 (n = q)
            Array((qMin + rMin - 3)...(qMax + rMax + 3)),  // family 4 (n = q + r)
            Array((qMin + 2 * rMin - 3)...(qMax + 2 * rMax + 3)),  // family 5 (e = q + 2r)
        ]

        var result: [(family: Int, offset: Int, mapped: Int)] = []
        for family in 0...5 {
            let range = ranges[family]
            if range.isEmpty { continue }
            for offset in range {
                let axis = Axis(family: family, offset: offset)
                var mapped = 0
                for cell in cells where accepts(axis.reflect(cell)) {
                    mapped += 1
                }
                if Double(mapped) >= Double(total) * threshold {
                    result.append((family, offset, mapped))
                }
            }
        }
        result.sort { lhs, rhs in
            if lhs.family != rhs.family { return lhs.family < rhs.family }
            return lhs.offset < rhs.offset
        }
        return result
    }
}
