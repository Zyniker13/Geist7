import Foundation

/// A solved value table for the Finkel-style race (RS-P1.4).
///
/// File layout (little-endian): magic `G7UR`, format version byte, pieces
/// byte, two reserved bytes, total position count (UInt32), layer count
/// (UInt32), the layer offsets as UInt64 values, the win probabilities as
/// UInt16 in 1/65535 units in the ranking's dense order, and an FNV-1a
/// 64-bit checksum of everything before it.
public struct UrTable: Sendable {

    public let pieces: Int
    public let values: [UInt16]
    public let layerStart: [Int]
    public let ranking: UrRanking

    public var totalPositions: Int { values.count }

    public init(pieces: Int, values: [UInt16], layerStart: [Int]) {
        self.pieces = pieces
        self.values = values
        self.layerStart = layerStart
        self.ranking = UrRanking(pieces: pieces)
    }

    /// Whether a table lookup is defined for `position`: it must belong to
    /// this table's piece count (the stones on the shared track plus the
    /// private run and the hand must sum to the solved count) and map
    /// inside the value array. Queries outside the table's coverage return
    /// false instead of an out-of-range index — the 2-piece fixture must
    /// not be consulted about 7-piece positions.
    public func covers(_ position: UrPosition) -> Bool {
        guard position.hand0 == pieces && position.hand1 == pieces else {
            return false
        }
        guard UrPosition.isValidShared(position.shared) else { return false }
        // `sharedCount0/1` are indexed by the ranking's base-3 pattern, not by
        // the packed field; convert first (a packed mask can exceed the 3^8
        // pattern range whenever any square past the fourth is occupied).
        let base3 = UrPosition.packedToBase3[Int(position.shared)]
        guard base3 >= 0 else { return false }
        guard
            Int(position.private0) + position.hand0
                + ranking.sharedCount0(base3) == pieces,
            Int(position.private1) + position.hand1
                + ranking.sharedCount1(base3) == pieces
        else { return false }
        let index = ranking.index(of: position)
        return index >= 0 && index < values.count
    }

    /// Win probability for the player about to roll from `position`.
    public func winProbability(at position: UrPosition) -> Double {
        Double(values[ranking.index(of: position)]) / 65535.0
    }

    /// Win probability from the initial position for the first player.
    public var initialWinProbability: Double {
        winProbability(
            at: UrPosition(shared: 0, private0: 0, private1: 0, hand0: pieces, hand1: pieces)
        )
    }

    // MARK: File format

    public static let magic: [UInt8] = [0x47, 0x37, 0x55, 0x52]  // "G7UR"
    public static let formatVersion: UInt8 = 1

    public func serialized() -> Data {
        var data = Data()
        data.append(contentsOf: UrTable.magic)
        data.append(UrTable.formatVersion)
        data.append(UInt8(pieces))
        data.append(contentsOf: [0, 0])
        data.appendUInt32LE(UInt32(values.count))
        data.appendUInt32LE(UInt32(layerStart.count - 1))
        for offset in layerStart {
            data.appendUInt64LE(UInt64(offset))
        }
        for value in values {
            data.appendUInt16LE(value)
        }
        let checksum = FNV1a64.bytes(data)
        data.append(contentsOf: checksum)
        return data
    }

    public static func deserialize(_ data: Data) throws -> UrTable {
        var bytes = [UInt8](data)
        guard bytes.count >= 24 else { throw UrTable.UrTableError.truncated }
        guard Array(bytes[0..<4]) == magic else { throw UrTable.UrTableError.badMagic }
        guard bytes[4] == formatVersion else { throw UrTable.UrTableError.badVersion }
        let pieces = Int(bytes[5])
        guard pieces >= 1 && pieces <= 7 else { throw UrTable.UrTableError.badPieces(pieces) }
        var offset = 8
        let total = Int(bytes.readUInt32LE(&offset))
        let layerCount = Int(bytes.readUInt32LE(&offset))
        var layerStart = [Int]()
        layerStart.reserveCapacity(layerCount + 1)
        for _ in 0...(layerCount) {
            layerStart.append(Int(bytes.readUInt64LE(&offset)))
        }
        guard total == layerStart[layerCount] else { throw UrTable.UrTableError.badOffsets }
        guard bytes.count == offset + total * 2 + 8 else { throw UrTable.UrTableError.truncated }
        var values = [UInt16]()
        values.reserveCapacity(total)
        for _ in 0..<total {
            values.append(bytes.readUInt16LE(&offset))
        }
        let stored = Array(bytes[offset..<offset + 8])
        let expected = FNV1a64.bytes(Data(bytes[0..<offset]))
        guard stored == expected else { throw UrTable.UrTableError.checksumMismatch }
        return UrTable(pieces: pieces, values: values, layerStart: layerStart)
    }

    public enum UrTableError: Error, CustomStringConvertible {
        case truncated
        case badMagic
        case badVersion
        case badPieces(Int)
        case badOffsets
        case checksumMismatch

        public var description: String {
            switch self {
            case .truncated: return "table file truncated"
            case .badMagic: return "not a Ur table file"
            case .badVersion: return "unsupported table format version"
            case .badPieces(let pieces): return "unsupported piece count \(pieces)"
            case .badOffsets: return "table offsets inconsistent"
            case .checksumMismatch: return "table checksum mismatch"
            }
        }
    }
}

/// Delta + varint compression for value tables (RS-P1.4), with an adaptive
/// raw fallback: the payload is stored as mode 1 (per-layer zigzag varint
/// deltas) or mode 0 (raw little-endian UInt16), whichever is smaller —
/// solved tables have structurally adjacent values whose deltas do not
/// always beat the raw encoding. Each layer restarts from its first value
/// to keep corruption local.
public enum UrTableCodec {

    public static func compress(_ values: [UInt16], layerStart: [Int]) -> Data {
        var header = Data()
        header.appendUInt32LE(UInt32(values.count))
        header.appendUInt32LE(UInt32(layerStart.count - 1))
        for offset in layerStart { header.appendUInt64LE(UInt64(offset)) }

        var deltaPayload = Data()
        var previous: Int = 0
        var layerIndex = 0
        var nextLayerStart = layerStart.count > 1 ? layerStart[1] : values.count
        for index in 0..<values.count {
            if index == nextLayerStart {
                layerIndex += 1
                nextLayerStart =
                    layerIndex + 1 < layerStart.count
                    ? layerStart[layerIndex + 1] : values.count
                previous = 0
            }
            let value = Int(values[index])
            let delta = value &- previous
            previous = value
            // Zigzag so small negative deltas stay short.
            let zigzag = UInt64(truncatingIfNeeded: (delta << 1) ^ (delta >> 31))
            appendVarint(zigzag, to: &deltaPayload)
        }

        // Mode 1 beats mode 0 only when the varint payload is strictly smaller
        // than two bytes per value.
        if deltaPayload.count < values.count * 2 {
            var out = header
            out.append(1)
            out.append(deltaPayload)
            return out
        }
        var out = header
        out.append(0)
        for value in values {
            out.append(UInt8(truncatingIfNeeded: value))
            out.append(UInt8(truncatingIfNeeded: value >> 8))
        }
        return out
    }

    public static func decompress(_ data: Data, pieces: Int) throws -> [UInt16] {
        var bytes = [UInt8](data)
        var offset = 0
        let count = Int(bytes.readUInt32LE(&offset))
        let layerCount = Int(bytes.readUInt32LE(&offset))
        var layerStart = [Int]()
        for _ in 0...layerCount {
            layerStart.append(Int(bytes.readUInt64LE(&offset)))
        }
        let ranking = UrRanking(pieces: pieces)
        guard layerStart[ranking.layerCount] == count else { throw UrTable.UrTableError.badOffsets }
        let mode = bytes.readUInt8(&offset)
        var values = [UInt16](repeating: 0, count: count)
        if mode == 0 {
            for index in 0..<count {
                let low = bytes.readUInt8(&offset)
                let high = bytes.readUInt8(&offset)
                values[index] = UInt16(low) | UInt16(high) << 8
            }
            return values
        }
        var previous = 0
        var layerIndex = 0
        var nextLayerStart = layerCount > 0 ? layerStart[1] : count
        for index in 0..<count {
            if index == nextLayerStart {
                layerIndex += 1
                nextLayerStart =
                    layerIndex + 1 < layerStart.count
                    ? layerStart[layerIndex + 1] : count
                previous = 0
            }
            let zigzag = try readVarint(bytes, &offset)
            let signed = (zigzag % 2 == 0) ? Int(zigzag / 2) : -Int((zigzag + 1) / 2)
            previous = previous &+ signed
            values[index] = UInt16(truncatingIfNeeded: previous)
        }
        return values
    }

    static func appendVarint(_ value: UInt64, to data: inout Data) {
        var v = value
        while true {
            let byte = v & 0x7F
            v >>= 7
            if v == 0 {
                data.append(UInt8(byte))
                break
            }
            data.append(UInt8(byte | 0x80))
        }
    }

    static func readVarint(_ bytes: [UInt8], _ offset: inout Int) throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while true {
            guard offset < bytes.count else { throw UrTable.UrTableError.truncated }
            let byte = bytes[offset]
            offset += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 { return result }
            shift += 7
            if shift > 63 { throw UrTable.UrTableError.badVersion }
        }
    }
}

/// FNV-1a 64-bit checksum, matching MatchState.stateHash.
public enum FNV1a64 {
    public static func digest(_ data: Data) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in [UInt8](data) {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }

    public static func bytes(_ data: Data) -> [UInt8] {
        let value = digest(data)
        return [
            UInt8(truncatingIfNeeded: value),
            UInt8(truncatingIfNeeded: value >> 8),
            UInt8(truncatingIfNeeded: value >> 16),
            UInt8(truncatingIfNeeded: value >> 24),
            UInt8(truncatingIfNeeded: value >> 32),
            UInt8(truncatingIfNeeded: value >> 40),
            UInt8(truncatingIfNeeded: value >> 48),
            UInt8(truncatingIfNeeded: value >> 56),
        ]
    }
}

extension Data {
    mutating func appendUInt16LE(_ value: UInt16) {
        append(UInt8(truncatingIfNeeded: value))
        append(UInt8(truncatingIfNeeded: value >> 8))
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        append(UInt8(truncatingIfNeeded: value))
        append(UInt8(truncatingIfNeeded: value >> 8))
        append(UInt8(truncatingIfNeeded: value >> 16))
        append(UInt8(truncatingIfNeeded: value >> 24))
    }

    mutating func appendUInt64LE(_ value: UInt64) {
        for shift in stride(from: 0, to: 64, by: 8) {
            append(UInt8(truncatingIfNeeded: value >> UInt64(shift)))
        }
    }
}

extension [UInt8] {
    mutating func readUInt8(_ offset: inout Int) -> UInt8 {
        let value = self[offset]
        offset += 1
        return value
    }

    mutating func readUInt16LE(_ offset: inout Int) -> UInt16 {
        let value = UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
        offset += 2
        return value
    }

    mutating func readUInt32LE(_ offset: inout Int) -> UInt32 {
        var value: UInt32 = 0
        for shift in stride(from: 0, to: 32, by: 8) {
            value |= UInt32(self[offset]) << UInt32(shift)
            offset += 1
        }
        return value
    }

    mutating func readUInt64LE(_ offset: inout Int) -> UInt64 {
        var value: UInt64 = 0
        for shift in stride(from: 0, to: 64, by: 8) {
            value |= UInt64(self[offset]) << UInt64(shift)
            offset += 1
        }
        return value
    }
}
