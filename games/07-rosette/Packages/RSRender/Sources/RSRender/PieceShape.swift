// RSRender — Piece shapes for color-blind accessibility (RS-P8.1)

import CoreGraphics
import RSCore

/// Piece shapes distinguish the two players by geometry as well as color
/// (RS-P8.1: color-blind accessibility). Player 0 uses circles; player 1
/// uses diamonds.
public enum PieceShape: Equatable, Sendable {
    case circle
    case diamond

    /// The shape for a player's pieces.
    public static func forOwner(_ owner: PlayerID) -> PieceShape {
        switch owner {
        case .player0: return .circle
        case .player1: return .diamond
        }
    }

    /// A path centered at the origin, `radius` from center to edge.
    public func cgPath(radius: CGFloat) -> CGPath {
        switch self {
        case .circle:
            return CGPath(
                ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2),
                transform: nil)
        case .diamond:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: radius))
            path.addLine(to: CGPoint(x: radius, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -radius))
            path.addLine(to: CGPoint(x: -radius, y: 0))
            path.closeSubpath()
            return path
        }
    }
}
