import Foundation

/// Reads a RoyalUr `.rgu` solved-value file and cross-checks it against
/// this package's own solved values (RS-P1.4 gate evidence, INV-5 support).
///
/// The RGU format (big-endian) is: magic `RGU`, a version byte, an Int32
/// metadata JSON length with the JSON itself, an Int32 map count with an
/// Int32 entry count per map, then per map a sorted UInt32 key buffer and
/// a value buffer whose layout depends on the metadata's `value_type`
/// (`percent16` stores one UInt16 per entry; the win percentage is
/// `raw * 100 / 65535`).
///
/// Keys are the RoyalUr `SimpleGameStateEncoding` light-to-move states:
/// dark safe tiles (6 bits), the compressed shared-lane state, light safe
/// tiles, and the two hand counts. Occupant digits are inverted relative
/// to RSCore's (RoyalUr uses 1 = dark, 2 = light; RSCore uses 1 = the
/// rolling player), and the per-player safe-tile bit order runs opposite
/// to RSCore's private bitmaps on both halves.
public enum UrRguCrossCheck {

    public struct File {
        public var pieces: Int
        public var maps: [(keys: [UInt32], values: [UInt16])]
    }

    public static func read(path: String) throws -> File {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        var offset = 0
        func readBytes(_ count: Int) throws -> [UInt8] {
            guard offset + count <= data.count else {
                throw CrossCheckError.truncated("need \(count) bytes at \(offset)")
            }
            let slice = Array(data[offset..<offset + count])
            offset += count
            return slice
        }
        func readInt32() throws -> Int32 {
            let bytes = try readBytes(4)
            return Int32(bytes[0]) << 24 | Int32(bytes[1]) << 16
                | Int32(bytes[2]) << 8 | Int32(bytes[3])
        }

        let magic = try readBytes(3)
        guard magic == [0x52, 0x47, 0x55] else { throw CrossCheckError.badMagic }
        let version = try readBytes(1)[0]
        guard version == 0 else { throw CrossCheckError.badVersion(version) }

        let metadataLength = Int(try readInt32())
        let metadataBytes = try readBytes(metadataLength)
        let metadata =
            try JSONSerialization.jsonObject(
                with: Data(metadataBytes), options: []
            ) as? [String: Any] ?? [:]
        let settings = metadata["game_settings"] as? [String: Any] ?? [:]
        let startPieces = settings["start_pieces"] as? Int ?? 0
        let valueType = metadata["value_type"] as? String ?? ""
        guard valueType == "percent16" else {
            throw CrossCheckError.unsupportedValueType(valueType)
        }

        let mapCount = Int(try readInt32())
        var entryCounts = [Int]()
        for _ in 0..<mapCount { entryCounts.append(Int(try readInt32())) }

        var maps = [(keys: [UInt32], values: [UInt16])]()
        for index in 0..<mapCount {
            var keys = [UInt32]()
            keys.reserveCapacity(entryCounts[index])
            for _ in 0..<entryCounts[index] {
                let bytes = try readBytes(4)
                keys.append(
                    UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16
                        | UInt32(bytes[2]) << 8 | UInt32(bytes[3]))
            }
            var values = [UInt16]()
            values.reserveCapacity(entryCounts[index])
            for _ in 0..<entryCounts[index] {
                let bytes = try readBytes(2)
                values.append(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
            }
            maps.append((keys, values))
        }
        return File(pieces: startPieces, maps: maps)
    }

    public enum CrossCheckError: Error, CustomStringConvertible {
        case truncated(String)
        case badMagic
        case badVersion(UInt8)
        case unsupportedValueType(String)
        case unknownKey(UInt32)
        case valueOutOfRange(UInt32, UInt16)

        public var description: String {
            switch self {
            case .truncated(let detail): return "rgu file truncated: \(detail)"
            case .badMagic: return "not an RGU file"
            case .badVersion(let v): return "unsupported RGU version \(v)"
            case .unsupportedValueType(let t): return "unsupported value type \(t)"
            case .unknownKey(let key): return "key \(key) not found in table"
            case .valueOutOfRange(let key, let raw):
                return "key \(key) has out-of-range value \(raw)"
            }
        }
    }

    /// The RoyalUr war-lane compression inverted: dense index → raw 16-bit
    /// shared-lane state (the last lane square is the most significant
    /// digit), built in their recursive enumeration order with per-player
    /// piece budgets.
    public static func warCompressionInverse(pieces: Int) -> [Int: UInt32] {
        var table = [Int: UInt32]()
        var nextIndex = 0
        func recurse(lightBudget: Int, darkBudget: Int, state: UInt32, square: Int) {
            guard square >= 0 else {
                table[nextIndex] = state
                nextIndex += 1
                return
            }
            for occupant in 0...2 {
                var light = lightBudget
                var dark = darkBudget
                if occupant == 1 { dark -= 1 }
                if occupant == 2 { light -= 1 }
                if dark < 0 || light < 0 { continue }
                recurse(
                    lightBudget: light, darkBudget: dark,
                    state: (state << 2) | UInt32(occupant), square: square - 1)
            }
        }
        recurse(lightBudget: pieces, darkBudget: pieces, state: 0, square: 7)
        return table
    }

    /// Decodes one RoyalUr key into an RSCore position. RoyalUr occupant
    /// digits are 1 = dark, 2 = light; RSCore's are 1 = rolling player
    /// (light here), 2 = the opponent, so they swap. Safe-tile bits run in
    /// RoyalUr's ascending board-index order, which reverses RSCore's
    /// private bitmap order within both halves.
    public static func position(
        key: UInt32, compression: [Int: UInt32], pieces: Int
    ) throws -> UrPosition {
        let boardBits = 2 * 6 + warSegmentBits(pieces: pieces)
        let darkSafe = key & 0x3F
        let compressed = (key >> 6) & UInt32((1 << warSegmentBits(pieces: pieces)) - 1)
        let lightSafe = (key >> UInt32(6 + warSegmentBits(pieces: pieces))) & 0x3F
        let darkHand = (key >> UInt32(boardBits)) & 7
        let lightHand = (key >> UInt32(boardBits + 3)) & 7

        guard let state = compression[Int(compressed)] else {
            throw CrossCheckError.unknownKey(key)
        }
        // The dense order is lexicographic with the LAST lane square most
        // significant, so square i sits at 2-bit group (7 - i) of the
        // decompressed state.
        var shared: UInt32 = 0
        for index in 0..<8 {
            let occupant = (state >> UInt32((7 - index) * 2)) & 3
            // RoyalUr lane square `index` (y = 0…7) is RSCore shared step 4+index.
            let digit: UInt32 = occupant == 2 ? 1 : (occupant == 1 ? 2 : 0)
            shared |= digit << UInt32(index * 2)
        }

        // Safe-tile bit b is RoyalUr's b-th safe tile in ascending board
        // index order: RSCore steps 3, 2, 1, 0, 13, 12.
        let bitRemap = [3, 2, 1, 0, 5, 4]
        func privateBits(_ safe: UInt32) -> UInt32 {
            var bits: UInt32 = 0
            for b in 0..<6 where safe & (1 << UInt32(b)) != 0 {
                bits |= 1 << UInt32(bitRemap[b])
            }
            return bits
        }

        return UrPosition(
            shared: shared,
            private0: privateBits(lightSafe),
            private1: privateBits(darkSafe),
            hand0: Int(lightHand),
            hand1: Int(darkHand)
        )
    }

    public static func warSegmentBits(pieces: Int) -> Int {
        // RoyalUr: one segment for 8 war tiles; its width covers the largest
        // dense compression index (calculateBitsRequired).
        var count = 0
        var nextIndex = 0
        func recurse(lightBudget: Int, darkBudget: Int, square: Int) {
            guard square >= 0 else {
                nextIndex += 1
                return
            }
            for occupant in 0...2 {
                var light = lightBudget
                var dark = darkBudget
                if occupant == 1 { dark -= 1 }
                if occupant == 2 { light -= 1 }
                if dark < 0 || light < 0 { continue }
                recurse(lightBudget: light, darkBudget: dark, square: square - 1)
            }
        }
        recurse(lightBudget: pieces, darkBudget: pieces, square: 7)
        count = nextIndex
        var bits = 1
        while count - 1 > (1 << bits) { bits += 1 }
        return bits
    }

    /// Cross-checks every RGU entry against `values` in the ranking's dense
    /// order. Returns the worst absolute deviation in win-probability units.
    public static func run(
        rgu: File, values: [Double], ranking: UrRanking, verbose: Bool = false
    ) throws -> (maxDelta: Double, checked: Int, worstKey: UInt32) {
        let compression = warCompressionInverse(pieces: rgu.pieces)
        var worst = [(Double, UInt32, UrPosition, Double, Double)]()
        var maxDelta = 0.0
        var checked = 0
        var worstKey: UInt32 = 0
        for map in rgu.maps {
            for (key, raw) in zip(map.keys, map.values) {
                let theirProbability = Double(raw) / 65535.0
                let position = try position(key: key, compression: compression, pieces: rgu.pieces)
                let index = ranking.index(of: position)
                guard index < values.count else {
                    throw CrossCheckError.unknownKey(key)
                }
                let mine = values[index]
                let delta = abs(mine - theirProbability)
                if delta > maxDelta {
                    maxDelta = delta
                    worstKey = key
                }
                if verbose && delta > 0.01 && worst.count < 8 {
                    worst.append((delta, key, position, mine, theirProbability))
                }
                checked += 1
            }
        }
        if verbose {
            worst.sort { $0.0 > $1.0 }
            for (delta, key, position, mine, theirs) in worst {
                var digits = ""
                for i in 0..<8 { digits += String(position.sharedDigit(i)) }
                print(
                    "    key \(key) Δ=\(delta) shared=\(digits) priv0=\(position.private0) priv1=\(position.private1) h0=\(position.hand0) h1=\(position.hand1) mine=\(mine) theirs=\(theirs)"
                )
            }
        }
        return (maxDelta, checked, worstKey)
    }
}
