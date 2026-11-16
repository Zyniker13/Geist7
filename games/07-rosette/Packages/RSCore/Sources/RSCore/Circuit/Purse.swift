// MARK: - Purse

/// The player's purse (virtual currency for the circuit).
struct Purse: Sendable, Equatable {
    /// Current balance.
    var balance: Int
    /// Total earned this circuit.
    var totalEarned: Int

    /// Create a new purse.
    static func newPurse() -> Purse {
        Purse(balance: 0, totalEarned: 0)
    }

    /// Add earnings. The balance never goes negative (INV-3).
    mutating func add(_ amount: Int) {
        balance = max(0, balance + amount)
        totalEarned += max(0, amount)
    }

    /// Pay a stake.
    mutating func pay(_ amount: Int) -> Bool {
        guard balance >= amount else { return false }
        balance -= amount
        return true
    }

    /// Check if the purse is empty.
    var isEmpty: Bool { balance <= 0 }
}
