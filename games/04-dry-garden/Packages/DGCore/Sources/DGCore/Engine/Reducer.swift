// Reducer.swift — the one pure state-transition function (_CONVENTIONS
// §4.2.2: `apply` is the only way state changes; S1.1).
//
// R-4/R-5/R-6 actions, the garden laws (R-7/R-8) judging AFTER
// positions, R-15's end conditions (two consecutive passes; supplies
// and rakes both spent), and R-30's resign. Randomness: none — the
// reducer is deterministic and takes no rng at all.

public enum Reducer {

    /// Applies `action` to `state`, returning the next state and the
    /// emitted events. Throws `IllegalReason` without touching the
    /// state on any illegal action.
    public static func apply(
        _ action: Action, to state: GameState, courtyard: Courtyard,
        balance: Balance = .standard()
    ) throws -> (state: GameState, events: [Event]) {
        if state.isOver {
            throw IllegalReason.gameOver
        }
        var next = state
        var events: [Event] = []

        switch action {
        case .place(let cell, let size, let facing):
            let player = state.toMove
            if let reason = Legality.placementError(
                cell, size: size, facing: facing, player: player,
                courtyard: courtyard, state: state, balance: balance) {
                throw reason
            }
            var supply = state.supplies[player] ?? Supply(
                large: 0, medium: 0, small: 0)
            supply.use(size)  // INV-3 enforced by Supply
            next.supplies[player] = supply
            let stone = Stone(
                owner: player, cell: cell, size: size, facing: facing)
            next.stones.append(stone)
            next.passes = 0
            next.plies += 1
            next.toMove = player.opponent
            events.append(.placed(stone))

        case .rake(let start, let direction, let length):
            let player = state.toMove
            if let reason = Legality.rakeError(
                start: start, direction: direction, length: length,
                player: player, courtyard: courtyard, state: state,
                balance: balance) {
                throw reason
            }
            var cells: [Hex] = []
            var probe = start
            for _ in 0..<length {
                probe = probe.neighbor(direction)
                cells.append(probe)
            }
            // R-5: record the anchor (a mover's stone adjacent to the
            // first cell); rakeAnchor already verified one exists.
            let context = LegalMoves.Context(state: state, courtyard: courtyard)
            let anchor = Legality.rakeAnchor(
                for: cells, player: player, state: state, context: context)!
            let rake = RakeLine(owner: player, cells: cells, anchor: anchor)
            next.rakes.append(rake)
            next.rakesUsed[player, default: 0] += 1
            next.passes = 0
            next.plies += 1
            next.toMove = player.opponent
            events.append(.raked(rake))

        case .pass:
            let player = state.toMove
            if let reason = Legality.passError(
                player: player, courtyard: courtyard, state: state,
                balance: balance) {
                throw reason
            }
            next.passes += 1
            next.plies += 1
            next.toMove = player.opponent
            events.append(.passed(player: player))

        case .resign:
            let player = state.toMove
            // R-30: resign scores as a loss with the margin recorded as
            // the current difference — the current owned-cell counts go
            // into the record unchanged, and the opponent wins by rule
            // even if the counts favored the resigner.
            let tallies = InfluenceEngine.computeAll(
                courtyard: courtyard, stones: state.stones,
                rakes: state.rakes, balance: balance)
            let owned = Score.ownedCellCounts(
                courtyard: courtyard, tallies: tallies)
            let winner: PlayerID = player == .one ? .two : .one
            next.finalScores = owned
            next.isOver = true
            events.append(.resigned(player: player))
            events.append(.gameOver(winner: winner, scores: owned))
            return (next, events)
        }

        // R-15: two consecutive passes end the game.
        if next.passes >= 2 {
            next = finish(next, courtyard: courtyard, balance: balance)
            events.append(
                .gameOver(
                    winner: Score.winner(from: next.finalScores),
                    scores: next.finalScores))
            return (next, events)
        }

        // R-15: both supplies AND rakes spent → game over (both players
        // out of material, checked when the player to move can act on
        // nothing: they pass, and the double pass ends it — but a
        // material-exhausted position also ends immediately so the sim
        // does not rely on pass chains).
        if next.supplies[.one]?.isSpent == true
            && next.supplies[.two]?.isSpent == true
            && (next.rakesUsed[.one] ?? 0) >= balance.rakesPerPlayer
            && (next.rakesUsed[.two] ?? 0) >= balance.rakesPerPlayer {
            next = finish(next, courtyard: courtyard, balance: balance)
            events.append(
                .gameOver(
                    winner: Score.winner(from: next.finalScores),
                    scores: next.finalScores))
            return (next, events)
        }

        return (next, events)
    }

    /// Seals a finished state: compute final scores (R-14) from the
    /// final position alone (INV-8).
    private static func finish(
        _ state: GameState, courtyard: Courtyard, balance: Balance
    ) -> GameState {
        var final = state
        final.isOver = true
        final.finalScores = Score.finalScores(
            courtyard: courtyard, state: state, balance: balance)
        return final
    }
}
