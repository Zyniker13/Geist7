// MatchModel.swift — the match screen's game flow (MT-P2.2).
//
// Owns the GameState of one match against the Sailor tier: the human
// plays player 1 (or auto-pilot drives both sides for tests and
// snapshots), the AI acts after `aiDelay` seconds on its own task,
// and every committed action goes through the reducer — the model
// never mutates state outside Reducer.apply. The match persists to
// UserDefaults after every action so a kill can resume; launch
// arguments that start a match (-startMatch, -seed) always play
// fresh. Snapshots freeze at `-snapshotPly N` for deterministic
// captures.

import MTAI
import MTContent
import MTCore
import SwiftUI

@MainActor
final class MatchModel: ObservableObject {
    /// The side the local Sailor drives (the human is player 1).
    static let aiSide = PlayerID.p2

    @Published private(set) var state: GameState
    @Published private(set) var plies = 0
    @Published private(set) var aiThinking = false
    /// Pause freezes the match (S2.2): the pending AI move is
    /// cancelled and player input is ignored until resumed.
    @Published private(set) var isPaused = false
    /// The canoe whose sail path is being composed, if any.
    @Published private(set) var selected: CanoeID?
    /// The sail path composed so far (cells the canoe would enter).
    @Published private(set) var pendingPath: [Hex] = []
    /// The tapped-but-uncommitted island cell showing the preview.
    @Published var ghostIsland: Hex?
    @Published var showRays = true
    @Published var showNodes = true
    /// The Marshallese-names toggle: on, swell labels show the
    /// advisor-approved term; every term is still pending (§5), so
    /// the labels carry the pending marker until review lands.
    @Published var marshalleseNames = false

    let seed: UInt64
    /// Pause before each AI move (launch argument `-aiDelay`; tests
    /// set 0). Under auto-pilot the pace is min(aiDelay, 0.05) unless
    /// the caller passed an explicit delay, which is respected as-is.
    let aiDelay: TimeInterval
    /// Auto-pilot drives both sides (launch argument `-autoPilot`).
    let autoPilot: Bool
    /// Whether the launch arguments carried an explicit `-aiDelay`
    /// (those are respected as-is under auto-pilot).
    let explicitAIDelay: Bool
    /// Freeze the match after this many plies (launch argument
    /// `-snapshotPly`); nil plays on.
    let snapshotPly: Int?

    private var rng = SeededRNG(seed: 0)
    private var aiTask: Task<Void, Never>?
    private let defaults: UserDefaults

    static let saveKey = "mattang.match.v1"

    var isOver: Bool { state.status.isOver }

    var frozen: Bool {
        guard let limit = snapshotPly else { return false }
        return plies >= limit
    }

    /// A fresh match against Sailor.
    convenience init(
        seed: UInt64, aiDelay: TimeInterval, autoPilot: Bool,
        snapshotPly: Int?, explicitAIDelay: Bool = false
    ) {
        self.init(
            seed: seed, aiDelay: aiDelay, autoPilot: autoPilot,
            snapshotPly: snapshotPly, explicitAIDelay: explicitAIDelay,
            saved: nil)
    }

    /// Internal: build from an optional saved record (resume).
    private init(
        seed: UInt64, aiDelay: TimeInterval, autoPilot: Bool,
        snapshotPly: Int?, explicitAIDelay: Bool, saved: SavedMatch?
    ) {
        self.seed = seed
        self.aiDelay = aiDelay
        self.autoPilot = autoPilot
        self.explicitAIDelay = explicitAIDelay
        self.snapshotPly = snapshotPly
        self.defaults = .standard
        if let saved, saved.seed == seed {
            state = saved.state
            plies = saved.plies
            rng = SeededRNG(seed: saved.rngState)
        } else {
            let chart: Chart
            do {
                chart = try SliceGame.chart()
            } catch {
                // The slice content ships with the app; a decode
                // failure is a build defect, not a player-facing state.
                preconditionFailure("slice content unavailable: \(error)")
            }
            state = Reducer.initial(chart: chart)
            rng = SeededRNG(seed: seed)
            plies = 0
        }
        scheduleAIIfNeeded()
    }

    /// The model for this launch: a fresh match when the launch
    /// arguments start one, otherwise the saved match, else fresh.
    static func forCurrentLaunch(defaults: UserDefaults = .standard) -> MatchModel {
        let args = LaunchArguments.current
        let aiDelay = args.aiDelay ?? 1.2
        let explicit = args.aiDelay != nil
        if args.startMatch {
            return MatchModel(
                seed: args.seed ?? 0, aiDelay: aiDelay,
                autoPilot: args.autoPilot, snapshotPly: args.snapshotPly,
                explicitAIDelay: explicit)
        }
        if let data = defaults.data(forKey: saveKey),
            let saved = try? JSONDecoder().decode(SavedMatch.self, from: data)
        {
            return MatchModel(
                seed: saved.seed, aiDelay: aiDelay, autoPilot: args.autoPilot,
                snapshotPly: args.snapshotPly, explicitAIDelay: explicit,
                saved: saved)
        }
        return MatchModel(
            seed: 0, aiDelay: aiDelay, autoPilot: args.autoPilot,
            snapshotPly: args.snapshotPly, explicitAIDelay: explicit)
    }

    deinit {
        aiTask?.cancel()
    }

    // MARK: Derived view data

    /// Display name for a swell id under the current toggle.
    func swellName(_ id: String) -> String {
        guard marshalleseNames else { return SliceGame.neutralName(forSwellID: id) }
        // No advisor-approved term exists yet (§5): the label marks
        // the pending term instead of inventing one.
        return "\(SliceGame.neutralName(forSwellID: id)) · pending"
    }

    /// Why the Sail button is disabled, for accessibility labels.
    var sailHint: String {
        guard let selected else { return "Select a canoe" }
        if pendingPath.isEmpty { return "Tap cells to draw a path" }
        if Reducer.reason(.sail(selected, pendingPath), in: state) == nil {
            return "Sail"
        }
        return "Path not legal yet"
    }

    var canPlace: Bool {
        guard let ghost = ghostIsland else { return false }
        return Reducer.reason(.placeIsland(ghost), in: state) == nil
    }

    var canSail: Bool {
        guard let selected, !pendingPath.isEmpty else { return false }
        return Reducer.reason(.sail(selected, pendingPath), in: state) == nil
    }

    var canPass: Bool {
        Reducer.legalActions(in: state) == [.pass]
    }

    var statusLine: String {
        if state.status.isOver {
            switch state.status.winner {
            case .p1: return "You win"
            case .p2: return "Sailor wins"
            case nil: return "Game over"
            }
        }
        return state.toMove == .p1 ? "Your move" : "Sailor is thinking…"
    }

    // MARK: Player input

    /// A tap on a board cell: extends the sail path, selects a canoe,
    /// or arms the placement preview. Does nothing when it is not the
    /// human's turn or the game is over or frozen.
    func tap(_ cell: Hex) {
        guard !isOver, !frozen, !isPaused, state.toMove == .p1 else { return }
        if let ghost = ghostIsland {
            if ghost == cell, canPlace {
                commit(.placeIsland(ghost))
            } else {
                ghostIsland = nil
            }
            return
        }
        if Reducer.reason(.placeIsland(cell), in: state) == nil, state.poolRemaining > 0 {
            ghostIsland = cell
            selected = nil
            pendingPath = []
            return
        }
        if let selected, !pendingPath.isEmpty,
            Reducer.reason(.sail(selected, pendingPath + [cell]), in: state) == nil
        {
            pendingPath.append(cell)
            return
        }
        if let tapped = state.canoe(at: cell), tapped.player == .p1 {
            self.selected = tapped
            pendingPath = []
        }
    }

    func commitSail() {
        guard canSail, let selected else { return }
        commit(.sail(selected, pendingPath))
    }

    func cancelSelection() {
        selected = nil
        pendingPath = []
        ghostIsland = nil
    }

    func pass() {
        guard canPass else { return }
        commit(.pass)
    }

    /// Abandons the match and starts a fresh one on the same seed.
    func restart() {
        aiTask?.cancel()
        aiThinking = false
        isPaused = false
        thinkGeneration += 1  // any in-flight think is now stale
        state = Reducer.initial(chart: state.chart)
        rng = SeededRNG(seed: seed)
        plies = 0
        cancelSelection()
        persist()
        scheduleAIIfNeeded()
    }

    /// S2.2 pause: freezes the match. The pending AI move is
    /// cancelled, so pausing on Sailor's turn holds it until resume.
    func togglePause() {
        guard !isOver else { return }
        if isPaused {
            isPaused = false
            scheduleAIIfNeeded()
        } else {
            isPaused = true
            aiTask?.cancel()
            thinkGeneration += 1  // a landing during pause must discard
            aiThinking = false
        }
    }

    // MARK: Engine

    private func commit(_ action: Action) {
        do {
            let result = try Reducer.apply(action, to: state)
            state = result.state
            plies += 1
            cancelSelection()
            persist()
            scheduleAIIfNeeded()
        } catch {
            // Every action the UI commits was validated first; this is
            // an assertion failure in disguise.
            assertionFailure("illegal action committed: \(error)")
        }
    }

    /// The generation of the pending AI think. State can move on
    /// (pause, resume, restart, a committed human action) while the
    /// detached worker runs; a decision stamped with anything but the
    /// current generation is discarded.
    @Published private(set) var thinkGeneration = 0

    /// Runs the AI think off the main actor (Rosette's P8 fix): the
    /// main actor only snapshots the inputs and lands the decision.
    /// The worker clones the caller's rng state and returns the
    /// advanced state (INV-1: the stream position is part of the
    /// record), so reproducibility survives the hop.
    private func performAI() {
        guard !isOver, !frozen, !isPaused else {
            aiThinking = false
            return
        }
        // Auto-pilot drives both sides; the plain tier only plays its
        // own side.
        guard autoPilot || state.toMove == Self.aiSide else {
            aiThinking = false
            return
        }
        let snapshot = state
        let rngState = rng.state
        let generation = thinkGeneration
        aiTask = Task.detached { [weak self] in
            var workerRNG = SeededRNG(state: rngState)
            let action = Sailor().chooseAction(in: snapshot, rng: &workerRNG)
            let advanced = workerRNG.state
            guard let self, !Task.isCancelled else { return }
            await self.landAI(
                action: action, advancedRNGState: advanced,
                generation: generation)
        }
    }

    /// The main-actor landing path for a finished AI think.
    @MainActor
    private func landAI(action: Action, advancedRNGState: UInt64, generation: Int) {
        defer { aiThinking = false }
        guard generation == thinkGeneration, !isPaused else {
            return  // superseded or paused: discard the decision
        }
        rng = SeededRNG(state: advancedRNGState)
        commit(action)
    }

    /// Runs the AI whenever it should move: on the AI side's turn, or
    /// on either side under auto-pilot (tests and snapshots).
    private func scheduleAIIfNeeded() {
        guard !isOver, !frozen, !isPaused else { return }
        let aiTurn = state.toMove == Self.aiSide
        guard aiTurn || autoPilot else { return }
        aiTask?.cancel()
        thinkGeneration += 1
        // An explicit -aiDelay is respected under auto-pilot too: the
        // auto-pilot default keeps the pace testable (snapshot
        // captures wait on -snapshotPly), but a caller that passes a
        // delay gets that delay on every side's turn — the recording
        // flows run at real play pace through it. MatchModel exposes
        // whether the launch arguments carried -aiDelay.
        let delay =
            explicitAIDelay
            ? aiDelay : (autoPilot ? min(aiDelay, 0.05) : aiDelay)
        aiThinking = aiTurn
        aiTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            self.performAI()
        }
    }

    // MARK: Persistence

    private func persist() {
        let saved = SavedMatch(
            seed: seed, state: state, plies: plies, rngState: rng.state)
        if let data = try? JSONEncoder().encode(saved) {
            defaults.set(data, forKey: Self.saveKey)
        }
        if isOver {
            defaults.removeObject(forKey: Self.saveKey)
        }
    }

    /// S2.4: pause is transient — a resumed session comes back playing,
    /// never frozen behind a forgotten pause flag.
    var persistableState: Bool { !isPaused }
}

/// The persisted match record (seed + full state + rng position), so
/// a resumed game plays on identically (INV-4 replay determinism).
struct SavedMatch: Codable {
    var seed: UInt64
    var state: GameState
    var plies: Int
    var rngState: UInt64
}
