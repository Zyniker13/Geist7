// Influence.swift — per-cell influence accumulation and ownership (R-9–R-11,
// R-24, INV-2's from-scratch reference path).
//
// Influence is integer and additive per player: stones radiate
// size-dependent values (R-9), rake lines carry the anchor stone's
// distance-1 value along and beside the line undiminished (R-10),
// and viewing-face bonuses add +1 at distances 1–2 along the facing
// ray toward the veranda (R-12). The owner of a cell is the player
// with strictly greater influence; ties are unowned (R-11).

/// Which edge of the courtyard is the veranda (R-3, R-12). "bottom"
/// (maximal r) is the only edge P1 content uses.
public enum VerandaEdge: String, Codable, Hashable, Sendable {
    case bottom
    case top
    case left
    case right

    /// The three directions that "point toward" this edge (R-12's
    /// parenthetical), indexed in Hex's 0–5 clockwise-from-east list.
    /// Bottom (maximal r): SE (1), SW (2), W (3).
    /// Top (minimal r): E (0), NW (4), NE (5).
    /// Left (minimal q): W (3), SW (2), NW (4).
    /// Right (maximal q): E (0), SE (1), NE (5).
    public var facingDirections: [Int] {
        switch self {
        case .bottom: return [1, 2, 3]
        case .top: return [0, 4, 5]
        case .left: return [2, 3, 4]
        case .right: return [0, 1, 5]
        }
    }
}

/// A cell's influence tally per player.
public struct InfluenceTally: Hashable, Sendable {
    public var one: Int
    public var two: Int

    public init(one: Int = 0, two: Int = 0) {
        self.one = one
        self.two = two
    }

    public mutating func add(_ player: PlayerID, _ amount: Int) {
        switch player {
        case .one: one += amount
        case .two: two += amount
        }
    }

    public func value(for player: PlayerID) -> Int {
        player == .one ? one : two
    }

    /// R-11: strictly greater total influence owns the cell.
    public var owner: PlayerID? {
        if one > two { return .one }
        if two > one { return .two }
        return nil
    }

    /// R-11 margin: how far ahead the stronger side is (0 on ties).
    public var margin: Int {
        max(one, two) - min(one, two)
    }

    /// The stronger side's influence at this cell.
    public var leading: Int {
        max(one, two)
    }
}

/// Tunable balance parameters (roadmap §6, schema A.3). P1 ships the
/// defaults; DGContent loads content overrides in P3.
public struct Balance: Hashable, Sendable {
    public var supply: [StoneSize: Int]
    public var influence: [StoneSize: [Int]]
    public var rakesPerPlayer: Int
    public var groupBonus: [Int]
    public var viewingFaceBonus: Int
    public var symmetryMinStones: Int
    public var rakeMaxLength: Int

    public init(
        supply: [StoneSize: Int] = [.large: 2, .medium: 3, .small: 4],
        influence: [StoneSize: [Int]] = [
            .large: [6, 5, 4, 3, 2, 1],
            .medium: [4, 3, 2, 1],
            .small: [3, 2, 1],
        ],
        rakesPerPlayer: Int = 6,
        groupBonus: [Int] = [0, 0, 0, 4, 0, 9, 0, 15],
        viewingFaceBonus: Int = 1,
        symmetryMinStones: Int = 4,
        rakeMaxLength: Int = 5
    ) {
        self.supply = supply
        self.influence = influence
        self.rakesPerPlayer = rakesPerPlayer
        self.groupBonus = groupBonus
        self.viewingFaceBonus = viewingFaceBonus
        self.symmetryMinStones = symmetryMinStones
        self.rakeMaxLength = rakeMaxLength
    }

    /// The roadmap's default balance row (A.3 sample).
    public static func standard() -> Balance {
        Balance()
    }

    /// R-9 curve for a size, from the loaded table.
    public func curve(for size: StoneSize) -> [Int] {
        influence[size] ?? size.defaultCurve
    }

    /// R-13 group bonus for a group size (0 outside the table's range).
    public func groupBonusFor(size: Int) -> Int {
        guard size >= 0, size < groupBonus.count else { return 0 }
        return groupBonus[size]
    }
}

extension StoneSize {
    /// R-9 influence curves indexed by hex distance.
    /// Large: 6, 5, 4, 3, 2, 1 for d = 0…5; medium: 4, 3, 2, 1;
    /// small: 3, 2, 1.
    public var defaultCurve: [Int] {
        switch self {
        case .large: return [6, 5, 4, 3, 2, 1]
        case .medium: return [4, 3, 2, 1]
        case .small: return [3, 2, 1]
        }
    }
}

/// From-scratch influence computation (the INV-2 reference path) plus
/// the shared R-12 helpers both the from-scratch and incremental
/// engines use, so the two paths cannot drift.
public enum InfluenceEngine {

    /// R-12: viewing stones are large or medium.
    public static func isViewingStone(_ stone: Stone) -> Bool {
        stone.size == .large || stone.size == .medium
    }

    /// R-25: the view is clear when no opponent stone stands between
    /// the stone and the veranda on the facing ray within distance 3.
    public static func viewIsClear(_ stone: Stone, stones: [Stone]) -> Bool {
        let direction = Hex.directionVectors[stone.facing]
        var probe = stone.cell
        for _ in 0..<3 {
            probe = probe + direction
            for other in stones where other.cell == probe {
                if other.owner == stone.owner.opponent {
                    return false
                }
            }
        }
        return true
    }

    /// The R-12/R-25 bonus amount a stone earns in the given position
    /// context (0 when the stone is small, the bonus is off, the facing
    /// is not veranda-ward, or the view is blocked).
    public static func viewingBonus(
        for stone: Stone, stones: [Stone], balance: Balance
    ) -> Int {
        guard isViewingStone(stone), balance.viewingFaceBonus > 0 else { return 0 }
        guard viewIsClear(stone, stones: stones) else { return 0 }
        return balance.viewingFaceBonus
    }

    /// The cells a stone's viewing bonus covers: distances 1–2 along
    /// the facing ray (R-12), regardless of whether they lie in the
    /// courtyard (callers filter membership).
    public static func viewingBonusCells(for stone: Stone) -> [Hex] {
        let direction = Hex.directionVectors[stone.facing]
        return [stone.cell + direction, stone.cell + direction * 2]
    }

    /// Adds one stone's influence to the tallies. `curve` is the size's
    /// R-9 curve; `bonus` the stone's R-12 amount (0 when none); cells
    /// beyond the curve's range receive nothing.
    public static func applyStone(
        _ stone: Stone, cells: [Hex], curve: [Int], bonus: Int,
        into tallies: inout [Hex: InfluenceTally]
    ) {
        for cell in cells {
            let d = stone.cell.distance(to: cell)
            guard d < curve.count else { continue }
            var amount = curve[d]
            // R-12: bonus at distances 1–2 on the facing ray.
            if bonus > 0, d >= 1, d <= 2, isOnFacingRay(from: stone, to: cell) {
                amount += bonus
            }
            tallies[cell, default: InfluenceTally()].add(stone.owner, amount)
        }
    }

    /// True when `target` lies on `stone`'s facing ray within three
    /// steps (the ray starts after the stone's own cell).
    public static func isOnFacingRay(from stone: Stone, to target: Hex) -> Bool {
        let direction = Hex.directionVectors[stone.facing]
        var probe = stone.cell
        for _ in 0..<3 {
            probe = probe + direction
            if probe == target { return true }
        }
        return false
    }

    /// Adds one rake line's influence (R-10): every cell of the line
    /// and each courtyard cell adjacent to the line receives the anchor
    /// stone's distance-1 influence value, undiminished along the
    /// length. On a crossing cell both rakes' bonuses land, each to its
    /// own owner (R-21); the rake's owner still gets theirs here.
    public static func applyRake(
        _ rake: RakeLine, anchorValue: Int, courtyard: Courtyard,
        into tallies: inout [Hex: InfluenceTally]
    ) {
        guard anchorValue > 0 else { return }
        let inSet = courtyard.cellSet
        var covered = Set<Hex>()
        for lineCell in rake.cells {
            covered.insert(lineCell)
            for d in 0..<6 {
                let neighbor = lineCell.neighbor(d)
                if inSet.contains(neighbor) {
                    covered.insert(neighbor)
                }
            }
        }
        for cell in covered {
            tallies[cell, default: InfluenceTally()].add(rake.owner, anchorValue)
        }
    }

    /// Full recomputation of every courtyard cell's influence tally
    /// (the INV-2 reference path). Every courtyard cell appears in the
    /// result (features included; they can be owned, R-24).
    public static func computeAll(
        courtyard: Courtyard, stones: [Stone], rakes: [RakeLine],
        balance: Balance
    ) -> [Hex: InfluenceTally] {
        var tallies: [Hex: InfluenceTally] = [:]

        for stone in stones {
            let bonus = viewingBonus(for: stone, stones: stones, balance: balance)
            applyStone(
                stone, cells: courtyard.cells,
                curve: balance.curve(for: stone.size), bonus: bonus,
                into: &tallies)
        }

        for rake in rakes {
            // R-22: the rake lives only while its anchor stone stands.
            guard let anchor = stones.first(where: { $0.cell == rake.anchor })
            else { continue }
            applyRake(
                rake, anchorValue: balance.curve(for: anchor.size)[1],
                courtyard: courtyard, into: &tallies)
        }

        return tallies
    }
}

extension Hex {
    /// Repeats this vector `n` times (ray walking).
    public static func * (vector: Hex, n: Int) -> Hex {
        Hex(vector.q * n, vector.r * n)
    }
}
