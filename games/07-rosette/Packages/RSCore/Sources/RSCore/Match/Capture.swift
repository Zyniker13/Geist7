// MARK: - CaptureResult

/// Result of a capture check.
public enum CaptureResult: Sendable, Equatable {
    /// No capture; the landing square is clear or held by the mover's own piece.
    case none
    /// A capture occurred; the captured piece ID.
    case captured(PieceID)
    /// The square is a safe rosette; capturing there is illegal (R-5).
    case safeRosette
}

// MARK: - Capture

/// Handles capture logic (R-5, R-20).
public enum Capture {
    /// Check whether landing on the target square captures the piece there.
    ///
    /// - Parameter unsafeRosettesActive: true when the safety omen is active
    ///   this turn, making safe rosettes capturable (R-23).
    public static func check(
        landingOn targetPos: Int,
        targetPiece: Piece?,
        track: Track,
        rules: RuleSet,
        unsafeRosettesActive: Bool = false
    ) -> CaptureResult {
        switch rules.captureRule {
        case .none:
            return .none
        case .standard:
            guard let targetPiece else { return .none }
            // The square is a safe rosette: the capture is illegal (the move
            // itself is rejected) unless the omen lifts safety this turn.
            if !unsafeRosettesActive && track.safeRosetteIndices.contains(targetPos) {
                return .safeRosette
            }
            return .captured(targetPiece.id)
        }
    }
}
