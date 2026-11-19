// MARK: - CircuitView

import RSContent
import RSCore
import SwiftUI

// MARK: - CircuitSession

/// The state of one tavern-circuit run in the UI (R-13, R-14). Bridges
/// `CircuitState` to the match screen: entering a tavern pays the buy-in,
/// the match plays under the tavern's ruleset, and the outcome is recorded
/// (a win advances; a loss offers a re-challenge).
@MainActor
final class CircuitSession: ObservableObject {

    /// The Game Center bridge, injected by the view once its environment
    /// has it (RS-P7.1: the circuit purse doubles as a leaderboard score).
    weak var gameCenter: GameCenterManager?

    /// One match waiting to be played at the current tavern.
    struct PendingMatch: Identifiable {
        let id = UUID()
        let tavern: Tavern
        let opponent: Opponent
        let ruleset: RuleSet
        let dice: DiceModel
        let stake: Int
        let omens1: [Omen]
        let fortunes: [FortuneSquare]
    }

    @Published private(set) var circuit: CircuitState
    /// The tavern whose buy-in has been paid and whose match is on screen.
    @Published var pendingMatch: PendingMatch?
    @Published private(set) var lastResultText: String = ""
    @Published private(set) var loadError: String?

    private let loader = ContentLoader()
    private let rulesetByID: [String: RuleSet]
    private let diceByID: [String: DiceModel]
    private let opponentByID: [String: OpponentDef]
    private let omenDefs: [OmenDef]
    private let fortunesByRuleset: [String: [FortuneSquare]]
    private let startPurseValue: Int

    private struct Loaded {
        var rulesetByID: [String: RuleSet] = [:]
        var diceByID: [String: DiceModel] = [:]
        var opponentByID: [String: OpponentDef] = [:]
        var omenDefs: [OmenDef] = []
        var fortunesByRuleset: [String: [FortuneSquare]] = [:]
        var startPurse: Int = 0
        var circuit: CircuitState?
        var error: String?
    }

    private static func loadContent(_ loader: ContentLoader) -> Loaded {
        do {
            let rulesets = try loader.loadEngineRuleSets()
            let dice = try loader.loadDice().map { loader.makeDiceModel($0) }
            var fortunes: [String: [FortuneSquare]] = [:]
            for def in try loader.loadFortunes() {
                guard let deck = FortuneDeck(rawValue: def.omenDeck) else { continue }
                fortunes[def.ruleset, default: []].append(
                    FortuneSquare(rulesetId: def.ruleset, square: def.square, deck: deck))
            }
            return Loaded(
                rulesetByID: Dictionary(uniqueKeysWithValues: rulesets.map { ($0.id, $0) }),
                diceByID: Dictionary(uniqueKeysWithValues: dice.map { ($0.id, $0) }),
                opponentByID: Dictionary(
                    uniqueKeysWithValues: try loader.loadOpponents().map { ($0.id, $0) }),
                omenDefs: try loader.loadOmens(),
                fortunesByRuleset: fortunes,
                startPurse: try loader.loadCircuit().startPurse,
                circuit: try loader.newCircuitState()
            )
        } catch {
            return Loaded(error: "Could not load the circuit: \(error)")
        }
    }

    init() {
        let loaded = Self.loadContent(loader)
        self.rulesetByID = loaded.rulesetByID
        self.diceByID = loaded.diceByID
        self.opponentByID = loaded.opponentByID
        self.omenDefs = loaded.omenDefs
        self.fortunesByRuleset = loaded.fortunesByRuleset
        self.startPurseValue = loaded.startPurse
        if let circuit = loaded.circuit {
            self.circuit = circuit
        } else {
            self.circuit = CircuitState(taverns: [], startPurse: 0, finalCrawford: false)
        }
        self.loadError = loaded.error
    }

    // MARK: Derived view state

    var taverns: [Tavern] { circuit.taverns }
    var currentTavern: Tavern? { circuit.currentTavern }
    var startPurse: Int { startPurseValue }
    var isRunOver: Bool { circuit.isOver }
    var purse: Int { circuit.purse.balance }

    /// The current tavern's opponent definition, if any.
    var currentOpponentDef: OpponentDef? {
        currentTavern.flatMap { opponentByID[$0.opponentId] }
    }

    /// Omens the player currently holds, as definitions for display.
    var heldOmenDefs: [OmenDef] {
        omenDefs.filter { circuit.heldOmens.contains($0.id) }
    }

    /// All omen definitions, for the shop display.
    var allOmenDefs: [OmenDef] { omenDefs }

    /// Whether the player may buy the given omen right now (R-12, R-14).
    func canBuy(_ omen: OmenDef) -> Bool {
        circuit.heldOmens.count < 2 && circuit.purse.balance >= omen.cost
    }

    /// Buy an omen between matches (R-14).
    func buy(_ omen: OmenDef) {
        guard canBuy(omen) else { return }
        _ = circuit.buyOmen(omen)
        persistCircuit()
    }

    /// Whether this opponent's tell has been learned (R-24).
    func hasTell(_ opponent: OpponentDef) -> Bool {
        circuit.learnedTells.contains(opponent.id)
    }

    /// Pay to learn the current opponent's tell (R-14/R-24).
    func learnTell() {
        guard let def = currentOpponentDef,
            !circuit.learnedTells.contains(def.id)
        else { return }
        _ = circuit.learnTell(def)
        persistCircuit()
    }

    // MARK: Match flow

    /// Sit down at the current tavern: pay the buy-in and prepare the match.
    func sitDown() {
        guard let tavern = currentTavern, !circuit.isRunEnded, pendingMatch == nil else { return }
        guard circuit.payBuyIn() else { return }
        persistCircuit()
        let ruleset =
            rulesetByID[tavern.rulesetId]
            ?? GameViewModel.contentDefaults().ruleset
        let dice = diceByID[ruleset.diceModel] ?? .tetra4
        let opponentDef = opponentByID[tavern.opponentId]
        let heldOmens: [Omen] = (opponentDef?.omens ?? []).compactMap { id in
            omenDefs.first(where: { $0.id == id }).map {
                Omen(id: $0.id, effect: $0.effect, cost: $0.cost, label: $0.label)
            }
        }
        pendingMatch = PendingMatch(
            tavern: tavern,
            opponent: opponentDef.map(Opponent.init(def:))
                ?? Opponent(
                    id: "unknown", name: "Stranger", personality: .careful,
                    cubeAggression: 3, omenIds: [], tellCost: 10, label: .invented),
            ruleset: ruleset,
            dice: dice,
            stake: circuit.stake(for: tavern),
            omens1: heldOmens,
            fortunes: fortunesByRuleset[tavern.rulesetId] ?? []
        )
    }

    /// Record a finished match. A win advances to the next tavern; a loss
    /// leaves the player here to re-challenge (buying in again).
    func recordOutcome(_ outcome: Outcome) {
        guard let match = pendingMatch else { return }
        let won = outcome.winner == .player0
        circuit.recordResult(
            won: won,
            stake: match.stake,
            gammon: outcome.gammon
        )
        if won {
            circuit.advanceTavern()
        }
        lastResultText =
            won
            ? "Won \(outcome.score(for: .player0)) at \(match.tavern.name)"
            : "Lost \(abs(outcome.score(for: .player0))) at \(match.tavern.name)"
        pendingMatch = nil
        persistCircuit()
        // The purse doubles as the circuit's Game Center score (RS-P7.1).
        if let gameCenter {
            Task { await gameCenter.reportCircuitPurse(circuit.purse.balance) }
        }
    }

    /// Forfeit the pending match: recorded as a loss at the stake.
    func forfeit() {
        guard let match = pendingMatch else { return }
        circuit.recordResult(won: false, stake: match.stake)
        lastResultText = "Forfeited the match at \(match.tavern.name)"
        pendingMatch = nil
        persistCircuit()
    }

    /// Start a fresh run (after a run ends).
    func newRun() {
        if let fresh = try? loader.newCircuitState() {
            circuit = fresh
            lastResultText = ""
            persistCircuit()
        }
    }

    // MARK: iCloud sync (RS-P7.1)

    /// The app-wide sync manager (the local file-store substitute).
    private let cloud = CloudSyncManager.shared
    /// Whether the launch-time restore has run (it runs once per model).
    private var didRestore = false

    /// Restore the stored circuit at first presentation (the store copy
    /// wins when present — see CloudSyncManager for the policy).
    func restoreFromCloud() async {
        guard !didRestore else { return }
        didRestore = true
        if let stored = await cloud.pull() {
            circuit = stored
        }
    }

    /// Push the current circuit state to the store (best-effort).
    private func persistCircuit() {
        let state = circuit
        Task { await cloud.push(state) }
    }
}

// MARK: - CircuitView

/// The tavern-circuit screen: purse, tavern ladder, omen shop, and tells.
struct CircuitView: View {
    @StateObject private var session = CircuitSession()
    @EnvironmentObject private var gameCenter: GameCenterManager

    var body: some View {
        Group {
            if let error = session.loadError {
                ContentUnavailableView(
                    "Circuit unavailable", systemImage: "exclamationmark.triangle",
                    description: Text(error))
            } else {
                circuitContent
            }
        }
        .navigationTitle("Tavern Circuit")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            // Restore the stored circuit once per presentation (RS-P7.1) and
            // hand the session the Game Center bridge from the environment.
            session.gameCenter = gameCenter
            await session.restoreFromCloud()
        }
    }

    private var circuitContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                tavernLadder
                if let opponent = session.currentOpponentDef, !session.isRunOver {
                    tellSection(opponent)
                }
                omenShop
                if session.isRunOver {
                    runOverCard
                }
            }
            .padding()
        }
        // iOS presents the match full-screen (the board needs the whole
        // display — a sheet clips it); macOS uses a window-modal sheet.
        .modifier(
            MatchPresentation(item: $session.pendingMatch) { match in
                CircuitMatchView(session: session, match: match)
            })
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Purse: \(session.purse)")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Text("\(session.circuit.tavernsCompleted)/\(session.taverns.count) taverns")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            if !session.lastResultText.isEmpty {
                Text(session.lastResultText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    /// The 12-tavern ladder in circuit order (R-13).
    private var tavernLadder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("The Circuit")
                .font(.headline)
            ForEach(Array(session.taverns.enumerated()), id: \.element.id) { index, tavern in
                tavernRow(index: index, tavern: tavern)
            }
        }
    }

    @ViewBuilder
    private func tavernRow(index: Int, tavern: Tavern) -> some View {
        let isCurrent = session.currentTavern?.id == tavern.id
        let isDone = index < session.circuit.tavernsCompleted
        HStack {
            Image(
                systemName: isDone
                    ? "checkmark.circle.fill" : isCurrent ? "circle.fill" : "circle"
            )
            .foregroundColor(isDone ? .green : isCurrent ? .yellow : .gray)
            VStack(alignment: .leading) {
                Text(tavern.name)
                    .font(.subheadline)
                    .fontWeight(isCurrent ? .bold : .regular)
                Text(
                    "\(tavern.rulesetId) · stake ≥\(tavern.minStake) · buy-in \(tavern.buyIn)\(tavern.gammonRule ? " · gammon ×2" : "")"
                )
                .font(.caption2)
                .foregroundColor(.gray)
                if isCurrent, let note = tavern.historyNote {
                    Text(note)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if isCurrent, !session.isRunOver {
                Button(action: { session.sitDown() }) {
                    Text("Sit Down")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .disabled(session.pendingMatch != nil)
            }
        }
        .padding(8)
        .background(isCurrent ? Color.yellow.opacity(0.12) : Color.clear)
        .cornerRadius(8)
    }

    /// R-14/R-24: pay the current opponent's tell cost to learn its cube policy.
    private func tellSection(_ opponent: OpponentDef) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(opponent.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if session.hasTell(opponent) {
                    Text(Opponent(def: opponent).tell())
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("A stranger at the table. Learn their habits for \(opponent.tellCost).")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
            if !session.hasTell(opponent) {
                Button("Learn Tell (\(opponent.tellCost))") {
                    session.learnTell()
                }
                .font(.caption)
                .disabled(session.purse < opponent.tellCost)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.04))
        .cornerRadius(8)
    }

    /// R-14: the omen shop.
    private var omenShop: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Omens (\(session.circuit.heldOmens.count)/2 held)")
                .font(.headline)
            ForEach(session.allOmenDefs, id: \.id) { omen in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(omen.name)
                            .font(.subheadline)
                        Text(effectText(omen.effect) + " · \(omen.label.displayName)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Text("\(omen.cost)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    if session.circuit.heldOmens.contains(omen.id) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Button("Buy") { session.buy(omen) }
                            .font(.caption)
                            .disabled(!session.canBuy(omen))
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var runOverCard: some View {
        VStack(spacing: 12) {
            Text(session.circuit.isComplete ? "Circuit Complete!" : "The Run Ends Here")
                .font(.title3)
                .fontWeight(.bold)
            Text(
                session.circuit.isComplete
                    ? "You conquered all \(session.taverns.count) taverns with \(session.purse) in the purse."
                    : "The purse cannot cover another table. Final purse: \(session.purse)."
            )
            .font(.caption)
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)

            Text("Matches: \(session.circuit.totalGames) · Wins: \(session.circuit.totalWins)")
                .font(.caption2)
                .foregroundColor(.gray)

            Button(action: { session.newRun() }) {
                Text("Start a New Run")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.black.opacity(0.05))
        .cornerRadius(12)
    }

    private func effectText(_ effect: OmenEffect) -> String {
        switch effect.kind {
        case .reroll: return "Re-roll once"
        case .unsafeRosettes: return "Open the wards (rosettes unsafe)"
        case .split: return "Split the roll"
        }
    }
}

// MARK: - MatchPresentation

/// Platform-split presentation for a circuit match: full-screen cover on
/// iOS/iPadOS, sheet on macOS.
struct MatchPresentation<Item: Identifiable, MatchView: View>: ViewModifier {
    @Binding var item: Item?
    @ViewBuilder let matchView: (Item) -> MatchView

    func body(content base: Content) -> some View {
        #if os(iOS)
            base.fullScreenCover(item: $item, content: matchView)
        #else
            base.sheet(item: $item, content: matchView)
        #endif
    }
}

// MARK: - CircuitMatchView

/// A match inside the circuit run: the game screen with a forfeit control;
/// when the match completes, the outcome is recorded and the cover dismisses.
struct CircuitMatchView: View {
    @ObservedObject var session: CircuitSession
    let match: CircuitSession.PendingMatch
    @Environment(\.dismiss) private var dismiss
    @State private var completed = false

    var body: some View {
        NavigationStack {
            GameView(
                ruleset: match.ruleset,
                dice: match.dice,
                fortunes: match.fortunes,
                omens1: match.omens1,
                stake: match.stake,
                region: match.tavern.region,
                showPlayAgain: false,
                onMatchComplete: { outcome in
                    guard !completed else { return }
                    completed = true
                    session.recordOutcome(outcome)
                    // Brief pause so the result is readable, then return to
                    // the circuit screen.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        dismiss()
                    }
                }
            )
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Forfeit") {
                        session.forfeit()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text(match.tavern.name)
                            .font(.headline)
                        Text("vs \(match.opponent.name) · stake \(match.stake)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .interactiveDismissDisabled()
    }
}
