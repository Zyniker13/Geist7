// MARK: - Square

/// A single square on the board track. Indices are path positions: both
/// players' paths run over the same 14 index slots (4 private start squares,
/// 8 shared squares, 2 private exit squares); a player's private squares can
/// never hold an opponent's piece.
public struct Square: Sendable, Equatable, Hashable {
    /// The square's index along the track (0-based path position).
    public let index: Int
    /// Whether this square is a rosette.
    public let isRosette: Bool
    /// Whether this rosette is safe (captures not allowed there).
    public let isSafeRosette: Bool
    /// Which run the square belongs to.
    public let owner: SquareOwner

    public init(index: Int, isRosette: Bool, isSafeRosette: Bool, owner: SquareOwner) {
        self.index = index
        self.isRosette = isRosette
        self.isSafeRosette = isSafeRosette
        self.owner = owner
    }
}

// MARK: - SquareOwner

/// What kind of run a square belongs to.
public enum SquareOwner: Sendable, Equatable, Hashable {
    /// One of the first four squares of a player's path (private start run).
    case startPrivate
    /// One of the eight middle squares shared by both players.
    case shared
    /// One of the last two squares of a player's path (private exit run).
    case exitPrivate
}
