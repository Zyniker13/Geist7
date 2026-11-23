// Courtyard.swift — the courtyard: a mask of lattice cells plus fixed
// features (R-1, R-16).
//
// The mask is a row-string grid: row index = r, column index = c, and
// the axial coordinate of mask cell (c, r) is q = c − r / 2 (floor
// division), the odd-r offset layout that pairs with the pointy-top
// direction convention in `Hex`. `#` marks a courtyard cell, `.` marks
// the wall (outside). Feature cells (moss, basin) sit on courtyard
// cells and cannot hold stones (R-1, R-20) but can be owned (R-24).

public enum CourtyardError: Error, Equatable {
    case emptyMask
    case raggedRow(row: Int)
    case featureOutsideMask(q: Int, r: Int)
}

public struct Feature: Hashable, Codable, Sendable {
    public var cell: Hex
    /// Raw kind string from content: "moss", "basin", "lantern".
    public var kind: String

    public init(cell: Hex, kind: String) {
        self.cell = cell
        self.kind = kind
    }
}

public struct Courtyard: Hashable, Codable, Sendable {
    /// Content identifier, e.g. "long_wall".
    public var id: String
    /// Display name, e.g. "Long Wall".
    public var name: String
    /// Every courtyard cell (mask `#`), in row-major order.
    public var cells: [Hex]
    /// Cells that hold fixed features and cannot receive stones.
    public var features: [Feature]
    /// "bottom" is the veranda edge (R-3); only "bottom" exists at P0.
    public var veranda: String
    /// Mirror axes in play (R-17's 70% filter), precomputed at load.
    public var axes: [Axis]

    public init(
        id: String, name: String, cells: [Hex], features: [Feature],
        veranda: String, axes: [Axis]
    ) {
        self.id = id
        self.name = name
        self.cells = cells
        self.features = features
        self.veranda = veranda
        self.axes = axes
    }

    // MARK: Parsing (DG-P0.2)

    /// Parses a row-string mask into cells. Row `r` of the mask is the
    /// string at index `r`; column `c` maps to axial q = c − r / 2.
    /// All rows must be the same length (the wall is part of the mask).
    public static func parse(
        id: String, name: String, mask: [String],
        features: [Feature], veranda: String
    ) throws -> Courtyard {
        guard !mask.isEmpty else { throw CourtyardError.emptyMask }
        let width = mask[0].count
        var cells: [Hex] = []
        var onMask = Set<Hex>()
        for (r, row) in mask.enumerated() {
            guard row.count == width else {
                throw CourtyardError.raggedRow(row: r)
            }
            for (c, character) in row.enumerated() where character == "#" {
                let hex = Hex(q: c - r / 2, r: r)
                cells.append(hex)
                onMask.insert(hex)
            }
        }
        for feature in features where !onMask.contains(feature.cell) {
            throw CourtyardError.featureOutsideMask(
                q: feature.cell.q, r: feature.cell.r)
        }
        // R-17: the 70% filter runs over NON-FEATURE cells, and an
        // axis is in play when its reflection maps at least 70% of
        // those cells onto non-feature cells (stones reflecting onto a
        // wall or a feature cell break symmetry, R-18).
        let featureCells = Set(features.map(\.cell))
        let nonFeature = cells.filter { !featureCells.contains($0) }
        let axes = AxisEnumeration.axesInPlay(
            cells: nonFeature,
            areTargets: { !featureCells.contains($0) && onMask.contains($0) }
        ).map { Axis(family: $0.family, offset: $0.offset) }
        return Courtyard(
            id: id, name: name, cells: cells, features: features,
            veranda: veranda, axes: axes)
    }

    // MARK: Queries

    /// The set of courtyard cells (fast membership).
    public var cellSet: Set<Hex> {
        Set(cells)
    }

    /// Cells that can receive a stone: on the mask, not a feature.
    public var placeableCells: [Hex] {
        let featureCells = Set(features.map(\.cell))
        return cells.filter { !featureCells.contains($0) }
    }

    /// True when the cell is a feature cell (moss or basin, R-1).
    public func isFeature(_ cell: Hex) -> Bool {
        features.contains { $0.cell == cell }
    }
}
