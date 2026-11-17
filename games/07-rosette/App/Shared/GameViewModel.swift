// MARK: - GameViewModel

import Combine
import Foundation
import RSContent
import RSCore

// MARK: - LaunchArguments

/// Launch-argument parsing for UI-test scenarios.
enum LaunchArguments {
    /// "-seed N": override the deterministic match seed (UI tests).
    static var seed: UInt64? {
        let args = ProcessInfo.processInfo.arguments
        guard
            let index = args.firstIndex(of: "-seed"),
            index + 1 < args.count,
            let value = UInt64(args[index + 1])
        else { return nil }
        return value
    }
}

/// ViewModel for the Rosette game screen. Bridges SwiftUI to RSCore's
/// match-state engine: every mutation goes through `Reducer.apply`, and the
/// reducer owns turn switching, extra rolls, splits, and outcome setting.
/// The ViewModel only derives view-facing state from the resulting state.
@MainActor
public final class GameViewModel: ObservableObject {

    // MARK: - Published state

    /// The current match state.
    @Published public private(set) var matchState: MatchState
    /// Legal moves for the current player (after a dice roll).
    @Published public private(set) var legalMoves: [Move] = []
    /// Whether the current player has an entry move (a piece can come in).
    @Published public private(set) var canEnter: Bool = false
    /// The odds panel text showing a simple capture heuristic for the roll.
    @Published public private(set) var oddsText: String = "Chance to capture next roll: 0%"
    /// Whether the AI is thinking (for the tavern opponent).
    @Published public private(set) var aiThinking: Bool = false
    /// Whether the game is paused.
    @Published public var isPaused: Bool = false
    /// The last rule error, for display (nil when the last action succeeded).
    @Published public private(set) var errorText: String?
    /// The last event description, for the activity line.
    @Published public private(set) var lastEventText: String = ""

    // MARK: - Derived state

    /// Whether the match is complete.
    public var isComplete: Bool { matchState.isComplete }
    /// The match outcome, once complete.
    public var outcome: Outcome? { matchState.outcome }
    /// Whether a double offer is pending.
    public var doublePending: Bool { matchState.doubleOffered }

    // MARK: - Private state

    private var rng: SeededRNG
    private var omenRng: SeededRNG
    private let seed: UInt64
    private let useAI: Bool
    private let stakeValue: Int
    private let omenId: String?
    /// The match's ruleset (R-15: it travels with the match).
    private let ruleset: RuleSet
    /// The match's dice model.
    private let diceModel: DiceModel
    /// Fortune squares in play (R-16; only the Tablet ruleset has any).
    private let fortunes: [FortuneSquare]
    /// Omens held by each side at the start (R-12).
    private let omens0: [Omen]
    private let omens1: [Omen]
    /// Autosave every applied action (S2.4 save/resume).
    private let autoSave: Bool
    /// UI-test/auto mode: both sides play the heuristic AI, fast timers.
    private let autoPilot: Bool
    /// The applied action history, for snapshot saves (deterministic replay).
    private var recordedActions: [RecordedAction] = []

    // MARK: - Lifecycle

    /// Start a new match under a content ruleset.
    ///
    /// - Parameters:
    ///   - ruleset: The ruleset to play (nil = the content's Finkel ruleset).
    ///   - dice: The dice model (nil = the ruleset's content dice).
    ///   - fortunes: Fortune squares in play (R-16).
    ///   - omens0/omens1: Omens each side holds at the start (R-12).
    ///   - stakeValue: Initial stake for the doubling cube.
    ///   - omenId: Optional omen id held by player 0 (quick-match path).
    ///   - useAI: If true, player 1 is controlled by the heuristic AI.
    ///   - seed: Deterministic seed for dice rolls.
    public init(
        ruleset: RuleSet? = nil,
        dice: DiceModel? = nil,
        fortunes: [FortuneSquare] = [],
        omens0: [Omen] = [],
        omens1: [Omen] = [],
        stakeValue: Int = 1,
        omenId: String? = nil,
        useAI: Bool = false,
        seed: UInt64 = 42,
        autoSave: Bool = true,
        autoPilot: Bool = ProcessInfo.processInfo.arguments.contains("-autoPilot")
    ) {
        let defaults = GameViewModel.contentDefaults()
        self.ruleset = ruleset ?? defaults.ruleset
        self.diceModel = dice ?? defaults.dice
        self.fortunes = fortunes
        self.omens0 = omens0 + (GameViewModel.omenFrom(id: omenId).map { [$0] } ?? [])
        self.omens1 = omens1
        self.stakeValue = stakeValue
        self.omenId = omenId
        self.useAI = useAI
        self.seed = seed
        self.autoSave = autoSave
        self.autoPilot = autoPilot
        self.rng = SeededRNG(seed: seed)
        self.omenRng = SeededRNG(seed: seed &+ 0x9E37_79B9_7F4A_7C15)
        self.matchState = GameViewModel.emptyMatch
        self.matchState = self.makeMatch(stake: stakeValue)
        deriveViewState()
    }

    /// Restore a saved match by deterministic replay of its action history.
    /// (Circuit matches do not autosave; snapshots are quick matches under
    /// the content's default ruleset.)
    init(
        snapshot: SavedMatch,
        autoSave: Bool = true,
        autoPilot: Bool = ProcessInfo.processInfo.arguments.contains("-autoPilot")
    ) {
        let defaults = GameViewModel.contentDefaults()
        self.ruleset = defaults.ruleset
        self.diceModel = defaults.dice
        self.fortunes = []
        self.omens0 = GameViewModel.omenFrom(id: snapshot.omenId).map { [$0] } ?? []
        self.omens1 = []
        self.stakeValue = snapshot.stakeValue
        self.omenId = snapshot.omenId
        self.useAI = snapshot.useAI
        self.seed = snapshot.seed
        self.autoSave = autoSave
        self.autoPilot = autoPilot
        self.rng = SeededRNG(seed: snapshot.seed)
        self.omenRng = SeededRNG(seed: snapshot.seed &+ 0x9E37_79B9_7F4A_7C15)
        self.recordedActions = []
        self.matchState = GameViewModel.emptyMatch
        var state = self.makeMatch(stake: snapshot.stakeValue)

        // Fold the saved actions through the reducer with fresh streams from
        // the stored seed. A failed step means a corrupt save; stop there.
        for recorded in snapshot.actions {
            guard let action = GameViewModel.action(from: recorded) else { continue }
            do {
                let result = try Reducer.apply(action, to: state, rng: &rng, omenRng: &omenRng)
                state = result.state
                recordedActions.append(recorded)
            } catch {
                break
            }
        }

        self.matchState = state
        deriveViewState()
    }

    /// Map a recorded action back to its engine action.
    private static func action(from recorded: RecordedAction) -> Action? {
        switch recorded {
        case .roll: return .roll
        case .move(let id): return .move(id)
        case .offerDouble: return .offerDouble
        case .acceptDouble: return .acceptDouble
        case .concede: return .concede
        case .playOmen(let id): return .playOmen(omenId: id)
        case .setStake(let value): return .setStake(value)
        }
    }

    /// The content's default ruleset and dice (Finkel + tetra4), used when
    /// a caller does not specify one. Loaded from RSContent (ADR-0007).
    static func contentDefaults() -> (ruleset: RuleSet, dice: DiceModel) {
        let loader = ContentLoader()
        if let ruleset = (try? loader.loadEngineRuleSets())?.first(where: { $0.id == "finkel" }),
            let dice = try? loader.diceModel(forRulesetID: "finkel")
        {
            return (ruleset, dice)
        }
        // Content should always provide Finkel; fall back to the engine's
        // static definition so a broken bundle still yields a playable match.
        return (RuleSet.finkel, .tetra4)
    }

    /// An empty placeholder state used only during initialisation.
    private static let emptyMatch = MatchState.finkelMatch(stake: 1, omens: [])

    /// Build the match from the configured ruleset, dice, fortunes, omens.
    private func makeMatch(stake: Int) -> MatchState {
        var state = MatchState.newMatch(
            ruleset: ruleset,
            dice: diceModel,
            stake: stake,
            omens: [],
            fortunes: fortunes
        )
        state.omensHeld[.player0] = omens0
        state.omensHeld[.player1] = omens1
        return state
    }

    /// Build an omen from its id: content omens first (their cost and
    /// HIST3.1 label travel with them), then the legacy quick-match ids.
    static func omenFrom(id: String?) -> Omen? {
        guard let id else { return nil }
        let loader = ContentLoader()
        if let defs = try? loader.loadOmens(),
            let def = defs.first(where: { $0.id == id })
        {
            return Omen(id: def.id, effect: def.effect, cost: def.cost, label: def.label)
        }
        let effect: OmenEffect
        switch id {
        case "reroll": effect = .reroll(count: 1)
        case "unsafeRosettes": effect = .unsafeRosettes(count: 1)
        case "split": effect = .split(count: 1)
        default: return nil
        }
        return Omen(id: id, effect: effect, cost: 0, label: .reconstructed)
    }

    // MARK: - Actions

    /// Roll the dice. After rolling, legal moves are derived from the state.
    public func rollDice() {
        guard !isPaused else { return }
        applyAction(.roll)
    }

    /// Move the given piece (must be movable this turn).
    public func movePiece(_ pieceId: PieceID) {
        guard !isPaused, matchState.movablePieceIds.contains(pieceId) else { return }
        applyAction(.move(pieceId))
    }

    /// Offer a double (R-10): before rolling, once per turn.
    public func offerDouble() {
        guard !isPaused else { return }
        applyAction(.offerDouble)
    }

    /// Accept a pending double offer (R-10).
    public func acceptDouble() {
        guard !isPaused else { return }
        applyAction(.acceptDouble)
    }

    /// Decline a pending double offer: conceding at the current stake (R-10).
    public func declineDouble() {
        guard !isPaused else { return }
        applyAction(.concede)
    }

    /// Concede the match.
    public func concede() {
        guard !isPaused else { return }
        applyAction(.concede)
    }

    /// Restart the match with the same settings.
    public func restart() {
        matchState = makeMatch(stake: stakeValue)
        recordedActions = []
        legalMoves = []
        canEnter = false
        oddsText = "Chance to capture next roll: 0%"
        aiThinking = false
        errorText = nil
        lastEventText = ""
    }

    /// Pause or resume the match.
    public func togglePause() {
        isPaused.toggle()
    }

    // MARK: - Reducer bridge

    /// Apply an action through the reducer and re-derive view state.
    func applyAction(_ action: Action) {
        do {
            let result = try Reducer.apply(action, to: matchState, rng: &rng, omenRng: &omenRng)
            matchState = result.state
            if let recorded = GameViewModel.recorded(from: action) {
                recordedActions.append(recorded)
            }
            errorText = nil
            for event in result.events {
                record(event)
            }
            deriveViewState()
            // S2.4: autosave every applied action while the match runs.
            if autoSave {
                if matchState.isComplete {
                    SaveManager.deleteAutosave()
                } else {
                    SaveManager.saveAutosave(currentSnapshot)
                }
            }
        } catch {
            errorText = error.description
        }

        scheduleAIIfNeeded()
    }

    /// Map an engine action to its recorded (Codable) form.
    private static func recorded(from action: Action) -> RecordedAction? {
        switch action {
        case .roll: return .roll
        case .move(let id): return .move(id)
        case .offerDouble: return .offerDouble
        case .acceptDouble: return .acceptDouble
        case .concede: return .concede
        case .playOmen(let id): return .playOmen(id)
        case .setStake(let value): return .setStake(value)
        }
    }

    // MARK: - Save / load

    /// A snapshot of the current match for persistence.
    var currentSnapshot: SavedMatch {
        SavedMatch(
            version: SavedMatch.currentVersion,
            seed: seed,
            stakeValue: stakeValue,
            omenId: omenId,
            useAI: useAI,
            actions: recordedActions
        )
    }

    /// Save the current match. Returns the file URL, or nil on failure.
    @discardableResult
    public func save() -> URL? {
        SaveManager.save(currentSnapshot)
    }

    /// Record a human-readable line for the latest event.
    private func record(_ event: Event) {
        switch event {
        case .diceRolled(value: let v):
            lastEventText = "Rolled \(v)"
        case .pieceMoved(let piece, let from, let to):
            lastEventText =
                "Piece \(piece) moved \(from < 0 ? "in" : "from \(from)") to \(to < 0 ? "off" : "\(to)")"
        case .pieceCaptured:
            lastEventText = "Capture!"
        case .pieceBorneOff:
            lastEventText = "Piece borne off"
        case .rosetteLanded:
            lastEventText = "Rosette! Extra roll"
        case .doubleOffered:
            lastEventText = "Double offered"
        case .cubeDoubled(newValue: let v, newOwner: _):
            lastEventText = "Cube doubled to \(v)"
        case .conceded:
            lastEventText = "Conceded"
        case .matchWon:
            lastEventText = "Match won"
        case .omenPlayed(omenId: let id, player: _):
            lastEventText = "Omen played: \(id)"
        case .stakeSet(value: let v):
            lastEventText = "Stake set to \(v)"
        case .turnPassed:
            lastEventText = "Turn passed"
        }
    }

    /// Re-derive published view state from the (reducer-owned) match state.
    private func deriveViewState() {
        // The odds panel is about the next roll, shown from any fresh-turn
        // state (and reads 0% while a roll is pending or a double awaits).
        oddsText = OddsCalculator.panelText(for: matchState)

        // After a roll (or a split's first half), the reducer has set
        // diceValue and movablePieceIds; derive the Move list for the UI.
        if matchState.hasRolled, let amount = matchState.diceValue, !matchState.isComplete {
            let unsafeActive = matchState.pendingOmen?.effect.kind == .unsafeRosettes
            legalMoves = MoveGen.legalMoves(
                for: matchState.currentPlayer,
                amount: amount,
                pieces: matchState.pieces,
                track: matchState.track,
                rules: matchState.ruleset,
                unsafeRosettesActive: unsafeActive,
                allowEntry: !matchState.splitActive
            )
            canEnter = legalMoves.contains { move in
                matchState.pieces.first { $0.id == move.piece }?.position == -1
            }
        } else {
            legalMoves = []
            canEnter = false
        }
    }

    // MARK: - AI (simple heuristic for P2; RS-AI replaces it in P4)

    /// How long the AI waits before acting (fast in autoPilot UI-test runs).
    private var aiDelay: TimeInterval { autoPilot ? 0.05 : 0.5 }

    /// Schedule the next AI action when an AI-controlled side must act.
    private func scheduleAIIfNeeded() {
        guard !matchState.isComplete, !isPaused else { return }

        // A pending double must be answered by the opponent of the offerer.
        if matchState.doubleOffered {
            let answerer: PlayerID = matchState.currentPlayer == .player0 ? .player1 : .player0
            let aiControlsAnswerer = (useAI && answerer == .player1) || autoPilot
            guard aiControlsAnswerer else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + aiDelay) { [weak self] in
                self?.aiRespondToDouble()
            }
            return
        }

        guard autoPilot || matchState.currentPlayer == .player1 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + aiDelay) { [weak self] in
            self?.aiTurn()
        }
    }

    /// The AI (or autoPilot) answers a pending double: accept when not behind.
    /// In autoPilot the answerer always accepts, so the UI test reliably
    /// exercises the accepted-double path (G2).
    private func aiRespondToDouble() {
        guard matchState.doubleOffered, !isPaused else { return }
        aiThinking = true
        let answerer: PlayerID = matchState.currentPlayer == .player0 ? .player1 : .player0
        let offerer = matchState.currentPlayer
        let accept =
            autoPilot
            || (matchState.borneOff[answerer] ?? 0) >= (matchState.borneOff[offerer] ?? 0)
        applyAction(accept ? .acceptDouble : .concede)
        aiThinking = false
    }

    /// AI turn: roll, maybe offer a double, then pick the best heuristic move.
    private func aiTurn() {
        guard !matchState.isComplete, !isPaused else { return }
        guard autoPilot || matchState.currentPlayer == .player1 else { return }

        aiThinking = true

        if !matchState.hasRolled {
            applyAction(.roll)
            // The AI may offer a double when clearly ahead (R-10: before rolling).
            if !matchState.hasRolled && !matchState.isComplete && shouldOfferDouble() {
                applyAction(.offerDouble)
            }
        } else if !legalMoves.isEmpty {
            if let move = pickBestAIMove() {
                applyAction(.move(move.piece))
            }
        }

        aiThinking = false
        // Keep the chain moving: the next roll/action is scheduled whenever
        // an AI-controlled side is next to act.
        scheduleAIIfNeeded()
    }

    /// Decide whether the AI should offer a double.
    private func shouldOfferDouble() -> Bool {
        let own = matchState.borneOff[matchState.currentPlayer] ?? 0
        let opponent: PlayerID = matchState.currentPlayer == .player0 ? .player1 : .player0
        let other = matchState.borneOff[opponent] ?? 0
        return own > other && own >= 3
    }

    /// Pick the best move for the AI: capture, enter, bear off, then advance.
    private func pickBestAIMove() -> Move? {
        // 1) Capture: destination holds an opponent piece not on a safe rosette.
        for move in legalMoves {
            guard move.destination >= 0 else { continue }
            let opponentThere = matchState.pieces.contains {
                $0.owner != matchState.currentPlayer && $0.position == move.destination
            }
            let safe = matchState.track.safeRosetteIndices.contains(move.destination)
            if opponentThere && !(safe && !matchState.pendingOmenIsUnsafeRosettes) {
                return move
            }
        }

        // 2) Enter a piece from off-board (entry square = amount - 1).
        if let amount = matchState.diceValue {
            let entrySquare = amount - 1
            if let enter = legalMoves.first(where: { $0.destination == entrySquare }) {
                return enter
            }
        }

        // 3) Bear off.
        if let bearOff = legalMoves.first(where: { $0.destination == -1 }) {
            return bearOff
        }

        // 4) Advance.
        return legalMoves.first
    }
}

/// Small helper so the AI's capture check can read the pending-omen flag
/// without reaching into MatchState internals from outside RSCore.
extension MatchState {
    /// Whether the safety-toggle omen is active this turn.
    var pendingOmenIsUnsafeRosettes: Bool {
        pendingOmen?.effect.kind == .unsafeRosettes
    }
}
