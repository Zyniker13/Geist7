// MARK: - Purse

/// The player's purse (R-13): the money carried through a circuit run.
/// INV-3: the balance never goes negative.
public struct Purse: Sendable, Equatable {
    /// Current balance.
    public var balance: Int
    /// Total earned this circuit.
    public var totalEarned: Int

    /// Create an empty purse (test fixtures; runs start from content).
    public init() {
        self.balance = 0
        self.totalEarned = 0
    }

    /// Create a purse starting at `balance` (circuit.json's start purse).
    public init(startingBalance: Int) {
        self.balance = max(0, startingBalance)
        self.totalEarned = 0
    }

    /// Add earnings. The balance never goes negative (INV-3).
    public mutating func add(_ amount: Int) {
        balance = max(0, balance + amount)
        totalEarned += max(0, amount)
    }

    /// Pay an amount only when affordable; reports success.
    @discardableResult
    public mutating func pay(_ amount: Int) -> Bool {
        guard balance >= amount else { return false }
        balance -= amount
        return true
    }

    /// Pay up to `amount` (a gammon loss may exceed the purse); returns the
    /// amount actually paid. Never drives the balance negative (INV-3).
    @discardableResult
    public mutating func payUpTo(_ amount: Int) -> Int {
        let paid = min(max(0, amount), balance)
        balance -= paid
        return paid
    }

    /// Check if the purse is empty.
    public var isEmpty: Bool { balance <= 0 }
}
