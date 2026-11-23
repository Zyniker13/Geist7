// Event.swift — the reducer's outputs (A.3 `Event`; render and audio
// subscribe to these and never infer rules, _CONVENTIONS §4.2.6).

/// What happened when an action was applied. `placed`, `raked`,
/// `passed`, and `resigned` accompany a successful action; `gameOver`
/// closes a match (R-15).
public enum Event: Codable, Hashable, Sendable {
    case placed(Stone)
    case raked(RakeLine)
    case passed(player: PlayerID)
    case resigned(player: PlayerID)
    case gameOver(winner: PlayerID?, scores: [PlayerID: Int])
}
