// Movement.swift — R-8 sail path validation and enumeration.
//
// A sail path is the ordered list of cells a canoe ENTERS (ADR-0012).
// Validation and enumeration live here and must agree exactly:
// `validatePath` is the authority; `paths(for:in:)` enumerates the
// paths that validate clean, pruning with the same per-step checks
// (the agreement is tested).
//
// The movement model (§4 R-8 with A.1 R-18, ADR-0012):
//
// - A sail is straight-line: the canoe picks a direction and every
//   entered cell continues in that direction from the start.
// - Every entered sea cell carries strength ≥ 1 (R-8); the rival
//   atoll cell that ends a landing is the one exception (R-10).
// - A step between two nodes costs 0 (node chain); every other step
//   costs 1; the whole path stays within Balance.sailRange. The
//   starting cell counts as whatever it is, and it never binds: a
//   canoe standing on a node may step off in any direction.
// - Once the path has entered a node, the canoe is on a node chain:
//   it may stop at any node it occupies (§4: entering a node ends
//   movement), but its only continuation is straight ahead, and only
//   while the cell ahead is also a node. When the cell ahead is not
//   a node the path must end at that node (A.1 R-18: "the path ends
//   on the first node that is not followed by a further node step").
//   Blocked chain ends (an island, atoll or canoe on the ahead node)
//   are legitimate stopping points.
// - Landing (R-10): entering a rival atoll cell ends the action. A
//   canoe that has entered a node on this path rides the chain to its
//   end and stops short of the atoll; only a canoe that has entered
//   no node may step into the atoll cell.

public enum Movement {
    /// Validate `path` for canoe `id` in `state` (R-8, R-18). Returns
    /// the reason the path is illegal, or nil.
    public static func validatePath(
        _ path: [Hex], for id: CanoeID, in state: GameState
    ) -> IllegalReason? {
        guard !path.isEmpty else { return .pathEmpty }
        guard case .sea(let start) = state.canoes[id].map(\.location) else {
            return .notOnBoard(id)
        }
        precondition(
            state.canoe(id).owner == state.toMove, "validatePath is for the mover's canoe")
        let rivalCells = Set(state.chart.atoll(for: state.toMove.opponent).cells)
        let ocean = state.chart.ocean

        // Straight-line (ADR-0012): every entered cell continues in the
        // direction of the first step.
        guard let direction = Hex.directionVectors.firstIndex(of: path[0] - start) else {
            return .badPathStep(start, path[0])
        }

        var cost = 0
        var enteredNode = false
        var current = start

        for (index, next) in path.enumerated() {
            guard next == current.neighbor(direction) else {
                return .badPathStep(current, next)
            }
            // Landing: entering a rival atoll cell ends the action.
            if rivalCells.contains(next) {
                guard index == path.count - 1 else { return .landingMidPath(next) }
                guard !enteredNode else { return .landingFromNode(current) }
                cost += 1
                guard cost <= Balance.sailRange else { return .pathTooLong(cost: cost) }
                return nil
            }
            guard ocean.contains(next) else { return .cellNotInOcean(next) }
            guard !state.islands.contains(next), !state.chart.atollCells.contains(next) else {
                return .cellOccupied(next)
            }
            if state.canoe(at: next) != nil { return .cellHasCanoe(next) }
            guard state.field.strength(at: next) > Balance.becalmedStrength else {
                return .pathCellCalm(next)
            }

            let currentIsNode = state.field.isNode(current)
            let nextIsNode = state.field.isNode(next)
            // Leaving a chain: once a node has been entered, the only
            // continuation is the node straight ahead (R-18, ADR-0012).
            if enteredNode, !nextIsNode {
                return .nodeExit(current)
            }
            cost += (currentIsNode && nextIsNode) ? 0 : 1
            guard cost <= Balance.sailRange else { return .pathTooLong(cost: cost) }
            if nextIsNode { enteredNode = true }
            current = next
        }
        return nil
    }

    /// Every sail path the mover's canoe could take: every path that
    /// `validatePath` accepts, enumerated direction by direction with
    /// identical per-step pruning (the agreement is tested). A sail is
    /// straight-line, so at most six walks of at most
    /// Balance.maxPathCells steps are explored (ADR-0007).
    public static func paths(for id: CanoeID, in state: GameState) -> [[Hex]] {
        guard case .sea(let start) = state.canoes[id].map(\.location) else { return [] }
        let rivalCells = Set(state.chart.atoll(for: state.toMove.opponent).cells)
        let ocean = state.chart.ocean
        let field = state.field

        var results: [[Hex]] = []

        for direction in 0..<6 {
            var cost = 0
            var enteredNode = false
            var current = start
            var path: [Hex] = []

            while path.count < Balance.maxPathCells {
                let next = current.neighbor(direction)

                // Landing branch: entering a rival atoll cell ends the
                // action, before any node has been entered (R-10, R-18).
                if rivalCells.contains(next) {
                    if !enteredNode, cost + 1 <= Balance.sailRange {
                        results.append(path + [next])
                    }
                    break
                }
                guard ocean.contains(next),
                    !state.islands.contains(next),
                    !state.chart.atollCells.contains(next),
                    state.canoe(at: next) == nil,
                    field.strength(at: next) > Balance.becalmedStrength
                else { break }

                let currentIsNode = field.isNode(current)
                let nextIsNode = field.isNode(next)
                if enteredNode, !nextIsNode { break }
                let newCost = cost + ((currentIsNode && nextIsNode) ? 0 : 1)
                guard newCost <= Balance.sailRange else { break }

                path.append(next)
                cost = newCost
                if nextIsNode { enteredNode = true }
                results.append(path)
                current = next
            }
        }
        return results
    }
}
