// MARK: - Tavern

/// A tavern in the circuit (R-13): a stop with an opponent, a ruleset, a
/// minimum stake, and a buy-in. Loaded from content; the circuit's order is
/// the content order (CircuitDef.regions → taverns).
public struct Tavern: Sendable, Equatable, Codable {
    /// Unique identifier (from content).
    public let id: String
    /// Display name.
    public let name: String
    /// Region this tavern belongs to ("ur", "thebes", "tenochtitlan").
    public let region: String
    /// The ruleset played here (referential: rulesets.json id).
    public let rulesetId: String
    /// The opponent waiting here (referential: opponents.json id).
    public let opponentId: String
    /// R-9/R-13: the minimum stake for a match here.
    public let minStake: Int
    /// R-13: the buy-in to sit down at this tavern.
    public let buyIn: Int
    /// R-11: the gammon-equivalent double loss, toggled per tavern.
    public let gammonRule: Bool
    /// HIST3.1: the tavern's history label.
    public let label: HistoryLabel
    /// HIST3.1: the tavern's in-game historical note, if any.
    public let historyNote: String?

    /// Create from a definition.
    public init(def: TavernDef) {
        self.id = def.id
        self.name = def.name
        self.region = def.region
        self.rulesetId = def.ruleset
        self.opponentId = def.opponent
        self.minStake = def.minStake
        self.buyIn = def.buyIn
        self.gammonRule = def.gammonRule
        self.label = def.label
        self.historyNote = def.historyNote
    }

    /// Create directly (test fixtures).
    public init(
        id: String,
        name: String,
        region: String,
        rulesetId: String,
        opponentId: String,
        minStake: Int,
        buyIn: Int,
        gammonRule: Bool = false,
        label: HistoryLabel,
        historyNote: String? = nil
    ) {
        self.id = id
        self.name = name
        self.region = region
        self.rulesetId = rulesetId
        self.opponentId = opponentId
        self.minStake = minStake
        self.buyIn = buyIn
        self.gammonRule = gammonRule
        self.label = label
        self.historyNote = historyNote
    }
}
