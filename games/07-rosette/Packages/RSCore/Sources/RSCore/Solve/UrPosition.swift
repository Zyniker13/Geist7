import Foundation

/// The solver's packed position key for the Finkel-style race layout.
///
/// The layout is the per-owner path index space of ADR-0003: each player
/// walks 14 steps made of 4 private start squares (steps 0–3), 8 shared
/// squares (steps 4–11), and 2 private exit squares (steps 12–13). The
/// solver tracks:
///
/// - `shared`: base-4 packed occupancy for steps 4–11 — two bits per
///   square (0 empty, 1 first player, 2 second player), packed as
///   `Σ digit(i) · 4^i` in a 16-bit field. Digit 3 is impossible and
///   rejected at construction; the base-3 *value* space (3⁸ = 6561) is
///   never used for packing, only inside the ranking's dense tables.
/// - `private0` / `private1`: bitmaps over each player's six private
///   squares in step order 0, 1, 2, 3, 12, 13 (bit i set = own piece).
/// - `hand0` / `hand1`: pieces waiting to enter.
///
/// Borne-off counts follow from piece conservation: `off = pieces − hand −
/// onBoard`, so they are not stored. The player to roll is also not stored:
/// values are kept from the rolling player's perspective (INV-7 style
/// symmetry), which is what the doubling-cube-free solved value needs.
///
/// Bit layout (34 bits): shared 0–15, private0 16–21, private1 22–27,
/// hand0 28–30, hand1 31–33.
public struct UrPosition: Sendable, Equatable, Hashable {

    public let bits: UInt64

    public init(bits: UInt64) {
        self.bits = bits
    }

    public static let bitsForShared = 16
    public static let bitsForPrivate = 6
    public static let bitsForHand = 3

    public var shared: UInt32 { UInt32(bits & 0xFFFF) }
    public var private0: UInt32 { UInt32((bits >> 16) & 0x3F) }
    public var private1: UInt32 { UInt32((bits >> 22) & 0x3F) }
    public var hand0: Int { Int((bits >> 28) & 7) }
    public var hand1: Int { Int((bits >> 31) & 7) }

    public init(
        shared: UInt32,
        private0: UInt32,
        private1: UInt32,
        hand0: Int,
        hand1: Int
    ) {
        precondition(
            shared < 0x1_0000 && UrPosition.isValidShared(shared),
            "invalid shared field"
        )
        precondition(private0 < 0x40 && private1 < 0x40)
        precondition(hand0 >= 0 && hand0 < 8 && hand1 >= 0 && hand1 < 8)
        self.bits =
            UInt64(shared)
            | (UInt64(private0) << 16)
            | (UInt64(private1) << 22)
            | (UInt64(hand0) << 28)
            | (UInt64(hand1) << 31)
    }

    /// A shared field is valid when every 2-bit group is 0, 1 or 2.
    public static func isValidShared(_ shared: UInt32) -> Bool {
        var value = shared
        for _ in 0..<8 {
            if value & 3 == 3 { return false }
            value >>= 2
        }
        return true
    }

    /// `base3ToPacked[s]` is the base-4 packed shared field of the shared
    /// pattern whose base-3 value is `s` (the ranking's table index).
    public static let base3ToPacked: [UInt32] = {
        var table = [UInt32](repeating: 0, count: 6561)
        for s in 0..<6561 {
            var value = s
            var packed: UInt32 = 0
            for square in 0..<8 {
                packed |= UInt32(value % 3) << UInt32(square * 2)
                value /= 3
            }
            table[s] = packed
        }
        return table
    }()

    /// `packedToBase3[packed]` is the ranking's table index for a packed
    /// shared field, or −1 when the field holds an impossible digit 3.
    public static let packedToBase3: [Int] = {
        var table = [Int](repeating: -1, count: 65_536)
        for (index, packed) in base3ToPacked.enumerated() {
            table[Int(packed)] = index
        }
        return table
    }()

    /// Number of first-player pieces standing on the shared squares.
    public var sharedCount0: Int { UrPosition.popcount3(shared, digit: 1) }
    /// Number of second-player pieces standing on the shared squares.
    public var sharedCount1: Int { UrPosition.popcount3(shared, digit: 2) }

    /// Pieces of a player standing on their six private squares.
    public var privateCount0: Int { private0.nonzeroBitCount }
    public var privateCount1: Int { private1.nonzeroBitCount }

    static func popcount3(_ packed: UInt32, digit: UInt32) -> Int {
        var count = 0
        var value = packed
        for _ in 0..<8 {
            if value & 3 == digit { count += 1 }
            value >>= 2
        }
        return count
    }

    /// The occupant digit of shared step `index` (0…7), 0 empty, 1/2 players.
    public func sharedDigit(_ index: Int) -> UInt32 {
        (shared >> UInt32(index * 2)) & 3
    }

    /// Bit for private step order position `index` (0…5 = steps 0,1,2,3,12,13).
    public static func privateBit(_ index: Int) -> UInt32 { 1 << UInt32(index) }

    /// The 14-bit occupancy mask of a player's own pieces across the path:
    /// bits 0–3 from the private bitmap's low bits, bits 4–11 from shared
    /// digits, bits 12–13 from the private bitmap's high bits.
    public func ownMask(player: Int) -> UInt16 {
        let priv = player == 0 ? private0 : private1
        let sharedMask = UrPosition.sharedMask(player: player, shared: shared)
        var mask = UInt16(priv & 0xF)
        mask |= UInt16(sharedMask) << 4
        mask |= UInt16((priv >> 4) & 3) << 12
        return mask
    }

    /// 8-bit mask of shared squares (bit i = step 4+i) held by `player`.
    public static func sharedMask(player: Int, shared: UInt32) -> UInt8 {
        let digit: UInt32 = player == 0 ? 1 : 2
        var mask: UInt8 = 0
        for index in 0..<8 {
            if (shared >> UInt32(index * 2)) & 3 == digit {
                mask |= UInt8(1) << UInt8(index)
            }
        }
        return mask
    }
}
