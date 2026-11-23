// Supply.swift — per-player stone supplies (R-2, INV-3).

/// Per-player stone supply counts. INV-3 (supplies never go negative) is
/// enforced structurally: placement decrements only after an availability
/// check, and `use` traps on an empty bin rather than going negative.
public struct Supply: Codable, Hashable, Sendable {
    public var large: Int
    public var medium: Int
    public var small: Int

    public init(large: Int, medium: Int, small: Int) {
        self.large = large
        self.medium = medium
        self.small = small
    }

    public static func standard() -> Supply {
        Supply(large: 2, medium: 3, small: 4)
    }

    /// Remaining stones of a size.
    public func count(_ size: StoneSize) -> Int {
        switch size {
        case .large: return large
        case .medium: return medium
        case .small: return small
        }
    }

    /// True when at least one stone of the size remains.
    public func has(_ size: StoneSize) -> Bool {
        count(size) > 0
    }

    /// Consumes one stone of the size. Call only after `has(_:)` — a
    /// negative bin is a programming error, not a game state (INV-3).
    public mutating func use(_ size: StoneSize) {
        switch size {
        case .large:
            precondition(large > 0, "INV-3: large bin empty")
            large -= 1
        case .medium:
            precondition(medium > 0, "INV-3: medium bin empty")
            medium -= 1
        case .small:
            precondition(small > 0, "INV-3: small bin empty")
            small -= 1
        }
    }

    /// True when every bin is empty.
    public var isSpent: Bool {
        large == 0 && medium == 0 && small == 0
    }
}
