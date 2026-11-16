// MARK: - HistoryLabel

/// Labels a game element's provenance.
public enum HistoryLabel: String, Sendable, Codable {
    /// Directly attested by historical sources.
    case attested
    /// Filled in from modern scholarship/reconstruction.
    case reconstructed
    /// Invented for the game.
    case invented
}

// MARK: - CaptureRule

/// How captures work on this ruleset.
public enum CaptureRule: String, Sendable, Codable {
    /// Landing on an opponent sends them home; rosettes may be safe.
    case standard
    /// No captures (e.g., some Senet variants).
    case none
}

// MARK: - RuleSet

/// A complete ruleset definition.
public struct RuleSet: Sendable, Equatable, Codable {
    /// Unique identifier.
    public let id: String
    /// Human-readable label.
    public let label: String
    /// Board track length.
    public let trackLength: Int
    /// Pieces per player.
    public let pieces: Int
    /// Indices of rosette squares.
    public let rosettes: [Int]
    /// Indices of safe rosettes.
    public let safeRosettes: [Int]
    /// Dice model identifier.
    public let diceModel: String
    /// Bearing off requires exact roll.
    public let exactBearOff: Bool
    /// Landing on a rosette grants an extra roll.
    public let extraRollOnRosette: Bool
    /// Capture rule type.
    public let captureRule: CaptureRule
    /// Which move generator implements this ruleset (e.g. "ur").
    public let moveGenerator: String
    /// Source citation.
    public let source: String
    /// History label for the ruleset as a whole.
    public let historyLabel: HistoryLabel

    public init(
        id: String,
        label: String,
        trackLength: Int,
        pieces: Int,
        rosettes: [Int],
        safeRosettes: [Int],
        diceModel: String,
        exactBearOff: Bool,
        extraRollOnRosette: Bool,
        captureRule: CaptureRule,
        moveGenerator: String = "ur",
        source: String,
        historyLabel: HistoryLabel
    ) {
        self.id = id
        self.label = label
        self.trackLength = trackLength
        self.pieces = pieces
        self.rosettes = rosettes
        self.safeRosettes = safeRosettes
        self.diceModel = diceModel
        self.exactBearOff = exactBearOff
        self.extraRollOnRosette = extraRollOnRosette
        self.captureRule = captureRule
        self.moveGenerator = moveGenerator
        self.source = source
        self.historyLabel = historyLabel
    }

    /// Build the board track for this ruleset.
    public func makeTrack() -> Track {
        Track(length: trackLength, rosetteIndices: rosettes, safeRosetteIndices: safeRosettes)
    }
}
