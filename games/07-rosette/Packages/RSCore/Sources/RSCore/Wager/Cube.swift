// MARK: - DoublingCube

/// The doubling cube state (R-10).
public struct DoublingCube: Sendable, Equatable {
    /// Current cube value (1, 2, 4, 8, ..., 64).
    public let value: Int
    /// Which player owns the cube (-1 = centred, 0/1 = player index).
    public let owner: Int

    public init(value: Int, owner: Int) {
        self.value = value
        self.owner = owner
    }

    /// Create a centred cube.
    public static let centered = DoublingCube(value: 1, owner: -1)

    /// Validate a double offer without applying it (R-10: the owner — or
    /// anyone, if the cube is centred — may offer; the value may not pass
    /// `maxCube`). The stake and cube change only when the offer is accepted.
    public func validateOffer(by player: PlayerID, maxCube: Int) -> CubeError? {
        guard owner == -1 || owner == player.rawValue else { return .notOwner }
        guard value * 2 <= maxCube else { return .maxExceeded }
        return nil
    }

    /// Cube failures.
    public enum CubeError: Error, Sendable, Equatable {
        case notOwner
        case maxExceeded
    }
}
