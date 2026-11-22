// Tracer.swift — the swell ray tracer (R-3..R-6, R-12..R-16).
//
// Each swell emits one ray from every sea edge cell on its entry side
// (R-3); an edge cell occupied by an island or atoll cell blocks that
// entry and emits no ray (docs/DECISIONS.md). A ray marches one cell
// at a time:
//
// - If its next step would leave the ocean, the ray ends there (R-5).
// - If its next cell is an island or atoll cell (R-16), the ray
//   reflects off the struck face per InteractionTable (R-4, R-12);
//   the island cell never joins the path. Reaching the reflection cap
//   (§6: Balance.maxReflections) ends the ray (R-5), and reflections
//   do not consume steps.
// - Otherwise, if its next cell is adjacent to an island the ray has
//   not yet refracted toward, the ray moves into that cell and turns
//   one step toward that island — clockwise or counter-clockwise,
//   whichever points the following step closer to the island centre,
//   ties clockwise (R-13). Among several islands the lowest
//   row-major index wins (R-14). Each island refracts a given ray at
//   most once.
// - A ray ends after 40 steps (R-5).
//
// Rays never enter island or atoll cells, so path cells — and the
// swell masks and strengths built from them (R-6, R-15) — cover sea
// cells only. Rays of the same swell do not interact (R-15).

public enum Tracer: Sendable {
    /// Trace one ray from `start` (a sea cell) travelling in
    /// `direction`, against `obstacles` (island and atoll cells).
    public static func traceRay(
        ocean: Ocean,
        obstacles: Set<Hex>,
        swell: String,
        start: Hex,
        direction: Int
    ) -> RayPath {
        precondition(ocean.contains(start), "ray must start inside the ocean")
        precondition(!obstacles.contains(start), "ray must start on a sea cell")

        var cells: [Hex] = [start]
        var reflections = 0
        var refractedToward: Set<Hex> = []
        var position = start
        var heading = direction
        var steps = 0

        while true {
            let next = position.neighbor(heading)

            // R-5: leaving the ocean ends the ray.
            guard ocean.contains(next) else {
                return RayPath(
                    swell: swell, cells: cells,
                    reflections: reflections, termination: .leftOcean)
            }

            // R-4/R-12: an island or atoll cell reflects the ray off
            // the face it struck; the island cell never joins the path.
            if obstacles.contains(next) {
                heading = Hex.reflect(
                    incoming: heading, striking: Hex.faceStruck(by: heading))
                reflections += 1
                if reflections >= Balance.maxReflections {
                    return RayPath(
                        swell: swell, cells: cells,
                        reflections: reflections, termination: .maxReflections)
                }
                continue
            }

            // R-13/R-14: refraction toward an unused island beside the
            // next cell — the ray passes that cell, then bends toward
            // the island.
            let island = refractionTarget(
                from: next, obstacles: obstacles, alreadyUsed: refractedToward)
            position = next
            cells.append(next)
            steps += 1
            if let island {
                refractedToward.insert(island)
                heading = turnToward(from: position, heading: heading, island: island)
            }

            // R-5: the 40-step cap ends the ray.
            if steps == 40 {
                return RayPath(
                    swell: swell, cells: cells,
                    reflections: reflections, termination: .maxSteps)
            }
        }
    }

    /// Trace every swell's rays over the ocean (R-3), in swell order
    /// then edge row-major order.
    public static func trace(
        ocean: Ocean,
        swells: [Swell],
        islands: Set<Hex>,
        atollCells: Set<Hex>
    ) -> [RayPath] {
        trace(ocean: ocean, swells: swells, obstacles: islands.union(atollCells))
    }

    /// Trace every swell's rays against a merged obstacle set.
    /// `entryEdges` supplies the per-swell entry arcs (Chart memoizes
    /// them); pass nil to compute them here (the full-trace path).
    static func trace(
        ocean: Ocean,
        swells: [Swell],
        obstacles: Set<Hex>,
        entryEdges: [String: [Hex]]? = nil
    ) -> [RayPath] {
        var rays: [RayPath] = []
        for swell in swells {
            let edge = entryEdges?[swell.id] ?? ocean.edge(swell.entrySide)
            for start in edge where !obstacles.contains(start) {
                rays.append(
                    traceRay(
                        ocean: ocean, obstacles: obstacles, swell: swell.id,
                        start: start, direction: swell.direction))
            }
        }
        return rays
    }

    /// R-13/R-14: the island the ray would refract toward when its
    /// next cell is `next` — the unused obstacle adjacent to `next`
    /// with the lowest row-major index — or nil for a plain step.
    static func refractionTarget(
        from next: Hex,
        obstacles: Set<Hex>,
        alreadyUsed: Set<Hex>
    ) -> Hex? {
        // The scan order must equal row-major (r, then q): probe the
        // six neighbors of `next` and pick the obstacle with the least
        // (r, q) that has not been used. Equivalent to the former
        // whole-set subtract/filter/sort, ~40× fewer operations per
        // ray step (the tracer runs inside every search leaf).
        var best: Hex?
        var bestKey: (r: Int, q: Int)?
        for delta in Hex.directionVectors {
            let candidate = next + delta
            guard obstacles.contains(candidate),
                !alreadyUsed.contains(candidate)
            else { continue }
            let key = (candidate.r, candidate.q)
            if let current = bestKey, !(key < current) { continue }
            bestKey = key
            best = candidate
        }
        return best
    }

    /// R-13: one step toward `island` — clockwise (heading + 1) or
    /// counter-clockwise (heading − 1), whichever points the next
    /// step closer to the island centre; ties turn clockwise.
    static func turnToward(from cell: Hex, heading: Int, island: Hex) -> Int {
        let cw = flooredMod(heading + 1, 6)
        let ccw = flooredMod(heading + 5, 6)
        let towardCW = cell.neighbor(cw).distance(to: island)
        let towardCCW = cell.neighbor(ccw).distance(to: island)
        return towardCW <= towardCCW ? cw : ccw
    }
}
