// MARK: - Stake

/// The current match stake (R-9).
public struct Stake: Sendable, Equatable {
    /// The current stake value.
    public let value: Int

    public init(value: Int) {
        self.value = value
    }

    /// Double the stake (R-10, applied when an offer is accepted).
    public func double() -> Stake {
        Stake(value: value * 2)
    }
}
