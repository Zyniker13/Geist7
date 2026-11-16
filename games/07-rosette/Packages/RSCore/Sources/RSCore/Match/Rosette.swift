// MARK: - Rosette

/// Rosette logic (R-6, R-20).
public enum Rosette {
    /// Check if a square is a rosette.
    public static func isRosette(at position: Int, track: Track) -> Bool {
        track.rosetteIndices.contains(position)
    }

    /// Check if a rosette is safe (captures not allowed there).
    public static func isSafe(at position: Int, track: Track) -> Bool {
        track.safeRosetteIndices.contains(position)
    }
}
