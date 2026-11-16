// MARK: - Track

/// The full board track for a ruleset: 14 path positions per player
/// (R-1: 4 private, 8 shared, 2 private, then off).
public struct Track: Sendable, Equatable {
    /// Number of squares along the path.
    public let length: Int
    /// The squares in order.
    public let squares: [Square]
    /// Indices of rosette squares.
    public let rosetteIndices: [Int]
    /// Indices of safe rosettes (captures not allowed there, R-5).
    public let safeRosetteIndices: [Int]

    public init(length: Int, rosetteIndices: [Int], safeRosetteIndices: [Int]) {
        self.length = length
        self.rosetteIndices = rosetteIndices
        self.safeRosetteIndices = safeRosetteIndices
        self.squares = (0..<length).map { idx in
            let isRosette = rosetteIndices.contains(idx)
            let isSafe = safeRosetteIndices.contains(idx)
            let owner: SquareOwner
            if idx < 4 {
                owner = .startPrivate
            } else if idx < 12 {
                owner = .shared
            } else {
                owner = .exitPrivate
            }
            return Square(index: idx, isRosette: isRosette, isSafeRosette: isSafe, owner: owner)
        }
    }
}
