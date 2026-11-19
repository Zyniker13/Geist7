// MARK: - MacPieceKey

/// RS-P7.2b: Mac number-key navigation. Rosette has at most 7 pieces per
/// side; number keys 1–7 pick the corresponding piece's move, in the same
/// order the moves are listed elsewhere in the UI.
public enum MacPieceKey {
    /// The number keys that can select a piece (1–7).
    public static let validKeys = 1...7

    /// The 0-based index into the legal-move list that number key `n`
    /// selects, or nil when `n` is not a piece key or selects past the end
    /// of the list.
    public static func moveIndex(forNumberKey n: Int, legalMoveCount: Int) -> Int? {
        guard validKeys.contains(n), n <= legalMoveCount else { return nil }
        return n - 1
    }
}
