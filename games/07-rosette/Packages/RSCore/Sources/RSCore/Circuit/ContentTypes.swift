// Content type definitions — the Codable mirrors of the game roadmap's
// §5 data schemas and Appendix A.3 (each field mirrors the roadmap
// field-for-field; additions are listed in docs/DECISIONS.md).
//
// This file lives inside RSCore and uses its engine types directly, so it
// imports nothing.

// MARK: - RulesetDef

/// A ruleset definition (roadmap §5: `RuleSetDef`).
public struct RulesetDef: Sendable, Codable, Equatable {
    public let id: String
    /// Display name (justified extra, ADR-0007; A.9 names the default
    /// "Modern rules (Finkel/RoyalUr)").
    public let name: String
    public let label: HistoryLabel
    public let trackLength: Int
    public let pieces: Int
    public let rosettes: [Int]
    public let safeRosettes: [Int]
    public let dice: String
    public let exactBearOff: Bool
    public let extraRollOnRosette: Bool
    public let captureRule: CaptureRule
    public let source: String
    /// Which move generator implements this ruleset ("ur", "senet-like",
    /// "patolli-like"); nil means "ur". Justified extra (ADR-0007): the
    /// engine routes move generation through this id.
    public let moveGenerator: String?

    public init(
        id: String,
        name: String,
        label: HistoryLabel,
        trackLength: Int,
        pieces: Int,
        rosettes: [Int],
        safeRosettes: [Int],
        dice: String,
        exactBearOff: Bool,
        extraRollOnRosette: Bool,
        captureRule: CaptureRule,
        source: String,
        moveGenerator: String? = nil
    ) {
        self.id = id
        self.name = name
        self.label = label
        self.trackLength = trackLength
        self.pieces = pieces
        self.rosettes = rosettes
        self.safeRosettes = safeRosettes
        self.dice = dice
        self.exactBearOff = exactBearOff
        self.extraRollOnRosette = extraRollOnRosette
        self.captureRule = captureRule
        self.source = source
        self.moveGenerator = moveGenerator
    }
}

// MARK: - TavernDef

/// A tavern definition (roadmap §5 sample row: id, region, ruleset,
/// opponent, minStake, buyIn; R-11/§6 add the per-tavern gammon toggle).
public struct TavernDef: Sendable, Codable, Equatable {
    public let id: String
    /// Display name (justified extra, ADR-0007: the circuit UI needs one).
    public let name: String
    public let region: String
    public let ruleset: String
    public let opponent: String
    public let minStake: Int
    public let buyIn: Int
    /// R-11: the gammon-equivalent double loss, toggled per tavern (§6).
    public let gammonRule: Bool
    /// HIST3.1: every in-game historical note carries a label.
    public let label: HistoryLabel
    /// The in-game historical note (HIST3.1), if any.
    public let historyNote: String?

    public init(
        id: String,
        name: String,
        region: String,
        ruleset: String,
        opponent: String,
        minStake: Int,
        buyIn: Int,
        gammonRule: Bool,
        label: HistoryLabel,
        historyNote: String? = nil
    ) {
        self.id = id
        self.name = name
        self.region = region
        self.ruleset = ruleset
        self.opponent = opponent
        self.minStake = minStake
        self.buyIn = buyIn
        self.gammonRule = gammonRule
        self.label = label
        self.historyNote = historyNote
    }
}

// MARK: - OpponentDef

/// An opponent definition (roadmap §5 sample row: id, name, ai,
/// cubeAggression, omens, tellCost).
public struct OpponentDef: Sendable, Codable, Equatable {
    public let id: String
    public let name: String
    /// The personality id (roadmap §7: careful, greedy, bluffer, gambler).
    public let ai: String
    public let cubeAggression: Int
    /// Omen ids this opponent may hold (referential: ⊆ omens.json ids).
    public let omens: [String]
    /// R-14: what it costs to learn this opponent's tell (R-24).
    public let tellCost: Int
    /// HIST3.1: every in-game historical note carries a label.
    public let label: HistoryLabel
    /// The in-game historical note (HIST3.1), if any.
    public let historyNote: String?

    public init(
        id: String,
        name: String,
        ai: String,
        cubeAggression: Int,
        omens: [String],
        tellCost: Int,
        label: HistoryLabel,
        historyNote: String? = nil
    ) {
        self.id = id
        self.name = name
        self.ai = ai
        self.cubeAggression = cubeAggression
        self.omens = omens
        self.tellCost = tellCost
        self.label = label
        self.historyNote = historyNote
    }
}

// MARK: - OmenDef

/// An omen definition (roadmap §5: `OmenDef { id, cost, effect, label }`).
public struct OmenDef: Sendable, Codable, Equatable {
    public let id: String
    /// Display name (justified extra, ADR-0007: the omen shop needs one).
    public let name: String
    public let cost: Int
    public let effect: OmenEffect
    /// HIST3.1: every in-game historical note carries a label.
    public let label: HistoryLabel
    /// The in-game historical note (HIST3.1), if any.
    public let historyNote: String?

    public init(
        id: String,
        name: String,
        cost: Int,
        effect: OmenEffect,
        label: HistoryLabel,
        historyNote: String? = nil
    ) {
        self.id = id
        self.name = name
        self.cost = cost
        self.effect = effect
        self.label = label
        self.historyNote = historyNote
    }
}

// MARK: - DiceModelDef

/// A dice model definition (Appendix A.3: `DiceModelDef`).
public struct DiceModelDef: Sendable, Codable, Equatable {
    public let id: String
    public let label: HistoryLabel
    public let outcomes: [DiceOutcome]
    public let denominator: Int
    public let note: String

    public init(
        id: String,
        label: HistoryLabel,
        outcomes: [DiceOutcome],
        denominator: Int,
        note: String
    ) {
        self.id = id
        self.label = label
        self.outcomes = outcomes
        self.denominator = denominator
        self.note = note
    }
}

// MARK: - FortuneSquareDef

/// A fortune square (Appendix A.3: `FortuneSquareDef`; R-16: the tablet
/// attaches fortunes to specific squares, drawn as omen effects on landing —
/// attested that squares carry fortunes; the in-game effects are Invented).
public struct FortuneSquareDef: Sendable, Codable, Equatable {
    public let ruleset: String
    public let square: Int
    public let omenDeck: String
    public let label: HistoryLabel

    public init(ruleset: String, square: Int, omenDeck: String, label: HistoryLabel) {
        self.ruleset = ruleset
        self.square = square
        self.omenDeck = omenDeck
        self.label = label
    }
}

// MARK: - CircuitDef

/// The circuit definition (Appendix A.3: `CircuitDef`; R-13: 3 regions × 4
/// taverns; §6/A.4: the starting purse; R-22: Crawford in circuit finals).
public struct CircuitDef: Sendable, Codable, Equatable {
    public let regions: [RegionDef]
    public let startPurse: Int
    public let finalCrawford: Bool

    public init(regions: [RegionDef], startPurse: Int, finalCrawford: Bool) {
        self.regions = regions
        self.startPurse = startPurse
        self.finalCrawford = finalCrawford
    }
}

/// A circuit region (Appendix A.3: `RegionDef`).
public struct RegionDef: Sendable, Codable, Equatable {
    public let id: String
    public let name: String
    /// Tavern ids in circuit order (referential: ⊆ taverns.json ids).
    public let taverns: [String]
    /// Ruleset ids the region unlocks (R-15: the Tablet unlocks in region 2).
    public let unlocks: [String]

    public init(id: String, name: String, taverns: [String], unlocks: [String]) {
        self.id = id
        self.name = name
        self.taverns = taverns
        self.unlocks = unlocks
    }
}

// MARK: - TutorialLessonDef

/// A tutorial lesson definition (loaded from content).
public struct TutorialLessonDef: Sendable, Codable, Equatable {
    public let id: String
    public let title: String
    public let steps: [String]
    public let rulesetId: String
    public let isFirst: Bool
    public let label: HistoryLabel?

    public init(
        id: String,
        title: String,
        steps: [String],
        rulesetId: String,
        isFirst: Bool,
        label: HistoryLabel? = nil
    ) {
        self.id = id
        self.title = title
        self.steps = steps
        self.rulesetId = rulesetId
        self.isFirst = isFirst
        self.label = label
    }
}

// MARK: - BalanceDef

/// Balance data (roadmap §6: the cube max lives in balance.json).
public struct BalanceDef: Sendable, Codable, Equatable {
    public let cubeMax: Int

    public init(cubeMax: Int) {
        self.cubeMax = cubeMax
    }
}
