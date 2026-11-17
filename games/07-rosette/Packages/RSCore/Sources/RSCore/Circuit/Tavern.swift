// MARK: - Tavern

/// A tavern in the circuit (game-state, loaded from content).
public struct Tavern: Sendable, Equatable, Codable {
    /// Unique identifier (from content).
    public let id: String
    /// Display name.
    public let name: String
    /// Region this tavern belongs to.
    public let region: String
    /// Difficulty level (1–5).
    public let difficulty: Int
    /// The AI opponent's level.
    public let aiLevel: Int
    /// The starting stake.
    public let stake: Int
    /// Any special rules.
    public let specialRules: [String]
    /// History label for HIST3.1.
    public let label: HistoryLabel

    /// Create from a definition.
    public init(def: TavernDef) {
        self.id = def.id
        self.name = def.name
        self.region = def.region
        self.difficulty = def.difficulty
        self.aiLevel = def.aiLevel
        self.stake = def.stake
        self.specialRules = def.specialRules
        self.label = def.label
    }

    /// Create directly (for hardcoded taverns).
    public init(
        id: String,
        name: String,
        region: String,
        difficulty: Int,
        aiLevel: Int,
        stake: Int,
        specialRules: [String],
        label: HistoryLabel
    ) {
        self.id = id
        self.name = name
        self.region = region
        self.difficulty = difficulty
        self.aiLevel = aiLevel
        self.stake = stake
        self.specialRules = specialRules
        self.label = label
    }

    /// The first tavern (Thebes, difficulty 1).
    public static func firstTavern() -> Tavern {
        Tavern(
            id: "thebes_scribe",
            name: "The Ancient Scribe",
            region: "Thebes",
            difficulty: 1,
            aiLevel: 1,
            stake: 1,
            specialRules: [],
            label: .reconstructed
        )
    }

    /// Advance to the next tavern in the sequence.
    public func nextTavern() -> Tavern {
        let nextLevel = min(difficulty + 1, 5)
        let nextId = nextTavernId(for: id, at: nextLevel)
        return Tavern(
            id: nextId,
            name: tavernName(for: nextId),
            region: tavernRegion(for: nextId),
            difficulty: nextLevel,
            aiLevel: nextLevel,
            stake: stake * 2,
            specialRules: tavernSpecialRules(for: nextId),
            label: tavernLabel(for: nextId)
        )
    }

    /// The final tavern (Akhetaten, difficulty 5).
    public static func finalTavern() -> Tavern {
        Tavern(
            id: "akhet_pharaoh",
            name: "The Pharaoh's Gambit",
            region: "Akhetaten",
            difficulty: 5,
            aiLevel: 5,
            stake: 16,
            specialRules: ["double_gammon", "omen_blessing", "omen_curse"],
            label: .reconstructed
        )
    }

    /// Check if this is the final tavern.
    public var isFinal: Bool {
        id == "akhet_pharaoh"
    }

    /// Check if this tavern has a special rule.
    public func hasSpecialRule(_ rule: String) -> Bool {
        specialRules.contains(rule)
    }

    // MARK: - Private helpers

    private func nextTavernId(for currentId: String, at level: Int) -> String {
        let levelTaverns: [[String]] = [
            ["thebes_scribe", "memphis_scribe", "akhet_artist"],
            ["thebes_guard", "memphis_weaver", "akhet_solar"],
            ["thebes_merchant", "memphis_stone", "akhet_rebel"],
            ["thebes_priest", "memphis_vizier"],
            ["akhet_pharaoh"]
        ]
        if level <= levelTaverns.count {
            let tavernsAtLevel = levelTaverns[level - 1]
            if let idx = tavernsAtLevel.firstIndex(of: currentId), idx + 1 < tavernsAtLevel.count {
                return tavernsAtLevel[idx + 1]
            }
        }
        return "akhet_pharaoh"
    }

    private func tavernName(for id: String) -> String {
        switch id {
        case "thebes_scribe": return "The Ancient Scribe"
        case "thebes_guard": return "The Temple Guard"
        case "thebes_merchant": return "The Merchant Quarter"
        case "thebes_priest": return "The Royal Court"
        case "memphis_scribe": return "The Memphis Archivist"
        case "memphis_weaver": return "The Weaver's Guild"
        case "memphis_stone": return "The Stone Mason"
        case "memphis_vizier": return "The Vizier's Table"
        case "akhet_artist": return "The Artist's Atelier"
        case "akhet_solar": return "The Solar Disc"
        case "akhet_rebel": return "The Heretic's Gambit"
        case "akhet_pharaoh": return "The Pharaoh's Gambit"
        default: return "Unknown Tavern"
        }
    }

    private func tavernRegion(for id: String) -> String {
        switch id {
        case "thebes_scribe", "thebes_guard", "thebes_merchant", "thebes_priest":
            return "Thebes"
        case "memphis_scribe", "memphis_weaver", "memphis_stone", "memphis_vizier":
            return "Memphis"
        case "akhet_artist", "akhet_solar", "akhet_rebel", "akhet_pharaoh":
            return "Akhetaten"
        default:
            return "Unknown"
        }
    }

    private func tavernSpecialRules(for id: String) -> [String] {
        switch id {
        case "thebes_merchant": return ["double_gammon"]
        case "thebes_priest": return ["omen_blessing"]
        case "memphis_stone": return ["sphinx_gaze"]
        case "memphis_vizier": return ["double_gammon", "omen_blessing"]
        case "akhet_rebel": return ["omen_curse"]
        case "akhet_pharaoh": return ["double_gammon", "omen_blessing", "omen_curse"]
        default: return []
        }
    }

    private func tavernLabel(for id: String) -> HistoryLabel {
        switch id {
        case "thebes_scribe", "thebes_guard", "thebes_merchant", "thebes_priest",
             "memphis_scribe", "memphis_weaver", "memphis_stone", "memphis_vizier",
             "akhet_artist", "akhet_solar", "akhet_rebel", "akhet_pharaoh":
            return .reconstructed
        default:
            return .invented
        }
    }
}
