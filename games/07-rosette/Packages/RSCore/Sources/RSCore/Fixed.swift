import Foundation

/// A fixed-point number for deterministic board-state storage.
///
/// Stores `value / 10^scale`.  All game-state fields that must survive
/// save/load and replay verbatim use `Fixed` instead of `Double`.
public struct Fixed: Equatable, Hashable, Sendable {
    public let value: Int64
    public let scale: Int

    public init(_ value: Int64, scale: Int) {
        self.value = value
        self.scale = scale
    }

    public init(_ value: Int, scale: Int) {
        self.value = Int64(value) * Int64(pow(10.0, Double(scale)))
        self.scale = scale
    }

    public init(_ value: Double, scale: Int) {
        self.value = Int64(round(value * pow(10.0, Double(scale))))
        self.scale = scale
    }

    /// Convert back to Double for display.
    public var doubleValue: Double {
        Double(value) / pow(10.0, Double(scale))
    }

    public static func == (lhs: Fixed, rhs: Fixed) -> Bool {
        guard lhs.scale == rhs.scale else { return false }
        return lhs.value == rhs.value
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
        hasher.combine(scale)
    }
}
