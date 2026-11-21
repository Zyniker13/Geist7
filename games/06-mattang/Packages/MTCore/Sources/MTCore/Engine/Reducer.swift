// Reducer.swift — the rules engine: validate and apply one action per
// turn (§5 Reducer: validate → new state + Event list).

public enum Reducer {
    /// The initial state of a game on `chart` (§5): pre-placed islands,
    /// a full island pool, all eight canoes at home, no one landed,
    /// player 1 to move, and the swell field of the initial islands.
    /// Charts must satisfy Chart.validate; invalid charts trap.
    public static func initial(chart: Chart) -> GameState {
        let problems = chart.validate()
        precondition(problems.isEmpty, "invalid chart \(chart.id): \(problems)")

        let field = Field.compute(
            ocean: chart.ocean, swells: chart.swells,
            islands: chart.preIslands, atollCells: chart.atollCells)

        var canoes: [CanoeID: CanoeState] = [:]
        for id in CanoeID.allCanoeIDs {
            canoes[id] = CanoeState(owner: id.player, location: .home, becalmed: false)
        }

        var state = GameState(
            chart: chart,
            islands: chart.preIslands,
            poolRemaining: Balance.islandPool,
            canoes: canoes,
            landed: [.p1: 0, .p2: 0],
            toMove: .p1,
            stuckTurns: 0,
            field: field,
            status: .ongoing)
        // R-23 (ADR-0013): the starting position is the first
        // occurrence of its key.
        state.visited[Zobrist.positionKey(of: state), default: 0] += 1
        return state
    }

    /// Is the action legal in this state?
    public static func isLegal(_ action: Action, in state: GameState) -> Bool {
        reason(action, in: state) == nil
    }

    /// Why the action is illegal, or nil when it is legal. Every
    /// reason maps to one rule in docs/RULES.md; tests reference them
    /// by rule id.
    public static func reason(_ action: Action, in state: GameState) -> IllegalReason? {
        if state.status.isOver { return .gameAlreadyOver }
        let mover = state.toMove

        switch action {
        case .placeIsland(let cell):
            guard state.poolRemaining > 0 else { return .poolEmpty }
            return Island.placementReason(cell, in: state)

        case .launch(let cell):
            guard !state.homeCanoeIDs(owner: mover).isEmpty else {
                return .noHomeCanoe(mover)
            }
            guard state.chart.ocean.contains(cell) else { return .cellNotInOcean(cell) }
            guard !state.islands.contains(cell),
                !state.chart.atollCells.contains(cell)
            else { return .cellOccupied(cell) }
            guard state.canoe(at: cell) == nil else { return .cellHasCanoe(cell) }
            guard state.field.strength(at: cell) > Balance.becalmedStrength else {
                return .cellStrengthZero(cell)
            }
            let home = state.chart.atoll(for: mover)
            guard home.cells.contains(where: { cell.isAdjacent(to: $0) }) else {
                return .notAdjacentToHomeAtoll(cell)
            }
            return nil

        case .sail(let id, let path):
            let canoe =
                state.canoes[id]
                ?? CanoeState(
                    owner: id.player, location: .home, becalmed: false)
            guard canoe.owner == mover else { return .notOwnedByMover(id) }
            guard canoe.location.isSea else { return .notOnBoard(id) }
            guard !canoe.becalmed else { return .becalmedCanoe(id) }
            return Movement.validatePath(path, for: id, in: state)

        case .tow(let id, let cell):
            let canoe =
                state.canoes[id]
                ?? CanoeState(
                    owner: id.player, location: .home, becalmed: false)
            guard canoe.owner == mover else { return .notOwnedByMover(id) }
            guard canoe.location.isSea else { return .notOnBoard(id) }
            guard canoe.becalmed else { return .notBecalmed(id) }
            guard case .sea(let towedFrom) = canoe.location else {
                return .notOnBoard(id)
            }
            guard cell.isAdjacent(to: towedFrom) else { return .towTargetIllegal(cell) }
            guard state.chart.ocean.contains(cell) else { return .cellNotInOcean(cell) }
            guard !state.islands.contains(cell),
                !state.chart.atollCells.contains(cell)
            else { return .cellOccupied(cell) }
            guard state.canoe(at: cell) == nil else { return .cellHasCanoe(cell) }
            // A friendly canoe must be alongside to spend its turn (R-19).
            let towerNearby = CanoeID.allCanoeIDs.contains { other in
                other != id
                    && state.canoe(other).owner == mover
                    && state.canoe(other).location.isSea
                    && state.canoeCell(other).isAdjacent(to: towedFrom)
            }
            guard towerNearby else { return .noAdjacentTower(id) }
            return nil

        case .pass:
            // Pass is legal only when nothing else is (ADR-0011).
            return hasAnyNonPassAction(state) ? .passNotForced : nil
        }
    }

    /// Applies a legal action and returns the new state plus its
    /// events. Illegal actions throw; validate first for control over
    /// the failure.
    @discardableResult
    public static func apply(
        _ action: Action, to state: GameState
    ) throws -> (state: GameState, events: [Event]) {
        if let why = reason(action, in: state) {
            throw ReducerError(action: action, reason: why)
        }
        var next = state
        var events: [Event] = []
        let mover = state.toMove

        switch action {
        case .placeIsland(let cell):
            // R-7: the island token joins the board and is traced.
            next.islands.insert(cell)
            next.poolRemaining -= 1
            next.field = FieldUpdate.applyIslandPlacement(
                previous: state.field, ocean: state.chart.ocean,
                swells: state.chart.swells,
                islands: next.islands, atollCells: state.chart.atollCells,
                placed: cell)
            events.append(.islandPlaced(cell))
            next.stuckTurns = 0

        case .launch(let cell):
            // R-17: the lowest-numbered home canoe launches.
            let id = state.homeCanoeIDs(owner: mover)[0]
            next.canoes[id] = CanoeState(
                owner: mover, location: .sea(cell), becalmed: false)
            events.append(.launched(id, cell))
            next.stuckTurns = 0

        case .sail(let id, let path):
            // R-8: follow the validated path; R-10: a path ending on
            // the rival atoll lands the canoe and leaves the board.
            let destination = path[path.count - 1]
            if state.chart.atoll(for: mover.opponent).cells.contains(destination) {
                next.canoes[id] = CanoeState(owner: mover, location: .landed, becalmed: false)
                next.landed[mover, default: 0] += 1
                events.append(.sailed(id, path))
                events.append(.landed(id))
            } else {
                next.canoes[id] = CanoeState(
                    owner: mover, location: .sea(destination), becalmed: false)
                events.append(.sailed(id, path))
            }
            next.stuckTurns = 0

        case .tow(let id, let cell):
            // R-19: the becalmed canoe moves one step; the tower spent
            // its turn by making this the mover's whole action.
            next.canoes[id] = CanoeState(owner: mover, location: .sea(cell), becalmed: false)
            events.append(.towed(id, cell))
            next.stuckTurns = 0

        case .pass:
            // R-11: a pass counts toward the stuck rule.
            next.stuckTurns += 1
        }

        // R-9: becalm exactly the sea canoes standing on strength-0
        // cells of the (possibly new) field; otherwise clear the flag.
        // Applied once, in CanoeID order, against the final field.
        for id in CanoeID.allCanoeIDs {
            var canoe = next.canoe(id)
            guard case .sea(let cell) = canoe.location else { continue }
            let shouldBecalm = next.field.strength(at: cell) == Balance.becalmedStrength
            if shouldBecalm != canoe.becalmed {
                canoe = CanoeState(
                    owner: canoe.owner, location: canoe.location, becalmed: shouldBecalm)
                next.canoes[id] = canoe
                if shouldBecalm { events.append(.becameBecalmed(id)) }
            }
        }

        // R-11: outright wins first, then the stuck rule.
        next.status = Victory.check(next)
        if !next.status.isOver, next.poolRemaining == 0, next.stuckTurns >= 2 {
            next.status = .tiebreak(Victory.tiebreakWinner(next))
        }
        if next.status.isOver, !state.status.isOver {
            events.append(.gameEnded(next.status))
        }

        // R-23 (ADR-0013): the position after the action is recorded;
        // its third occurrence ends the game by the R-11 tie-break.
        if !next.status.isOver {
            let key = Zobrist.positionKey(of: next)
            let count = (next.visited[key] ?? 0) + 1
            next.visited[key] = count
            if count >= Balance.repetitionLimit {
                next.status = .tiebreak(Victory.tiebreakWinner(next))
                events.append(.gameEnded(next.status))
            }
        }

        // R-11: turn cycle — the other side moves next.
        next.toMove = mover.opponent
        return (next, events)
    }

    /// Every legal action for the side to move, in a stable order
    /// (deterministic; INV-3's canoe-count conservation is tested
    /// separately): island placements row-major, launches row-major, sail
    /// paths per canoe in CanoeID order (each path in the order
    /// Movement.paths produces it), then tows row-major per canoe.
    /// `pass` appears alone when no other action is legal.
    public static func legalActions(in state: GameState) -> [Action] {
        guard !state.status.isOver else { return [] }
        let mover = state.toMove
        var actions: [Action] = []

        // Island placements, row-major over candidate cells (R-7).
        if state.poolRemaining > 0 {
            for cell in state.placeableCandidates()
            where Island.placementReason(cell, in: state) == nil {
                actions.append(.placeIsland(cell))
            }
        }

        // Launches, row-major over candidate cells (R-17).
        if !state.homeCanoeIDs(owner: mover).isEmpty {
            var launchCells: [Hex] = []
            for cell in state.chart.atoll(for: mover).cells {
                for neighbor in cell.neighbors()
                where state.chart.ocean.contains(neighbor) {
                    launchCells.append(neighbor)
                }
            }
            launchCells.sort(by: Hex.rowMajor)
            for cell in launchCells where reason(.launch(cell), in: state) == nil {
                actions.append(.launch(cell))
            }
        }

        // Sails (R-8): every enumerated path of every movable canoe.
        for id in CanoeID.allCanoeIDs {
            let canoe = state.canoe(id)
            guard canoe.owner == mover, canoe.location.isSea, !canoe.becalmed else { continue }
            for path in Movement.paths(for: id, in: state) {
                actions.append(.sail(id, path))
            }
        }

        // Tows (R-19), row-major per becalmed canoe.
        for id in CanoeID.allCanoeIDs {
            let canoe = state.canoe(id)
            guard canoe.owner == mover, canoe.location.isSea, canoe.becalmed else { continue }
            if case .sea(let from) = canoe.location {
                for cell in from.neighbors().sorted(by: Hex.rowMajor)
                where reason(.tow(id, cell), in: state) == nil {
                    actions.append(.tow(id, cell))
                }
            }
        }

        // Pass (R-11) only when nothing else is legal (ADR-0011).
        if actions.isEmpty { actions.append(.pass) }
        return actions
    }

    // MARK: - Internals

    /// Is there any non-pass action? Cheap necessary-condition checks
    /// that agree exactly with `legalActions` (the agreement is tested).
    static func hasAnyNonPassAction(_ state: GameState) -> Bool {
        let mover = state.toMove
        if state.poolRemaining > 0 {
            for cell in state.placeableCandidates()
            where Island.placementReason(cell, in: state) == nil {
                return true
            }
        }
        if !state.homeCanoeIDs(owner: mover).isEmpty {
            for cell in state.chart.atoll(for: mover).cells {
                for neighbor in cell.neighbors()
                where state.chart.ocean.contains(neighbor)
                    && reason(.launch(neighbor), in: state) == nil
                {
                    return true
                }
            }
        }
        for id in CanoeID.allCanoeIDs {
            let canoe = state.canoe(id)
            guard canoe.owner == mover, canoe.location.isSea, !canoe.becalmed else { continue }
            if case .sea(let from) = canoe.location {
                for neighbor in from.neighbors()
                where reason(.sail(id, [neighbor]), in: state) == nil {
                    return true
                }
            }
        }
        for id in CanoeID.allCanoeIDs {
            let canoe = state.canoe(id)
            guard canoe.owner == mover, canoe.location.isSea, canoe.becalmed else { continue }
            if case .sea(let from) = canoe.location {
                for cell in from.neighbors()
                where reason(.tow(id, cell), in: state) == nil {
                    return true
                }
            }
        }
        return false
    }
}

extension GameState {
    /// The cell of a sea canoe; precondition failure otherwise.
    public func canoeCell(_ id: CanoeID) -> Hex {
        if case .sea(let cell) = canoe(id).location { return cell }
        preconditionFailure("canoe \(id.name) is not at sea")
    }
}

extension CanoeLocation {
    /// True when the canoe is at sea.
    public var isSea: Bool {
        if case .sea = self { return true }
        return false
    }
}
