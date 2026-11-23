// StoneSize.swift — the three stone sizes (R-2, R-9).

/// Stone sizes. Supplies are 2 large, 3 medium, 4 small per player (R-2);
/// each size carries its own influence curve (R-9).
public enum StoneSize: String, Codable, Hashable, Sendable, CaseIterable {
    case small
    case medium
    case large
}
