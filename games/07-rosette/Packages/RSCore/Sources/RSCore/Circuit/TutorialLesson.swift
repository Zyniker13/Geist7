// MARK: - TutorialLesson

/// A tutorial lesson for new players.
public struct TutorialLesson: Sendable, Equatable {
    /// Unique identifier.
    public let id: String
    /// Display title.
    public let title: String
    /// Step-by-step instructions.
    public let steps: [String]
    /// Which ruleset to use.
    public let rulesetId: String
    /// Whether this is the first lesson.
    public let isFirst: Bool
    /// History label (if applicable).
    public let label: HistoryLabel?

    /// Create from a definition.
    public init(def: TutorialLessonDef) {
        self.id = def.id
        self.title = def.title
        self.steps = def.steps
        self.rulesetId = def.rulesetId
        self.isFirst = def.isFirst
        self.label = def.label
    }

    /// Create directly (for hardcoded lessons).
    public init(
        id: String,
        title: String,
        steps: [String],
        rulesetId: String,
        isFirst: Bool,
        label: HistoryLabel?
    ) {
        self.id = id
        self.title = title
        self.steps = steps
        self.rulesetId = rulesetId
        self.isFirst = isFirst
        self.label = label
    }

    /// The first tutorial lesson (moving pieces).
    public static func firstLesson() -> TutorialLesson {
        TutorialLesson(
            id: "tutorial_move",
            title: "Moving Your Pieces",
            steps: [
                "Roll the dice by tapping the dice cup.",
                "Tap a piece to select it — its legal destinations will highlight in green.",
                "Tap a highlighted square to move your piece there.",
                "If you have multiple pieces that can move, choose which one to move.",
                "You must use the full roll value — if no piece can use it, the turn passes.",
            ],
            rulesetId: "finkel",
            isFirst: true,
            label: HistoryLabel.reconstructed
        )
    }
}
