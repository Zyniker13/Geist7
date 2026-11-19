// MARK: - CircuitState

/// State of a tavern-circuit run (R-13, R-14).
///
/// The run walks the taverns in content order. Entering a tavern costs its
/// buy-in; each match is played at a stake no lower than the tavern's
/// minimum and never above the purse (R-9). A win advances to the next
/// tavern; a loss leaves the player there to re-challenge (buying in
/// again). When the purse drops below the cheapest still-ahead entry cost
/// — a tavern's buy-in plus one match at its minimum stake — the run ends
/// (R-13): sitting down without being able to stake a legal match would
/// softlock. Between matches the player may buy omens (R-14, up to two
/// held, R-12) or pay an opponent's tell cost to learn its cube thresholds
/// (R-24).
public struct CircuitState: Sendable, Equatable, Codable {
    /// The taverns in circuit order (from circuit.json + taverns.json).
    public let taverns: [Tavern]
    /// R-22: the Crawford rule applies in circuit finals.
    public let finalCrawford: Bool

    /// Index into `taverns` of the tavern currently being played.
    public private(set) var tavernIndex: Int
    /// The player's purse (INV-3: never negative).
    public private(set) var purse: Purse
    /// Omens held (R-12: at most two).
    public private(set) var heldOmens: [String]
    /// Opponents whose tells the player has learned (R-14/R-24).
    public private(set) var learnedTells: Set<String>
    /// Matches played in this run.
    public private(set) var totalGames: Int
    /// Matches won in this run.
    public private(set) var totalWins: Int
    /// Net stake flow over the run (RS-P2.3: the ledger reconciles the purse).
    public private(set) var stakeLedger: Int

    /// Build a run from content.
    public init(taverns: [Tavern], startPurse: Int, finalCrawford: Bool) {
        self.taverns = taverns
        self.finalCrawford = finalCrawford
        self.tavernIndex = 0
        self.purse = Purse(startingBalance: startPurse)
        self.heldOmens = []
        self.learnedTells = []
        self.totalGames = 0
        self.totalWins = 0
        self.stakeLedger = 0
    }

    // MARK: - Position

    /// The tavern currently being played, or nil once the run is over.
    public var currentTavern: Tavern? {
        tavernIndex < taverns.count ? taverns[tavernIndex] : nil
    }

    /// Taverns fully played.
    public var tavernsCompleted: Int {
        min(tavernIndex, taverns.count)
    }

    /// The final tavern has been played through.
    public var isComplete: Bool {
        tavernIndex >= taverns.count
    }

    /// The cheapest entry cost among the taverns still ahead, if any: the
    /// buy-in plus one match at the minimum stake (you must be able to sit
    /// down AND play; a stake-0 match would violate R-9's minimum).
    public var cheapestRemainingEntry: Int? {
        guard tavernIndex < taverns.count else { return nil }
        return taverns[tavernIndex...].map { $0.buyIn + $0.minStake }.min()
    }

    /// R-13: the purse cannot afford to enter and play any remaining
    /// tavern, so the run ends. A completed run is not "broken".
    public var isRunEnded: Bool {
        guard !isComplete, let cheapest = cheapestRemainingEntry else { return false }
        return purse.balance < cheapest
    }

    /// The run is over: completed, or ended by the purse.
    public var isOver: Bool {
        isComplete || isRunEnded
    }

    /// Whether a match at `stake` is affordable (R-9: stake never above purse).
    public func canAffordStake(_ stake: Int) -> Bool {
        purse.balance >= stake
    }

    /// The stake to play at: the tavern's minimum, clamped to the purse.
    public func stake(for tavern: Tavern) -> Int {
        min(tavern.minStake, purse.balance)
    }

    // MARK: - Transitions

    /// Pay the current tavern's buy-in to sit down (R-13).
    @discardableResult
    public mutating func payBuyIn() -> Bool {
        guard let tavern = currentTavern, purse.balance >= tavern.buyIn else { return false }
        purse.pay(tavern.buyIn)
        return true
    }

    /// Record a finished match (R-11 gammon doubling applies when the
    /// tavern's gammon rule is on and the loser bore off nothing). A loss
    /// never drives the purse negative (INV-3): the player pays what they
    /// have when the doubled amount exceeds it.
    public mutating func recordResult(won: Bool, stake: Int, gammon: Bool = false) {
        let tavern = currentTavern
        let gammonApplies = gammon && (tavern?.gammonRule ?? false)
        let amount = gammonApplies ? stake * 2 : stake
        totalGames += 1
        if won {
            totalWins += 1
            purse.add(amount)
            stakeLedger += amount
        } else {
            let paid = purse.payUpTo(amount)
            stakeLedger -= paid
        }
    }

    /// R-14: buy an omen (R-12: at most two held).
    @discardableResult
    public mutating func buyOmen(_ def: OmenDef) -> Bool {
        guard heldOmens.count < 2, purse.balance >= def.cost else { return false }
        purse.pay(def.cost)
        heldOmens.append(def.id)
        return true
    }

    /// R-14/R-24: pay to learn an opponent's tell.
    @discardableResult
    public mutating func learnTell(_ def: OpponentDef) -> Bool {
        guard !learnedTells.contains(def.id), purse.balance >= def.tellCost else { return false }
        purse.pay(def.tellCost)
        learnedTells.insert(def.id)
        return true
    }

    /// Advance past the current tavern (after winning there).
    @discardableResult
    public mutating func advanceTavern() -> Bool {
        guard tavernIndex < taverns.count else { return false }
        tavernIndex += 1
        return true
    }
}
