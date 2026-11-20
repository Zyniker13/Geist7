# Mattang — Rules

Authoritative rules specification for implementation, copied from `ROADMAP.md` §4 and Appendix A with rule IDs intact. `ROADMAP.md` stays the source of truth for design; this file is the rules text the test suite tags (`R-n`, `INV-n`).

## Setup

- R-1 The ocean is a hex region (default radius 7, 169 cells). Each player has a home atoll (3 cells) on opposite edges. Swells from `charts.json`: each swell has an entry side, direction, and weight (dominant 2, minor 1).
- R-2 Shared island pool: 10 islands. Each player has 4 canoes in their home atoll.

## Swells

- R-3 Each swell emits one ray from every edge cell on its entry side, travelling in its direction.
- R-4 Ray interaction with an island cell: if the ray enters the island cell, it reflects (direction reversed about the face normal per `InteractionTable`). If the ray passes a cell adjacent to an island on the island's leeward side, it refracts: direction turns one step toward the island. Atolls behave as islands.
- R-5 A ray terminates after leaving the ocean, after 3 reflections, or after 40 steps.
- R-6 A cell's swell set is the set of distinct swell ids whose rays pass through it. Strength = sum of the weights of distinct swells. A node is a cell with ≥ 2 distinct swells.

## Turn

- R-7 On a turn, the player does one of: `placeIsland(cell)` (empty, not adjacent to an atoll, not adjacent to another island, pool not empty), `launch` (a canoe from home onto an adjacent cell of strength ≥ 1), or `sail(canoe, path)`.
- R-8 Sailing: a canoe moves up to `sailRange` (default 3) steps along cells of strength ≥ 1; entering a node ends movement unless the canoe continues along a "node chain" (a node adjacent to another node), which costs no range. A canoe cannot enter a cell holding another canoe.
- R-9 A canoe on a cell whose strength drops to 0 after an island placement is "becalmed": it cannot move until strength returns or it is towed (a friendly canoe adjacent spends its turn to move it 1 step).
- R-10 A canoe entering any cell of the rival atoll lands and is removed from the board; it scores 1.

## Victory

- R-11 First to land 3 canoes wins. If the island pool is empty and neither player can move for two consecutive turns, the player with more landed canoes wins, then the player whose remaining canoes are closer by path distance, then Player 2.

## Invariants

- INV-1 Tracing is deterministic and order-independent (rays traced in any order give the same field).
- INV-2 The field recomputed from scratch equals the incremental update after every action.
- INV-3 Canoe count conservation (home + sea + landed = 4).
- INV-4 Replay determinism.
- INV-5 Every ray terminates within 40 steps.
- INV-6 The field is symmetric under the chart's declared symmetry (mirror charts produce mirrored fields; property test).
- INV-7 No island placement creates a path-disconnected home atoll (every atoll keeps ≥ 1 adjacent cell reachable by strength ≥ 1 at chart start).
- INV-8 Becalmed status is a pure function of the field and canoe position.
- INV-9 Incremental tracing touches only rays whose path intersects the placed island's neighbourhood; recomputation equals full trace (INV-2) and is ≤ 2 ms on A15.

## Balance Parameters (defaults; §6)

| Name | Default | Range | File |
| --- | --- | --- | --- |
| Ocean radius | 7 | 5–9 | `charts.json` |
| Island pool | 10 | 6–14 | `balance.json` |
| Canoes per player | 4 | 3–5 | `balance.json` |
| `sailRange` | 3 | 2–4 | `balance.json` |
| Refraction enabled | true | — | `balance.json` |
| Max reflections | 3 | 1–4 | `balance.json` |

## Appendix Rules (A.1)

### Field tracing

- R-12 Hex directions are indexed 0–5 clockwise from east. Reflection off an island face: incoming direction `d` striking the face whose outward normal is `n` leaves in direction `(2n − d + 3) mod 6`; when a ray enters an island cell through a vertex (two faces equidistant), it reverses (`d + 3`).
- R-13 Refraction (R-4) occurs at most once per island per ray, and only when the ray's next cell is adjacent to the island and not itself an island. The turn is one step toward the island (clockwise or counter-clockwise, whichever reduces distance to the island centre; ties turn clockwise).
- R-14 A ray that would refract toward two islands at once refracts toward the one with the lower cell index (row-major order), so tracing is deterministic.
- R-15 Rays from the same swell do not interact with each other; a cell counts each swell id once regardless of how many rays of that swell pass.
- R-16 Rival atoll cells are islands for tracing; home atolls likewise.

### Canoes

- R-17 Launch places a canoe on any empty cell adjacent to the home atoll with strength ≥ 1; launching does not consume sail range (the canoe cannot sail that turn).
- R-18 A sail path is a sequence of adjacent cells; each non-node step costs 1; a step from a node into an adjacent node costs 0 (node chain); the path ends on the first node that is not followed by a further node step, or when range is exhausted.
- R-19 Towing (R-9) moves a becalmed friendly canoe 1 step to any adjacent empty cell; the towed canoe may then move normally next turn.
- R-20 Canoes block other canoes but do not block rays.

### Islands

- R-21 Islands cannot be placed on a cell holding a canoe, nor so that any canoe would have no adjacent cell at all (fully enclosed).
- R-22 Pre-placed chart islands (`preIslands`) are permanent and count toward the 3-reflection limit like any island.

### Draw handling

- R-23 Threefold repetition of the full state (islands, canoes, side) ends the game by the R-11 tie-break.
