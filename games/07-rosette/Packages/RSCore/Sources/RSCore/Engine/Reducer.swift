// MARK: - RuleError

/// Errors that can occur during rule application.
public enum RuleError: Error, Sendable, CustomStringConvertible {
    /// The action is not allowed in the current state.
    case illegalAction(String)
    /// The dice have not been rolled yet.
    case noDiceRolled
    /// No legal moves are available.
    case noLegalMoves
    /// The piece does not exist or is not movable.
    case noSuchPiece(PieceID)
    /// The move destination is invalid.
    case invalidDestination
    /// The match is already complete.
    case matchComplete
    /// The cube cannot be doubled (R-10).
    case cubeError(DoublingCube.CubeError)

    public var description: String {
        switch self {
        case .illegalAction(let msg): return "Illegal action: \(msg)"
        case .noDiceRolled: return "No dice rolled"
        case .noLegalMoves: return "No legal moves"
        case .noSuchPiece(let id): return "No such piece: \(id)"
        case .invalidDestination: return "Invalid destination"
        case .matchComplete: return "Match is complete"
        case .cubeError(let err): return "Cube error: \(err)"
        }
    }
}

// MARK: - Reducer

/// The pure reducer: applies an action to a state, producing a new state and
/// the events that describe what changed.
///
/// Dice draws come from `rng`. Every omen-caused draw (a re-roll's replacement
/// value) comes from `omenRng`, so playing omens never changes the dice
/// stream's draw sequence (INV-7, R-23).
public enum Reducer {
    /// The outcome of applying an action.
    public struct Result {
        public let state: MatchState
        public let events: [Event]
    }

    /// Apply an action to the current state.
    public static func apply(
        _ action: Action,
        to state: MatchState,
        rng: inout SeededRNG,
        omenRng: inout SeededRNG
    ) throws(RuleError) -> Result {
        var current = state
        var events: [Event] = []

        switch action {
        case .roll:
            (current, events) = try applyRoll(to: current, rng: &rng, omenRng: &omenRng)
        case .move(let pieceId):
            (current, events) = try applyMove(to: current, piece: pieceId)
        case .offerDouble:
            (current, events) = try applyOfferDouble(to: current)
        case .acceptDouble:
            (current, events) = try applyAcceptDouble(to: current)
        case .concede:
            (current, events) = try applyConcede(to: current)
        case .playOmen(let omenId):
            (current, events) = try applyOmen(to: current, omenId: omenId)
        case .setStake(let value):
            (current, events) = try applySetStake(to: current, value: value)
        }

        return Result(state: current, events: events)
    }

    // MARK: - Roll (R-2, R-3)

    static func applyRoll(
        to state: MatchState,
        rng: inout SeededRNG,
        omenRng: inout SeededRNG
    ) throws(RuleError) -> (MatchState, [Event]) {
        guard !state.isComplete else { throw RuleError.matchComplete }
        guard !state.doubleOffered else {
            throw RuleError.illegalAction("A pending double must be answered first")
        }
        guard !state.hasRolled else {
            throw RuleError.illegalAction("Already rolled this turn")
        }

        var result = state
        var events: [Event] = []
        var amount = result.dice.roll(rng: &rng)
        events.append(Event.diceRolled(value: amount))

        // Omen: re-roll. The replacement draw comes from the omen stream so
        // the dice stream's sequence is unchanged (INV-7). Split and safety
        // omens stay pending: the split is consumed below when it activates,
        // the safety toggle lasts through the turn and clears at its end.
        if let pending = result.pendingOmen, pending.effect.kind == .reroll {
            let replacement = result.dice.roll(rng: &omenRng)
            amount = replacement
            events.append(Event.diceRolled(value: replacement))
            result.pendingOmen = nil
        }

        result.hasRolled = true

        // The post-roll transition (split omens, move enumeration, pass-on-
        // no-move) is shared with the AI's search, which must replay the
        // engine's roll semantics exactly (ADR-0011).
        return try postRoll(to: result, amount: amount, events: events)
    }

    /// The state transition after a dice value has been drawn: a roll of 0
    /// passes (R-3), a split omen divides the roll (R-12), otherwise the
    /// legal moves for the amount are enumerated; with none the turn passes.
    /// Shared by `applyRoll` and by the AI's chance-node search (RS-P4.1,
    /// ADR-0011) so both paths can never drift apart. `events` carries the
    /// caller's accumulated events (applyRoll's original and replacement
    /// `diceRolled` records) and is returned appended to.
    public static func postRoll(
        to state: MatchState,
        amount: Int,
        events: [Event]
    ) throws(RuleError) -> (MatchState, [Event]) {
        var result = state
        var events = events

        // R-3: a roll of 0 passes.
        if amount == 0 {
            events.append(Event.turnPassed)
            return (endTurn(result), events)
        }

        // Omen: split the roll between two pieces (R-12). A roll of 2 or more
        // splits into two halves; the first half must be moved first.
        if let pending = result.pendingOmen, pending.effect.kind == .split, amount >= 2 {
            let firstHalf = amount / 2
            let secondHalf = amount - firstHalf
            let splitMoves = MoveGen.legalMoves(
                for: result.currentPlayer,
                amount: firstHalf,
                pieces: result.pieces,
                track: result.track,
                rules: result.ruleset,
                allowEntry: false
            )
            if !splitMoves.isEmpty {
                result.pendingOmen = nil
                result.splitActive = true
                result.splitRemaining = secondHalf
                result.diceValue = firstHalf
                result.movablePieceIds = Set(splitMoves.map { $0.piece })
                return (result, events)
            }
            // No piece can take the first half: the split fizzles into a
            // normal single move of the full roll.
        }

        result.diceValue = amount
        let moves = MoveGen.legalMoves(
            for: result.currentPlayer,
            amount: amount,
            pieces: result.pieces,
            track: result.track,
            rules: result.ruleset,
            unsafeRosettesActive: result.pendingOmen?.effect.kind == .unsafeRosettes
        )
        if moves.isEmpty {
            // R-3: no legal move passes the turn.
            events.append(Event.turnPassed)
            return (endTurn(result), events)
        }
        result.movablePieceIds = Set(moves.map { $0.piece })
        return (result, events)
    }

    // MARK: - Move (R-3, R-4, R-5, R-6, R-7, R-8)

    /// Apply one piece move to the current state. Public so the AI's search
    /// and the live reducer drive the identical move semantics (ADR-0011);
    /// the move must be legal (`movablePieceIds`), which is the caller's
    /// contract exactly as for `.move` actions.
    public static func applyMove(
        to state: MatchState,
        piece: PieceID
    ) throws(RuleError) -> (MatchState, [Event]) {
        guard !state.isComplete else { throw RuleError.matchComplete }
        guard !state.doubleOffered else {
            throw RuleError.illegalAction("A pending double must be answered first")
        }
        guard state.hasRolled, let amount = state.diceValue else {
            throw RuleError.noDiceRolled
        }
        guard state.movablePieceIds.contains(piece) else {
            throw RuleError.illegalAction("Piece \(piece) has no legal move this turn")
        }
        guard
            let pieceIndex = state.pieces.firstIndex(where: {
                $0.id == piece && $0.owner == state.currentPlayer
            })
        else {
            throw RuleError.noSuchPiece(piece)
        }

        var result = state
        var pieces = result.pieces
        let mover = pieces[pieceIndex]
        let from = mover.position
        var events: [Event] = []
        var movedPiece = mover

        // R-3: a waiting piece enters at step roll−1 (the roll carries the
        // piece in). A roll of 0 passes in applyRoll, so amount ≥ 1 here.
        // Otherwise the move advances by the roll; reaching (or passing, when
        // the ruleset allows inexact bear-off) the track end bears off (R-7).
        let destination: Int?
        if from == -1 {
            let entry = amount - 1
            guard entry >= 0, entry < result.track.length else {
                throw RuleError.invalidDestination
            }
            destination = entry
        } else if from + amount > result.track.length && result.ruleset.exactBearOff {
            // Unreachable for a legal move; guarded for safety.
            throw RuleError.invalidDestination
        } else if from + amount == result.track.length
            || (!result.ruleset.exactBearOff && from + amount > result.track.length)
        {
            destination = nil  // R-7: bear off.
        } else {
            destination = from + amount
        }

        if let destination {
            if let targetIndex = pieces.firstIndex(where: {
                $0.position == destination && $0.owner != result.currentPlayer
            }) {
                let unsafeActive = result.pendingOmen?.effect.kind == .unsafeRosettes
                let capture = Capture.check(
                    landingOn: destination,
                    targetPiece: pieces[targetIndex],
                    track: result.track,
                    rules: result.ruleset,
                    unsafeRosettesActive: unsafeActive
                )
                switch capture {
                case .safeRosette:
                    throw RuleError.illegalAction("Cannot capture on a safe rosette")
                case .none:
                    break
                case .captured(let capturedId):
                    pieces[targetIndex].position = -1
                    events.append(Event.pieceCaptured(piece: capturedId, by: result.currentPlayer))
                }
            }
            movedPiece.position = destination
            if result.ruleset.extraRollOnRosette
                && Rosette.isRosette(at: destination, track: result.track)
            {
                result.extraRoll = true
                events.append(Event.rosetteLanded(player: result.currentPlayer))
            }
        } else {
            // R-7: bear off.
            movedPiece.position = -2
            result.borneOff[result.currentPlayer, default: 0] += 1
            events.append(Event.pieceBorneOff(piece: piece, player: result.currentPlayer))
        }

        pieces[pieceIndex] = movedPiece
        result.pieces = pieces
        result.plies += 1
        events.insert(Event.pieceMoved(piece: piece, from: from, to: movedPiece.position), at: 0)

        // R-16: a fortune square strikes the piece that landed on it. A good
        // fortune grants another roll; a bad fortune sends the piece home.
        // The effect is deterministic by square (no RNG draw), so the dice
        // and omen streams are untouched (INV-7). A player's own pending
        // omen takes precedence for the turn.
        if !result.isComplete, movedPiece.position >= 0, result.pendingOmen == nil,
            let fortune = result.fortunes.first(where: {
                $0.rulesetId == result.ruleset.id && $0.square == movedPiece.position
            })
        {
            switch fortune.deck {
            case .good:
                result.extraRoll = true
                events.append(
                    Event.omenPlayed(omenId: fortune.deck.rawValue, player: result.currentPlayer)
                )
            case .bad:
                var bounced = movedPiece
                let landed = bounced.position
                bounced.position = -1
                pieces[pieceIndex] = bounced
                result.pieces = pieces
                // A bad fortune also cancels any rosette extra roll the same
                // landing earned: the piece went home.
                result.extraRoll = false
                events.append(
                    Event.omenPlayed(omenId: fortune.deck.rawValue, player: result.currentPlayer)
                )
                events.append(Event.pieceMoved(piece: piece, from: landed, to: -1))
            }
        }

        // R-8: bearing off the last piece wins the match.
        if (result.borneOff[result.currentPlayer] ?? 0) == result.ruleset.pieces {
            let opponent: PlayerID = result.currentPlayer == .player0 ? .player1 : .player0
            let gammon = (result.borneOff[opponent] ?? 0) == 0
            result.isComplete = true
            result.outcome = Outcome(
                winner: result.currentPlayer,
                gammon: gammon,
                cubeValue: result.cube.value,
                initialStake: result.stake.value,
                plies: result.plies
            )
            events.append(Event.matchWon(winner: result.currentPlayer, gammon: gammon))
            return (result, events)
        }

        // Split turn: the second half of the roll still has to be moved.
        if result.splitActive {
            result.splitActive = false
            let secondHalf = result.splitRemaining ?? 0
            result.splitRemaining = nil
            if secondHalf > 0 {
                let secondMoves = MoveGen.legalMoves(
                    for: result.currentPlayer,
                    amount: secondHalf,
                    pieces: result.pieces,
                    track: result.track,
                    rules: result.ruleset,
                    unsafeRosettesActive: result.pendingOmen?.effect.kind == .unsafeRosettes,
                    allowEntry: false
                )
                if secondMoves.isEmpty {
                    events.append(Event.turnPassed)
                    return (endTurn(result), events)
                }
                result.diceValue = secondHalf
                result.movablePieceIds = Set(secondMoves.map { $0.piece })
                return (result, events)
            }
        }

        // R-6/R-19: a rosette grants another roll (chains without limit).
        // When extraRoll is set, reset it (so the next .roll doesn't see it)
        // and return without ending the turn.  Otherwise end the turn.
        if result.extraRoll {
            result.extraRoll = false
            result.diceValue = nil
            result.hasRolled = false
            result.movablePieceIds = []
            return (result, events)
        }

        return (endTurn(result), events)
    }

    // MARK: - Doubling cube (R-10, R-21, R-22)

    static func applyOfferDouble(
        to state: MatchState
    ) throws(RuleError) -> (MatchState, [Event]) {
        guard !state.isComplete else { throw RuleError.matchComplete }
        guard !state.cubeDead else {
            throw RuleError.illegalAction("The cube is dead for this match (Crawford)")
        }
        guard !state.hasRolled else {
            throw RuleError.illegalAction("A double may be offered only before rolling")
        }
        guard !state.doubleOffered else {
            throw RuleError.illegalAction("A double was already offered this turn")
        }
        guard !state.hasDoubledThisTurn else {
            throw RuleError.illegalAction("The cube was already used this turn (R-21)")
        }
        if let error = state.cube.validateOffer(by: state.currentPlayer, maxCube: 64) {
            throw RuleError.cubeError(error)
        }
        var result = state
        result.doubleOffered = true
        result.hasDoubledThisTurn = true
        return (result, [Event.doubleOffered(by: state.currentPlayer)])
    }

    static func applyAcceptDouble(
        to state: MatchState
    ) throws(RuleError) -> (MatchState, [Event]) {
        guard !state.isComplete else { throw RuleError.matchComplete }
        guard state.doubleOffered else {
            throw RuleError.illegalAction("No double has been offered")
        }
        var result = state
        let accepter: PlayerID = result.currentPlayer == .player0 ? .player1 : .player0
        let newValue = result.cube.value * 2
        result.cube = DoublingCube(value: newValue, owner: accepter.rawValue)
        result.stake = result.stake.double()
        result.doubleOffered = false
        result.hasDoubledThisTurn = true
        return (result, [Event.cubeDoubled(newValue: newValue, newOwner: accepter)])
    }

    // MARK: - Concede (R-10, R-11)

    static func applyConcede(
        to state: MatchState
    ) throws(RuleError) -> (MatchState, [Event]) {
        guard !state.isComplete else { throw RuleError.matchComplete }
        var result = state
        // While a double is pending, conceding is the offered player's
        // decline: they lose at the current stake. Otherwise the current
        // player resigns.
        let loser: PlayerID
        if state.doubleOffered {
            loser = state.currentPlayer == .player0 ? .player1 : .player0
        } else {
            loser = state.currentPlayer
        }
        let winner: PlayerID = loser == .player0 ? .player1 : .player0
        // A concession prices the loss at the current stake (R-10); the
        // gammon multiplier (R-11) belongs to completed matches only.
        let gammon = false
        result.isComplete = true
        result.outcome = Outcome(
            winner: winner,
            gammon: gammon,
            cubeValue: result.cube.value,
            initialStake: result.stake.value,
            plies: result.plies
        )
        return (
            result, [Event.conceded(by: loser), Event.matchWon(winner: winner, gammon: gammon)]
        )
    }

    // MARK: - Omens (R-12, R-23)

    static func applyOmen(
        to state: MatchState,
        omenId: String
    ) throws(RuleError) -> (MatchState, [Event]) {
        guard !state.isComplete else { throw RuleError.matchComplete }
        guard !state.hasRolled else {
            throw RuleError.illegalAction("Omens are played before the roll")
        }
        guard !state.hasDoubledThisTurn else {
            throw RuleError.illegalAction("Omens must be played before doubling (R-21)")
        }
        guard state.omensPlayed[state.currentPlayer] == nil else {
            throw RuleError.illegalAction("Only one omen may be played per match")
        }
        let held = state.omensHeld[state.currentPlayer] ?? []
        guard let omen = held.first(where: { $0.id == omenId }) else {
            throw RuleError.illegalAction("Omen not held: \(omenId)")
        }
        var result = state
        result.omensHeld[result.currentPlayer] = held.filter { $0.id != omenId }
        result.omensPlayed[result.currentPlayer] = omenId
        result.pendingOmen = omen
        return (result, [Event.omenPlayed(omenId: omenId, player: result.currentPlayer)])
    }

    // MARK: - Stake (R-9)

    static func applySetStake(
        to state: MatchState,
        value: Int
    ) throws(RuleError) -> (MatchState, [Event]) {
        guard value > 0 else {
            throw RuleError.illegalAction("The stake must be positive")
        }
        guard state.plies == 0, !state.hasRolled else {
            throw RuleError.illegalAction("The stake is agreed before the match")
        }
        var result = state
        result.stake = Stake(value: value)
        return (result, [Event.stakeSet(value: value)])
    }

    // MARK: - Turn end

    /// Pass the turn to the other player and clear per-turn state. Public so
    /// the AI's search can model the pass transition exactly (ADR-0011).
    public static func endTurn(_ state: MatchState) -> MatchState {
        var result = state
        result.currentPlayer = result.currentPlayer == .player0 ? .player1 : .player0
        result.diceValue = nil
        result.hasRolled = false
        result.movablePieceIds = []
        result.extraRoll = false
        result.splitRemaining = nil
        result.splitActive = false
        result.pendingOmen = nil
        result.doubleOffered = false
        result.hasDoubledThisTurn = false
        return result
    }
}
