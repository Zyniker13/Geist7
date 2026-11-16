// MARK: - PieceID

/// Unique identifier for a piece (unique within one owner's set).
public typealias PieceID = Int

// MARK: - Piece

/// A single game piece.
public struct Piece: Sendable, Equatable, Hashable, Codable {
    /// The piece's unique ID (0 to pieces-1).
    public let id: PieceID
    /// Which player owns this piece.
    public let owner: PlayerID
    /// Current position: -1 = off-board (waiting to enter), 0..trackLength-1 = on board, -2 = borne off.
    public var position: Int

    /// Create a piece in its starting position (off-board).
    public static func making(id: PieceID, owner: PlayerID) -> Piece {
        Piece(id: id, owner: owner, position: -1)
    }

    /// Check if the piece is on the board.
    public var isOnBoard: Bool { position >= 0 && position < Int.max }

    /// Check if the piece has been borne off.
    public var isBorneOff: Bool { position == -2 }
}

// MARK: - PlayerID

/// Player identifier.
public enum PlayerID: Int, Sendable, Codable, CaseIterable {
    /// First player (white).
    case player0 = 0
    /// Second player (black).
    case player1 = 1
}
