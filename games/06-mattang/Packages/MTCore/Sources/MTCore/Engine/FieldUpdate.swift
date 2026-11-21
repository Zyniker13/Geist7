// FieldUpdate.swift — incremental swell-field updates (INV-9).
//
// INV-9: after an island placement the field must equal a full
// retrace, and the update must stay within the update budget. Only
// the swells whose rays or entry sides the new island touches can
// change; everything else is copied from the previous field.

public enum FieldUpdate {
    /// The field after placing an island on `cell`. Equal to
    /// `Field.compute` on the same inputs (INV-9); faster because only
    /// touching swells are re-traced.
    public static func applyIslandPlacement(
        previous: Field,
        ocean: Ocean,
        swells: [Swell],
        islands: Set<Hex>,
        atollCells: Set<Hex>,
        placed cell: Hex
    ) -> Field {
        // The obstacle set always includes the new island, whether the
        // caller passed the pre- or post-placement island set.
        let obstacles = islands.union(atollCells).union([cell])

        // Which swells are affected? A swell changes when the new
        // island sits on one of its entry-side edge cells (its launch
        // rows change) or within one step of any cell one of its rays
        // covers: the island can end a ray one step early, reflect a
        // ray that was about to step into the island's cell, or
        // refract a ray passing one step away.
        var touching = Set<Int>()
        for (index, swell) in swells.enumerated() {
            if ocean.edge(swell.entrySide).contains(cell) {
                touching.insert(index)
            }
        }
        let nearCells = [cell] + cell.neighbors()
        for (index, swell) in swells.enumerated() where !touching.contains(index) {
            for ray in previous.rays where ray.swell == swell.id {
                if ray.cells.contains(where: { nearCells.contains($0) }) {
                    touching.insert(index)
                    break
                }
            }
        }

        // Re-trace the touching swells; copy the untouched swells'
        // rays verbatim.
        var traced: [(index: Int, rays: [RayPath])] = []
        var untouched: [(index: Int, rays: [RayPath])] = []
        for (index, swell) in swells.enumerated() {
            if touching.contains(index) {
                traced.append(
                    (
                        index,
                        Tracer.trace(
                            ocean: ocean, swells: [swell], obstacles: obstacles)
                    ))
            } else {
                untouched.append((index, previous.rays.filter { $0.swell == swell.id }))
            }
        }

        // Rays keep the full-trace order: swell order, then edge
        // row-major order within each swell. Sorted with an index tie
        // break so the order is stable (Swift's sort is unstable).
        let rays: [RayPath] = (traced + untouched)
            .sorted { $0.index < $1.index }
            .flatMap(\.rays)

        var masks: [Hex: SwellMask] = [:]
        for ray in rays {
            for rayCell in ray.cells {
                masks[rayCell, default: []].insert(ray.swell)
            }
        }
        var weights: [String: Int] = [:]
        for swell in swells { weights[swell.id] = swell.weight }
        var strength: [Hex: Int] = [:]
        for (rayCell, mask) in masks {
            strength[rayCell] = mask.reduce(0) { $0 + (weights[$1] ?? 0) }
        }

        return Field(swells: masks, strength: strength, rays: rays)
    }
}
