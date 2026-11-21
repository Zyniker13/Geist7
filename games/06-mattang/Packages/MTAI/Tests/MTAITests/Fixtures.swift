// Fixtures.swift — hand-authored charts, fields, and states for the
// MTAI tests.
//
// The field is injected directly (Field's public init), so every
// expected distance and score below is derivable by hand from the
// listed cells; no test depends on the tracer's output. INV-8 is kept:
// a canoe marked becalmed stands on a calm cell, the rest on strong
// ones.

import MTCore
@testable import MTAI

enum Fixtures {
    /// p1's home atoll on the southwest rim of the radius-3 test ocean.
    static let p1Atoll: Set<Hex> = [Hex(-3, 1), Hex(-3, 2), Hex(-2, 2)]
    /// p2's home atoll on the east rim; (3, -1) sits beside the r-0
    /// corridor's east end (2, 0).
    static let p2Atoll: Set<Hex> = [Hex(3, -1), Hex(3, -2), Hex(2, -2)]

    /// A radius-3 test chart with the rim atolls above. The swell list
    /// only has to satisfy Chart's shape; hand-injected fields carry
    /// the strengths the tests reason about.
    static func chart(radius: Int = 3, swells: [Swell]? = nil) -> Chart {
        Chart(
            id: "test-chart",
            radius: radius,
            swells: swells ?? [Swell.minor(id: "s1", entrySide: 0, direction: 3)],
            preIslands: [],
            atolls: [
                Atoll(player: .p1, cells: p1Atoll),
                Atoll(player: .p2, cells: p2Atoll),
            ],
            symmetry: .none)
    }

    /// The slice chart's full geometry: the four content swells and
    /// the §A.3 radius-7 rim atolls, for Sailor self-play.
    static func sliceChart() -> Chart {
        Chart(
            id: "two_swells_basic",
            radius: 7,
            swells: [
                Swell.major(id: "east_dom", entrySide: 0, direction: 3),
                Swell.major(id: "north_dom", entrySide: 4, direction: 1),
                Swell.minor(id: "west_min", entrySide: 3, direction: 0),
                Swell.minor(id: "south_min", entrySide: 1, direction: 4),
            ],
            preIslands: [],
            atolls: [
                Atoll(player: .p1, cells: [Hex(-7, 3), Hex(-7, 4), Hex(-6, 3)]),
                Atoll(player: .p2, cells: [Hex(7, -3), Hex(7, -4), Hex(6, -3)]),
            ],
            symmetry: .none)
    }

    /// A hand-authored field: `strong` maps cells to strengths; cells
    /// in `nodes` carry two distinct swell ids so `Field.isNode` holds.
    static func field(strong: [Hex: Int], nodes: Set<Hex> = []) -> Field {
        var swells: [Hex: SwellMask] = [:]
        var strength: [Hex: Int] = [:]
        for (cell, value) in strong {
            strength[cell] = value
            swells[cell] = nodes.contains(cell) ? ["s1", "s2"] : ["s1"]
        }
        return Field(swells: swells, strength: strength, rays: [])
    }

    /// The r-0 corridor cells (-2...2, 0), minus any `gaps`, with the
    /// given cells made nodes (strength 2, two swells).
    static func corridor(gaps: Set<Hex> = [], nodes: Set<Hex> = []) -> Field {
        var strong: [Hex: Int] = [:]
        for q in -2...2 {
            let cell = Hex(q, 0)
            guard !gaps.contains(cell) else { continue }
            strong[cell] = nodes.contains(cell) ? 2 : 1
        }
        return field(strong: strong, nodes: nodes)
    }

    /// A GameState over `chart` with a hand-authored field. Unlisted
    /// canoes sit at home; `pool` defaults to 0 so placement actions
    /// stay out of the way unless a test asks for them.
    static func state(
        chart: Chart,
        field: Field,
        islands: Set<Hex> = [],
        pool: Int = 0,
        locations: [CanoeID: CanoeLocation] = [:],
        becalmed: Set<CanoeID> = [],
        landed: [PlayerID: Int] = [.p1: 0, .p2: 0],
        toMove: PlayerID = .p1
    ) -> GameState {
        var canoes: [CanoeID: CanoeState] = [:]
        for id in CanoeID.allCanoeIDs {
            canoes[id] = CanoeState(
                owner: id.player,
                location: locations[id] ?? .home,
                becalmed: becalmed.contains(id))
        }
        return GameState(
            chart: chart, islands: islands, poolRemaining: pool,
            canoes: canoes, landed: landed, toMove: toMove,
            stuckTurns: 0, field: field, status: .ongoing)
    }
}
