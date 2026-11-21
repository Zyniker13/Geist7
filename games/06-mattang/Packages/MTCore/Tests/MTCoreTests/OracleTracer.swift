// OracleTracer.swift — an independent re-derivation of the ray rules
// (R-3..R-5, R-12..R-16), written from the rule text with a different
// structure (a recursive walker, local modular arithmetic) from
// Tracer's loop, so that agreement between the two is evidence rather
// than circularity. The literal fixtures in TracerFixtureTests pin the
// oracle's semantics to hand-traced paths.

import XCTest

@testable import MTCore

enum Oracle {
    static func mod6(_ v: Int) -> Int { (v % 6 + 6) % 6 }

    /// Every ray of every swell (R-3), against one obstacle set.
    static func rays(ocean: Ocean, swells: [Swell], obstacles: Set<Hex>) -> [RayPath] {
        var out: [RayPath] = []
        for swell in swells {
            for start in ocean.edge(swell.entrySide) where !obstacles.contains(start) {
                out.append(
                    walk(
                        ocean, obstacles, swell.id, start, swell.direction,
                        [start], 0, [], 0))
            }
        }
        return out
    }

    /// R-5: the ocean edge ends the ray. R-4/R-12/R-16: an island or
    /// atoll ahead reflects the ray back the way it came (the struck
    /// face is the one the ray enters through), up to the reflection
    /// cap. R-13/R-14: on entering a cell adjacent to an unused
    /// obstacle the ray bends one step toward the obstacle with the
    /// lowest row-major index, clockwise on a tie. R-5: forty moves
    /// end the ray.
    static func walk(
        _ ocean: Ocean, _ obstacles: Set<Hex>, _ swell: String,
        _ here: Hex, _ heading: Int, _ seen: [Hex], _ bounces: Int,
        _ bentToward: Set<Hex>, _ moves: Int
    ) -> RayPath {
        let ahead = here.neighbor(heading)
        if !ocean.contains(ahead) {
            return RayPath(swell: swell, cells: seen, reflections: bounces, termination: .leftOcean)
        }
        if obstacles.contains(ahead) {
            if bounces + 1 >= Balance.maxReflections {
                return RayPath(
                    swell: swell, cells: seen, reflections: bounces + 1,
                    termination: .maxReflections)
            }
            return walk(
                ocean, obstacles, swell, here, mod6(heading + 3), seen,
                bounces + 1, bentToward, moves)
        }
        let candidates = obstacles.subtracting(bentToward).filter { ahead.distance(to: $0) == 1 }
        let target = candidates.min { ($0.r, $0.q) < ($1.r, $1.q) }
        var next = heading
        if let t = target {
            let cw = mod6(heading + 1)
            let ccw = mod6(heading + 5)
            next =
                ahead.neighbor(cw).distance(to: t) <= ahead.neighbor(ccw).distance(to: t)
                ? cw : ccw
        }
        if moves + 1 >= 40 {
            return RayPath(
                swell: swell, cells: seen + [ahead], reflections: bounces,
                termination: .maxSteps)
        }
        return walk(
            ocean, obstacles, swell, ahead, next, seen + [ahead], bounces,
            target.map { bentToward.union([$0]) } ?? bentToward, moves + 1)
    }
}
