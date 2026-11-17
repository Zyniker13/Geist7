// RSContent — Content loaders and validators for Rosette.
//
// The content tables live in this package's Resources/Content (ADR-0007:
// the single home). The loader decodes them into the roadmap's §5 /
// Appendix A.3 Def types, validates referential integrity, and builds the
// engine types (RuleSet, Tavern, Opponent, Omen, DiceModel) from them.

import Foundation
import RSCore

// MARK: - ContentLoader

/// Loads typed content from JSON files bundled with the app.
public struct ContentLoader {
    private let bundle: Bundle

    public init(bundle: Bundle) {
        self.bundle = bundle
    }

    /// Create a loader with the module bundle.
    public init() {
        self.init(bundle: .module)
    }

    /// Load all dice-model definitions (Appendix A.3).
    public func loadDice() throws -> [DiceModelDef] {
        try loadJSON("dice.json")
    }

    /// Load all ruleset definitions.
    public func loadRulesets() throws -> [RulesetDef] {
        try loadJSON("rulesets.json")
    }

    /// Load the circuit definition (regions, start purse, Crawford flag).
    public func loadCircuit() throws -> CircuitDef {
        try loadJSON("circuit.json")
    }

    /// Load all tavern definitions.
    public func loadTaverns() throws -> [TavernDef] {
        try loadJSON("taverns.json")
    }

    /// Load all opponent definitions.
    public func loadOpponents() throws -> [OpponentDef] {
        try loadJSON("opponents.json")
    }

    /// Load all omen definitions.
    public func loadOmens() throws -> [OmenDef] {
        try loadJSON("omens.json")
    }

    /// Load all fortune squares (R-16, the Tablet ruleset).
    public func loadFortunes() throws -> [FortuneSquareDef] {
        try loadJSON("fortunes.json")
    }

    /// Load tutorial lessons.
    public func loadTutorial() throws -> [TutorialLessonDef] {
        try loadJSON("tutorial.json")
    }

    /// Load balance data.
    public func loadBalance() throws -> BalanceDef {
        try loadJSON("balance.json")
    }

    // MARK: Builders (Def → engine types)

    /// Build the engine dice model for a definition.
    public func makeDiceModel(_ def: DiceModelDef) -> DiceModel {
        DiceModel(
            id: def.id,
            label: def.note,
            outcomes: def.outcomes,
            denominator: def.denominator,
            note: def.note
        )
    }

    /// Build the engine ruleset for a definition. The dice id must resolve
    /// (validated by `validateAll`).
    public func makeRuleSet(_ def: RulesetDef, dice: [DiceModel]) -> RuleSet? {
        guard dice.contains(where: { $0.id == def.dice }) else { return nil }
        return RuleSet(
            id: def.id,
            label: def.name,
            trackLength: def.trackLength,
            pieces: def.pieces,
            rosettes: def.rosettes,
            safeRosettes: def.safeRosettes,
            diceModel: def.dice,
            exactBearOff: def.exactBearOff,
            extraRollOnRosette: def.extraRollOnRosette,
            captureRule: def.captureRule,
            moveGenerator: def.moveGenerator ?? "ur",
            source: def.source,
            historyLabel: def.label
        )
    }

    /// Convenience: every content ruleset as an engine RuleSet.
    public func loadEngineRuleSets() throws -> [RuleSet] {
        let dice = try loadDice().map(makeDiceModel)
        return try loadRulesets().compactMap { makeRuleSet($0, dice: dice) }
    }

    /// The engine dice model for a ruleset id.
    public func diceModel(forRulesetID rulesetID: String) throws -> DiceModel? {
        let rulesets = try loadRulesets()
        let dice = try loadDice().map(makeDiceModel)
        guard let def = rulesets.first(where: { $0.id == rulesetID }) else { return nil }
        return dice.first(where: { $0.id == def.dice })
    }

    /// The taverns in circuit order (circuit.json defines the walk; R-13).
    public func loadCircuitTaverns() throws -> [Tavern] {
        let circuit = try loadCircuit()
        let taverns = try loadTaverns()
        let byID = Dictionary(uniqueKeysWithValues: taverns.map { ($0.id, $0) })
        var ordered: [Tavern] = []
        for region in circuit.regions {
            for id in region.taverns {
                guard let def = byID[id] else {
                    throw ContentError.validationErrors(["Circuit references unknown tavern: \(id)"]
                    )
                }
                ordered.append(Tavern(def: def))
            }
        }
        return ordered
    }

    /// A new circuit run from content (R-13).
    public func newCircuitState() throws -> CircuitState {
        let circuit = try loadCircuit()
        return CircuitState(
            taverns: try loadCircuitTaverns(),
            startPurse: circuit.startPurse,
            finalCrawford: circuit.finalCrawford
        )
    }

    /// The fortunes for a ruleset (R-16); empty for rulesets without any.
    public func loadEngineFortunes(rulesetID: String) throws -> [FortuneSquare] {
        try loadFortunes()
            .filter { $0.ruleset == rulesetID }
            .compactMap { def in
                guard let deck = FortuneDeck(rawValue: def.omenDeck) else { return nil }
                return FortuneSquare(rulesetId: def.ruleset, square: def.square, deck: deck)
            }
    }

    /// The omens an opponent may hold (R-12), as engine Omen values.
    public func omens(forOpponent opponent: OpponentDef) throws -> [Omen] {
        let all = try loadOmens()
        return opponent.omens.compactMap { id in
            all.first(where: { $0.id == id }).map { def in
                Omen(id: def.id, effect: def.effect, cost: def.cost, label: def.label)
            }
        }
    }

    // MARK: - Validation

    /// Validate referential integrity across all content (§5: no dangling
    /// IDs), the counts table's G3 levels, and HIST3.1 label requirements.
    public func validateAll() throws -> ValidationResult {
        let dice = try loadDice()
        let rulesets = try loadRulesets()
        let circuit = try loadCircuit()
        let taverns = try loadTaverns()
        let opponents = try loadOpponents()
        let omens = try loadOmens()
        let fortunes = try loadFortunes()
        let tutorial = try loadTutorial()

        var errors: [String] = []

        // Unique ids per table.
        for (name, defs) in [
            ("dice", dice.map(\.id)),
            ("ruleset", rulesets.map(\.id)),
            ("tavern", taverns.map(\.id)),
            ("opponent", opponents.map(\.id)),
            ("omen", omens.map(\.id)),
        ] {
            if defs.count != Set(defs).count {
                errors.append("Duplicate \(name) IDs found")
            }
        }

        let rulesetIds = Set(rulesets.map(\.id))
        let tavernIds = Set(taverns.map(\.id))
        let opponentIds = Set(opponents.map(\.id))
        let omenIds = Set(omens.map(\.id))
        let diceIds = Set(dice.map(\.id))

        // Tavern → ruleset / opponent (referential).
        for tavern in taverns {
            if !rulesetIds.contains(tavern.ruleset) {
                errors.append(
                    "Tavern '\(tavern.id)' references unknown ruleset '\(tavern.ruleset)'")
            }
            if !opponentIds.contains(tavern.opponent) {
                errors.append(
                    "Tavern '\(tavern.id)' references unknown opponent '\(tavern.opponent)'")
            }
        }

        // Opponent → omens.
        for opponent in opponents {
            for omenId in opponent.omens where !omenIds.contains(omenId) {
                errors.append("Opponent '\(opponent.id)' references unknown omen '\(omenId)'")
            }
        }

        // Ruleset → dice model.
        for ruleset in rulesets where !diceIds.contains(ruleset.dice) {
            errors.append("Ruleset '\(ruleset.id)' references unknown dice model '\(ruleset.dice)'")
        }

        // Circuit: regions × 4 taverns, every tavern listed exactly once,
        // tavern rows agree with their region, unlocks resolve.
        for region in circuit.regions {
            if region.taverns.count != 4 {
                errors.append("Region '\(region.id)' must list exactly 4 taverns (R-13)")
            }
            for tavernId in region.taverns where !tavernIds.contains(tavernId) {
                errors.append("Region '\(region.id)' references unknown tavern '\(tavernId)'")
            }
            for unlock in region.unlocks where !rulesetIds.contains(unlock) {
                errors.append("Region '\(region.id)' unlocks unknown ruleset '\(unlock)'")
            }
            for tavern in taverns
            where region.taverns.contains(tavern.id) && tavern.region != region.id {
                errors.append(
                    "Tavern '\(tavern.id)' region '\(tavern.region)' disagrees with circuit region '\(region.id)'"
                )
            }
        }
        let listed = circuit.regions.flatMap(\.taverns)
        if listed.count != taverns.count || Set(listed) != tavernIds {
            errors.append("Circuit must list every tavern exactly once")
        }
        if circuit.regions.count != 3 {
            errors.append("The circuit must have exactly 3 regions (R-13)")
        }

        // Fortune squares resolve to a ruleset and a known deck.
        for fortune in fortunes {
            if !rulesetIds.contains(fortune.ruleset) {
                errors.append("Fortune square references unknown ruleset '\(fortune.ruleset)'")
            }
            if FortuneDeck(rawValue: fortune.omenDeck) == nil {
                errors.append("Fortune square references unknown omen deck '\(fortune.omenDeck)'")
            }
        }

        // Tutorial lessons resolve to rulesets.
        for lesson in tutorial where !rulesetIds.contains(lesson.rulesetId) {
            errors.append(
                "Tutorial lesson '\(lesson.id)' references unknown ruleset '\(lesson.rulesetId)'")
        }

        // Counts (§5 counts table, G3 column; authored at G5 levels).
        if rulesets.count < 3 { errors.append("rulesets.json needs at least 3 rows at G3") }
        if taverns.count < 6 { errors.append("taverns.json needs at least 6 rows at G3") }
        if opponents.count < 6 { errors.append("opponents.json needs at least 6 rows at G3") }
        if omens.count < 6 { errors.append("omens.json needs at least 6 rows at G3") }
        if tutorial.count < 3 { errors.append("tutorial.json needs 3 lessons (RS-P3.2)") }

        // §6: omen prices 5–40.
        for omen in omens where omen.cost < 5 || omen.cost > 40 {
            errors.append("Omen '\(omen.id)' cost \(omen.cost) outside the 5–40 range (§6)")
        }

        return ValidationResult(
            errors: errors,
            dice: dice,
            rulesets: rulesets,
            circuit: circuit,
            taverns: taverns,
            opponents: opponents,
            omens: omens,
            fortunes: fortunes,
            tutorial: tutorial
        )
    }

    private func loadJSON<T: Decodable>(_ filename: String) throws -> T {
        guard let url = bundle.url(forResource: filename, withExtension: nil) else {
            throw ContentError.missingFile(filename)
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - ValidationResult

/// Result of content validation.
public struct ValidationResult {
    public let errors: [String]
    public let dice: [DiceModelDef]
    public let rulesets: [RulesetDef]
    public let circuit: CircuitDef
    public let taverns: [TavernDef]
    public let opponents: [OpponentDef]
    public let omens: [OmenDef]
    public let fortunes: [FortuneSquareDef]
    public let tutorial: [TutorialLessonDef]

    /// Whether validation passed (no errors).
    public var isValid: Bool {
        errors.isEmpty
    }
}

// MARK: - ContentError

enum ContentError: Error, CustomStringConvertible {
    case missingFile(String)
    case decodeError(Error)
    case validationErrors([String])

    var description: String {
        switch self {
        case .missingFile(let name):
            return "Missing content file: \(name)"
        case .decodeError(let error):
            return "Content decode error: \(error)"
        case .validationErrors(let errors):
            return "Content validation errors: \(errors.joined(separator: ", "))"
        }
    }
}
