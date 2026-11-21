# Mattang — docs/DECISIONS.md

ADR log. Toolchain facts: Xcode 27.2, Swift 6 (strict concurrency `complete`), targets iOS/iPadOS 26.0 and macOS 26.0, XcodeGen project generation, SpriteKit rendering with a Metal 4 compute visual layer planned (P6).

## ADR-0001: Toolchain (Xcode 27.2, Swift 6 strict)

Adopted the installed toolchain: Xcode 27.2 (`xcodebuild -version` recorded in docs/STATUS.md evidence), Swift 6 language mode with strict concurrency `complete` for every package and app target. Reason: `_CONVENTIONS.md` §2 requires reproducible builds on the installed toolchain; strict concurrency catches data races before P1's parallel tracing work. Consequence: closure-valued `static let` properties are rejected; shared functions are `static func` (e.g. `Hex.opposite`).

## ADR-0002: Stack per §2

Adopted the conventions stack with the roadmap's additions: one code base, SwiftUI app shell (two targets, one source set), SpriteKit in `SpriteView` for the board, MTCore/MTContent/MTAI as pure deterministic Swift packages, MTPlatform as the only layer that imports UIKit/AppKit, MTMeta for the meta layer. Dependencies: none beyond the allow-list (no third-party packages at P0).

## ADR-0003: Discrete swell model

Core models swells as discrete straight rays on the axial hex grid, integer-only, up to 3 reflections per ray and 40 steps (R-3–R-5). No continuous wave physics in Core. Reason: determinism (INV-1, INV-4), testability against fixed fixtures, and sub-millisecond field updates for AI search. The continuous interference look is render-only (ADR-0005).

## ADR-0004: Reflection and refraction table

Reflection is computed by the closed-form `(2n − d + 3) mod 6` (R-12) and cross-checked at test time against the 6×6 hand table committed in `InteractionTable.swift` (36 cases). Vertex hits reverse (`d + 3`). Refraction (R-13, R-14) turns one step toward the island, ties clockwise, resolves double-island ties by lower row-major cell index. Reason: a single closed form avoids table/maths divergence; the hand table keeps the formula honest.

## ADR-0005: Visual field decoupled from Core

The Metal compute wave-field visual (P6) is driven by Core's ray set as render-only data and is never read back into Core state. Reason: Core must stay integer-only and deterministic; the shimmer/interference look is presentation. Gate evidence (G2/G6) shows preview and committed fields matching Core exactly.

## ADR-0006: Lint toolchain reconciliation

`swift-format` 604 (as installed) with the shared `.swift-format` config; SwiftLint `--strict` with custom rules for banned APIs (`SystemRandomNumberGenerator`, `Int.random`, `Date()`, `UUID()` in Core/Content/AI) as error severity, mirrored by `Tools/check-imports.sh` grep. Reason: both linters stay green in CI on macos-latest.

## ADR-0007: Path enumeration is straight-line and capped

`Movement.paths` walks at most one straight-line path per direction per canoe, and no path exceeds `Balance.maxPathCells` = `sailRange` + 24 entered cells (ADR-0012's straight-line ride makes six walks the whole space; the cap is a further safety bound for charts yet to be designed). Reason: with the ride model the enumeration is linear in board width, which keeps `legalActions` cheap enough for the AI and the sim; a freeform enumeration would be exponential on node-rich boards. Consequence: `paths` is complete for every chart (it lists exactly the paths `validatePath` accepts); the P1 tests check the agreement on every fixture chart.

## ADR-0008: Enclosure is the literal adjacency rule

R-21's "fully enclosed" is read literally: a placement is illegal when it would leave any canoe without a single adjacent enterable cell — a cell in the ocean that is not an island, not an atoll cell, not the new island, and not held by another canoe (R-20). A strength-0 cell still counts as enterable, because R-19 lets a becalmed canoe be towed onto any adjacent empty cell. For a canoe still at home, the test is that its atoll keeps at least one enterable launch cell (R-17). Only canoes adjacent to the new island — and atolls the placement touches — can be newly enclosed, so the check is local. Reason: the roadmap's wording is about adjacency, not reachability, and the local check is exact and cheap. Consequence: a canoe that keeps an enterable neighbour but no path out is not "enclosed"; the R-11 tie-break and R-23 govern dead positions instead.

## ADR-0009: Hand-written byte-stable Codable

`GameState`, `Field`, `CanoeState` and the landed-count pair implement `Codable` by hand with a fixed field order and sorted collections, so structurally equal states encode to identical bytes in every process and on every platform. Reason: stable bytes underpin state-equality checks in replay tests, fixture comparison, and the AI's later transposition table; synthesized Codable would serialize sets and dictionaries in an unspecified order. Consequence: adding a stored property to these types requires updating the encoder and decoder together (the compiler checks the pairs).

## ADR-0010: Tie-break is a path-distance sum

The R-11 tie-break scores each side by the sum, over its best sea canoes (up to `Balance.canoesToWin`), of the BFS path distance to a rival atoll cell under the §7 movement model (0-cost steps between nodes, +1 otherwise; islands, atolls and occupied cells block; R-18 commitment honored). The side with the smaller sum wins; a canoe with no reachable landing scores a fixed large constant; Player 2 wins when the sums are equal. Reason: the roadmap names path distance as the tie-break criterion. Consequence: the tie-break is pure board geometry and never consults the swell field.

## ADR-0011: Pass is legal only when forced

`.pass` is legal exactly when `Reducer.hasAnyNonPassAction` is false, mirroring the roadmap's rule that a player with no legal action passes. Reason: a voluntary pass would let a side dodge the R-9 becalm risk without cost. Consequence: a pass still flips the side to move, so it changes the position key and every pass registers a distinct R-23 entry.

## ADR-0012: Actions record the cells entered; a sail is a straight-line ride

`.sail` carries the full ordered list of cells the canoe enters (not the start cell), so a replay re-simulates exactly without re-deriving player intent. The movement model reads §4 R-8 ("entering a node ends movement unless the canoe continues along a node chain, which costs no range") together with A.1 R-18 ("the path ends on the first node that is not followed by a further node step") as a straight-line ride: the player picks one direction, every entered cell continues in that direction, a step between two nodes costs 0, every other step costs 1, and the whole path stays within `sailRange`. The canoe may stop at any point within range (including any node it has entered), but once a node has been entered its only continuation is straight ahead and only while the cell ahead is also a node; when the cell ahead is not a node the path must end there. The starting cell never binds: a canoe standing on a node may step off in any direction. Landing (entering a rival atoll cell) is barred once a node has been entered — the ride ends at the chain's end short of the atoll. A "further node step" counts only enterable cells (ocean, not an island or atoll, not holding a canoe), so a blocked chain end is a legal stopping point. Reason: the freeform alternative (turns and stops anywhere on node chains) is unbounded — a board with two full-sweep swells makes every cell a node, and enumerating all self-avoiding chain walks exploded exponentially; the first `Tools/sim` run hung on exactly that, and no UI could present such a move list. The straight-line reading keeps §4's stop-anywhere default, gives A.1's "first … not followed by a further node step" a determinate meaning, bounds `legalActions` (at most six walks per canoe), and keeps the §7/A.5 BFS distance model sensible as an optimistic metric. Consequence: `Movement.validatePath` and `Movement.paths` share the same per-step checks (their agreement is tested), every legal path's every prefix is legal, and enumeration is finite on every chart, including degenerate all-node ones.

## ADR-0013: Repetition via Zobrist position keys

R-23's "third identical position" is detected with `Zobrist.positionKey(of:)` — a stable-order hash of the whole state (canoes in `CanoeID` order, islands and cells in row-major Hex order, tables generated once from `SeededRNG` at a fixed seed) — accumulated in `GameState.visited` as a key-to-count map. A count reaching `Balance.repetitionLimit` ends the game by the R-11 tie-break. Reason: hashing makes the check O(1) per action, and the fixed seed makes keys identical across processes and platforms, which the AI's later search reuses. Consequence: hash equality is probabilistic identity; the P1 tests check that structurally equal positions produce equal keys across the shipped charts.

## ADR-0014: INV-6 holds on tie-free charts; R-14's row-major tie-break is not symmetry-covariant

R-14 breaks refraction ties by the lowest row-major cell index, which makes tracing deterministic but is not covariant under the chart symmetries: rotate180 reverses row-major order, so the image of a tied pair resolves the other way, and a tied ray's image diverges. INV-6 ("the field is symmetric under the chart's declared symmetry") therefore holds exactly when the chart's geometry never presents a ray's next cell adjacent to two unused obstacles — a tie-free chart. Reason: R-14's text fixes the tie-break; INV-6's property test is run on tie-free charts (the rotate180 test chart uses two paired full-sweep swells and a symmetric island triple, and the mirror chart's swells are self-mapped). Consequence: chart design in P3 must either avoid tie configurations or accept the documented asymmetry; a static tie check belongs in chart validation (filed for P3 content work).

## ADR-0015: Slice content ships radius 7 with pinned rim atolls

`two_swells_basic` carries `"radius": 7` — the §6 default, applied at content-authoring time because the §5 sample row omits the field and `ChartDef.radius` is a non-optional `Int` — with home atolls on the §A.3 radius-7 rim pattern, `p1` `[-7,3],[-7,4],[-6,3]` and `p2` `[7,-3],[7,-4],[6,-3]`, the same cells as the §A.3 `lagoon_mirror` row. Earlier content briefly said radius 5 with rim cells derived from it; that was the deviation, corrected 2026-11-21. The tests pin both the radius and the two cell sets so future drift fails loudly. The glossary gains the fourth neutral entry `gl_west_swell`, and `gl_nw_swell` reads "dominant" (NW is one of the slice's two dominant swells); all four swell entries stay `pending` for the advisor. Open-question 3 stays at its default: "Mattang" remains the working title until the advisor answers issue #12; the app continues under it.

## ADR-0016: The G2 sharpened check runs in P3 as a recorded addendum

A.7 sharpens G2 with "a scripted UI test of the 'one island, one swell' lesson shows the predicted node highlight matching Core" — but the tutorial (MT-P3.2) did not exist when G2 was signed, so the check was neither run nor recorded as SUBSTITUTED, a miss. Remedy, without rewriting pushed history: G2 keeps its sign-off, this ADR records the miss, and P3 runs the sharpened check as its first scripted-tutorial deliverable — lesson 1 ("one swell, no islands") ships with a scripted UI test whose predicted node highlight is compared against Core's field. Reason: the check needs the lesson to exist; the roadmap's phase order puts that lesson in P3, and the ADR keeps the miss auditable instead of silently absorbed. Consequence: the G3 evidence block carries both the addendum test's output and this ADR reference; the lesson-1 UI test stays in the suite permanently.

## ADR-0019: The G3 puzzle set is the 1-ply spotting tier; multi-ply lines are MT-P4.2

§7's puzzle line ("mining positions with forced landings within N plies") is realized for G3 as 1-ply land-in puzzles: the hero canoe is at sea within a landing ride of the rival atoll, and verification demands that exactly ONE legal action of the side to move lands a canoe (a landing ends the game, so no defense search exists at this depth — uniqueness is the whole discipline). The §5 sample row's `plies: 2` is illustrative (ADR-0015's reading of sample rows); the shipped rows carry `plies: 1`. Reason: the full multi-ply AND/OR verification (every defender reply, island placements included — each placement re-traces the whole field) costs minutes per candidate and produced zero verified rows in a 25-minute run; the P4 miner (MT-P4.2, `MTAI/PuzzleGenerator`) owns the multi-ply machinery with proper move pruning and a 120-puzzle budget, and G3's launch set must be verifiable in seconds. Consequence: `puzzles.json` ships 30 rows with `plies: 1`, every row re-verified by the miner before writing and independently re-verified by MTContent's loader tests (the uniqueness check enumerates ALL mover actions, not just sails); a `plies ≥ 2` row remains decodable and loadable for P4's generator, whose tests will carry the AND/OR verifier.

## ADR-0017: lagoon_mirror is authored tie-free with paired full-sweep swells

The §A.3 `lagoon_mirror` sample row declares `rotate180` symmetry over the slice swell set (east/north dominant, west/south minor). Weights 2 and 1 are not half-turn symmetric (a rotate180 image of the swell pattern would pair a dominant swell with a minor one), so under ADR-0014's precedence reading (INV-6 governs what ships; sample rows are illustrative) the row is a shape to fill in, not a byte-exact spec. Shipped form: radius 7 with the sample's atoll cells, a rotate180-paired swell set — two full-sweep dominants on opposite sides entering in directions that cross at the centre, paired with two full-sweep minors likewise paired — and a single preIsland `[0, 0]`, mirroring the P1 INV-6 test chart's construction so the tie-free property the INV-6 test relies on holds. `crossroads` and `single_swell` complete the four-chart G3 set (none/mirror symmetries respectively) with the same tie-free discipline; a static tie check on shipped charts is added to chart validation so future content fails loudly rather than silently violating INV-6. Reason: A.4's per-chart acceptance runs on real games, which need valid charts; INV-6 is a shipped invariant, the sample row is not. Consequence: `two_swells_basic` (none), `lagoon_mirror` (rotate180), `crossroads` (none), and `single_swell` (mirror) make the G3 count with every chart passing `Chart.validate`, the new tie check, and the INV-6 property test at their declared symmetry.
