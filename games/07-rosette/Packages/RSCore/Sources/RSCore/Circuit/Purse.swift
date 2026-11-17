// MARK: - Purse

/// The player's purse (virtual currency for the circuit).
public struct Purse: Sendable, Equatable {
    /// Current balance.
    public var balance: Int
    /// Total earned this circuit.
    public var totalEarned: Int

    /// Create a new purse.
    public init() {
        self.balance = 0
        self.totalEarned = 0
    }

    /// Create a new purse (static convenience).
    public static func newPurse() -> Purse {
        Purse()
    }

    /// Add earnings. The balance never goes negative (INV-3).
    public mutating func add(_ amount: Int) {
        balance = max(0, balance + amount)
        totalEarned += max(0, amount)
    }

    /// Pay a stake.
    public mutating func pay(_ amount: Int) -> Bool {
        guard balance >= amount else { return false }
        balance -= amount
        return true
    }

    /// Check if the purse is empty.
    public var isEmpty: Bool { balance <= 0 }
}
