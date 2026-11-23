// Replay.swift — deterministic replay support and stable state hashing.
//
// _CONVENTIONS S0.6: every game records a Replay (seed, ordered events,
// final state hash) and a golden-replay test harness verifies it.
// INV-4 (Dry Garden roadmap): replay determinism — the same seed and
// action list must rebuild the identical state.
//
// Swift's `Hasher` is seeded per process, so `Hashable` hashes are NOT
// stable across runs or devices. State hashes that appear in replays,
// debug overlays, and golden tests use FNV-1a 64 over a canonical
// byte encoding instead, which is stable everywhere.

import Foundation

/// FNV-1a 64-bit (Fowler, Noll, Vo). Used only for replay verification,
/// never for security.
public enum FNV1a64: Sendable {
    public static let offsetBasis: UInt64 = 0xCBF2_9CE4_8422_2325
    public static let prime: UInt64 = 0x0000_0100_0000_01B3

    public static func hash(_ data: [UInt8]) -> UInt64 {
        var h = offsetBasis
        for b in data {
            h ^= UInt64(b)
            h = h &* prime
        }
        return h
    }

    public static func hash(_ string: String) -> UInt64 {
        hash(Array(string.utf8))
    }
}

/// Stable hash for any Encodable value: a canonical byte encoding,
/// then FNV-1a 64. The same value hashes identically on every device
/// and in every process.
///
/// Swift encodes `Dictionary` and `Set` in per-process hash-seed order
/// even under `JSONEncoder`'s `.sortedKeys` (that option sorts the
/// object keys of a keyed container, not the element order of a
/// dictionary encoded as alternating key/value elements), and
/// floating-point encodings can differ per build. A state carrying any
/// dictionary — GameState carries supplies and rakes used — would
/// therefore hash differently across processes and devices, breaking
/// INV-4's byte-identical requirement. The canonical form encodes
/// every value independently and sorts dictionary entries, so the
/// encoding is order-stable everywhere.
///
/// Supported: Bool, the fixed-width and Swift integer types, Double,
/// Float, String, RawRepresentable strings/ints (enum cases), arrays,
/// sets (order-canonicalized), dictionaries (entry-sorted), and
/// Codable structs/enums composed of those, via reflection of their
/// stored properties in declaration order.
public enum StateHashing: Sendable {
    public static func stableHash<T: Encodable>(_ value: T) throws -> UInt64 {
        FNV1a64.hash(try CanonicalEncoding.encode(value))
    }
}

/// A single recorded ply in a replay.
public struct ReplayEvent: Codable, Sendable, Equatable {
    public let ply: Int
    public let action: String
    public let params: [String: String]

    public init(ply: Int, action: String, params: [String: String] = [:]) {
        self.ply = ply
        self.action = action
        self.params = params
    }
}

/// A complete replay: the seed that generated the match, the ordered
/// event list, and the stable hash of the final state for verification.
public struct Replay: Codable, Sendable, Equatable {
    public let seed: UInt64
    public let version: Int
    public let events: [ReplayEvent]
    public let finalHash: UInt64

    public init(seed: UInt64, version: Int = 1, events: [ReplayEvent], finalHash: UInt64) {
        self.seed = seed
        self.version = version
        self.events = events
        self.finalHash = finalHash
    }

    public func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> Replay {
        try JSONDecoder().decode(Replay.self, from: data)
    }

    public func save(to url: URL) throws {
        try encode().write(to: url)
    }

    public static func load(from url: URL) throws -> Replay {
        try decode(Data(contentsOf: url))
    }
}

/// The canonical encoding: one total order over every supported value.
/// Chunks carry a discriminator so "1" (string) never equals 1 (int).
enum CanonicalEncoding {

    /// Entry point: encodes any Encodable into canonical bytes.
    static func encode<T: Encodable>(_ value: T) throws -> [UInt8] {
        var sink = ByteSink()
        try write(value, into: &sink)
        return sink.bytes
    }

    /// The mutable byte accumulator.
    struct ByteSink {
        var bytes: [UInt8] = []
    }

    // MARK: Scalar leaves

    private static func write(_ value: Bool, into sink: inout ByteSink) {
        sink.bytes.append(value ? 0x54 : 0x46)  // "T" / "F"
    }

    private static func write(_ value: String, into sink: inout ByteSink) {
        sink.bytes.append(0x53)  // "S"
        sink.bytes.append(contentsOf: Array(value.utf8))
        sink.bytes.append(0x00)  // terminator keeps prefix-unambiguity
    }

    /// Integers encode big-endian in offset-binary form (all bits
    /// flipped for negatives), which orders lexicographically exactly
    /// as the numbers order numerically: −1 < 0 < 1.
    private static func write(_ value: Int, into sink: inout ByteSink) {
        sink.bytes.append(0x49)  // "I"
        let negative = value < 0
        let flipped = negative
            ? ~UInt64(bitPattern: Int64(value))
            : UInt64(bitPattern: Int64(value))
        for shift in stride(from: 56, through: 0, by: -8) {
            sink.bytes.append(UInt8((flipped >> UInt64(shift)) & 0xFF))
        }
    }

    private static func write(_ value: Int8, into sink: inout ByteSink) {
        write(Int(value), into: &sink)
    }
    private static func write(_ value: Int16, into sink: inout ByteSink) {
        write(Int(value), into: &sink)
    }
    private static func write(_ value: Int32, into sink: inout ByteSink) {
        write(Int(value), into: &sink)
    }
    private static func write(_ value: Int64, into sink: inout ByteSink) {
        // Int64 values beyond Int's range would lose bits; the game's
        // states never carry them (Fixed keeps raw Int64 but hashes
        // through its own Codable as an Int64... guard by folding the
        // full 64 bits into the stream via two Int writes).
        sink.bytes.append(0x49)
        let negative = value < 0
        let flipped = negative ? ~UInt64(bitPattern: value) : UInt64(bitPattern: value)
        for shift in stride(from: 56, through: 0, by: -8) {
            sink.bytes.append(UInt8((flipped >> UInt64(shift)) & 0xFF))
        }
    }
    private static func write(_ value: UInt, into sink: inout ByteSink) {
        sink.bytes.append(0x55)  // "U"
        for shift in stride(from: 56, through: 0, by: -8) {
            sink.bytes.append(UInt8((value >> UInt64(shift)) & 0xFF))
        }
    }
    private static func write(_ value: UInt8, into sink: inout ByteSink) {
        write(UInt(value), into: &sink)
    }
    private static func write(_ value: UInt16, into sink: inout ByteSink) {
        write(UInt(value), into: &sink)
    }
    private static func write(_ value: UInt32, into sink: inout ByteSink) {
        write(UInt(value), into: &sink)
    }
    private static func write(_ value: UInt64, into sink: inout ByteSink) {
        write(UInt(value), into: &sink)
    }

    /// Doubles: encode the IEEE bit pattern (canonical across devices;
    /// -0.0 normalizes to 0.0; NaN folds to one representation).
    private static func write(_ value: Double, into sink: inout ByteSink) {
        sink.bytes.append(0x44)  // "D"
        var bits = value.bitPattern
        if bits == 0x8000_0000_0000_0000 { bits = 0 }  // -0.0 → +0.0
        if value.isNaN { bits = 0x7FF8_0000_0000_0000 }
        for shift in stride(from: 56, through: 0, by: -8) {
            sink.bytes.append(UInt8((bits >> UInt64(shift)) & 0xFF))
        }
    }

    private static func write(_ value: Float, into sink: inout ByteSink) {
        write(Double(value), into: &sink)
    }

    // MARK: Composites

    private static func write(_ values: [UInt8], as Tag: UInt8, into sink: inout ByteSink) {
        sink.bytes.append(Tag)
        write(values.count, into: &sink)
        sink.bytes.append(contentsOf: values)
    }

    private static func write<T: Encodable>(_ values: [T], into sink: inout ByteSink) throws {
        sink.bytes.append(0x41)  // "A" array
        write(values.count, into: &sink)
        for value in values {
            try write(value, into: &sink)
        }
    }

    private static func write<T: Hashable & Encodable>(_ values: Set<T>, into sink: inout ByteSink) throws {
        // Sets are order-free: sort each element's canonical bytes.
        var elementSinks: [[UInt8]] = []
        for value in values {
            var elementSink = ByteSink()
            try write(value, into: &elementSink)
            elementSinks.append(elementSink.bytes)
        }
        elementSinks.sort { lhs, rhs in
            lhs.lexicographicallyPrecedes(rhs)
        }
        sink.bytes.append(0x41)
        write(elementSinks.count, into: &sink)
        for element in elementSinks {
            sink.bytes.append(contentsOf: element)
        }
    }

    private static func write<K: Hashable & Encodable, V: Encodable>(
        _ dictionary: [K: V], into sink: inout ByteSink
    ) throws {
        // Dictionaries are order-free: sort the (key, value) canonical
        // byte pairs lexicographically.
        var pairs: [[UInt8]] = []
        for (key, value) in dictionary {
            var keySink = ByteSink()
            try write(key, into: &keySink)
            var valueSink = ByteSink()
            try write(value, into: &valueSink)
            keySink.bytes.append(contentsOf: valueSink.bytes)
            pairs.append(keySink.bytes)
        }
        pairs.sort { lhs, rhs in
            lhs.lexicographicallyPrecedes(rhs)
        }
        sink.bytes.append(0x4D)  // "M" map
        write(pairs.count, into: &sink)
        for pair in pairs {
            sink.bytes.append(contentsOf: pair)
        }
    }

    private static func write(_ value: Optional<some Encodable>, into sink: inout ByteSink) throws {
        // Optionals: 0x4E "N" for nil; Some(v) delegates.
        sink.bytes.append(0x4E)
    }

    // MARK: The generic router

    /// The heart: one function per supported shape, dispatched through
    /// a protocol witness so the generic `write<T: Encodable>` picks
    /// the right overload via conditional conformance checks.
    static func write<T: Encodable>(_ value: T, into sink: inout ByteSink) throws {
        if let bool = value as? Bool {
            write(bool, into: &sink)
        } else if let string = value as? String {
            write(string, into: &sink)
        } else if let int = value as? Int {
            write(int, into: &sink)
        } else if let int8 = value as? Int8 {
            write(int8, into: &sink)
        } else if let int16 = value as? Int16 {
            write(int16, into: &sink)
        } else if let int32 = value as? Int32 {
            write(int32, into: &sink)
        } else if let int64 = value as? Int64 {
            write(int64, into: &sink)
        } else if let uint = value as? UInt {
            write(uint, into: &sink)
        } else if let uint8 = value as? UInt8 {
            write(uint8, into: &sink)
        } else if let uint16 = value as? UInt16 {
            write(uint16, into: &sink)
        } else if let uint32 = value as? UInt32 {
            write(uint32, into: &sink)
        } else if let uint64 = value as? UInt64 {
            write(uint64, into: &sink)
        } else if let double = value as? Double {
            write(double, into: &sink)
        } else if let float = value as? Float {
            write(float, into: &sink)
        } else if let array = value as? [Any] {
            // Dynamic arrays: re-enter per element through AnyHaystack.
            sink.bytes.append(0x41)
            write(array.count, into: &sink)
            for element in array {
                try writeAny(element, into: &sink)
            }
        } else if let dictionary = value as? [AnyHashable: Any] {
            sink.bytes.append(0x4D)
            write(dictionary.count, into: &sink)
            var pairs: [[UInt8]] = []
            for (key, element) in dictionary {
                var pairSink = ByteSink()
                try writeAny(key.base, into: &pairSink)
                try writeAny(element, into: &pairSink)
                pairs.append(pairSink.bytes)
            }
            pairs.sort { lhs, rhs in
                lhs.lexicographicallyPrecedes(rhs)
            }
            for pair in pairs {
                sink.bytes.append(contentsOf: pair)
            }
        } else {
            // A Codable struct/enum: reflect its fields in declaration
            // order (deterministic; the compiler fixes the order).
            try writeAnyReflectable(value, into: &sink)
        }
    }

    /// Writes an `Any` by re-entering the router with its dynamic type.
    static func writeAny(_ value: Any, into sink: inout ByteSink) throws {
        if let v = value as? Bool { write(v, into: &sink) }
        else if let v = value as? String { write(v, into: &sink) }
        else if let v = value as? Int { write(v, into: &sink) }
        else if let v = value as? Int8 { write(v, into: &sink) }
        else if let v = value as? Int16 { write(v, into: &sink) }
        else if let v = value as? Int32 { write(v, into: &sink) }
        else if let v = value as? Int64 { write(v, into: &sink) }
        else if let v = value as? UInt { write(v, into: &sink) }
        else if let v = value as? UInt8 { write(v, into: &sink) }
        else if let v = value as? UInt16 { write(v, into: &sink) }
        else if let v = value as? UInt32 { write(v, into: &sink) }
        else if let v = value as? UInt64 { write(v, into: &sink) }
        else if let v = value as? Double { write(v, into: &sink) }
        else if let v = value as? Float { write(v, into: &sink) }
        else if let v = value as? [Any] {
            sink.bytes.append(0x41)
            write(v.count, into: &sink)
            for element in v {
                try writeAny(element, into: &sink)
            }
        } else if let v = value as? [AnyHashable: Any] {
            sink.bytes.append(0x4D)
            write(v.count, into: &sink)
            var pairs: [[UInt8]] = []
            for (key, element) in v {
                var pairSink = ByteSink()
                try writeAny(key.base, into: &pairSink)
                try writeAny(element, into: &pairSink)
                pairs.append(pairSink.bytes)
            }
            pairs.sort { lhs, rhs in
                lhs.lexicographicallyPrecedes(rhs)
            }
            for pair in pairs {
                sink.bytes.append(contentsOf: pair)
            }
        } else {
            try writeAnyReflectable(value, into: &sink)
        }
    }

    /// The `Any`-typed reflection path (structs and enums reached via
    /// dynamic dispatch from dictionaries, arrays, and mirrors).
    static func writeAnyReflectable(_ value: Any, into sink: inout ByteSink) throws {
        if let raw = value as? any RawRepresentable {
            let rawValue = raw.rawValue
            if let stringValue = rawValue as? String {
                sink.bytes.append(0x52)  // "R" raw-enum
                write(stringValue, into: &sink)
                return
            }
            if let intValue = rawValue as? Int {
                sink.bytes.append(0x52)
                write(intValue, into: &sink)
                return
            }
            if let int64Value = rawValue as? Int64 {
                sink.bytes.append(0x52)
                write(int64Value, into: &sink)
                return
            }
        }
        let mirror = Mirror(reflecting: value)
        let typeName = String(describing: type(of: value))
        sink.bytes.append(0x4F)  // "O" object
        write(typeName, into: &sink)
        var fields: [[UInt8]] = []
        for child in mirror.children {
            guard let label = child.label else {
                var fieldSink = ByteSink()
                write("#", into: &fieldSink)
                try writeAny(child.value, into: &fieldSink)
                fields.append(fieldSink.bytes)
                continue
            }
            var fieldSink = ByteSink()
            write(label, into: &fieldSink)
            try writeAny(child.value, into: &fieldSink)
            fields.append(fieldSink.bytes)
        }
        write(fields.count, into: &sink)
        for field in fields {
            sink.bytes.append(contentsOf: field)
        }
    }

    // MARK: Reflection

    /// Encodes a Codable struct or enum field-by-field in declaration
    /// order, tagged with the type name so distinct types never
    /// collide. Uses Mirror for the field list; each field re-enters
    /// the generic router with its dynamic type.
    static func writeReflectable<T: Encodable>(_ value: T, into sink: inout ByteSink) throws {
        // RawRepresentable enums encode as their raw value (stable
        // forever once shipped — the roadmap's content-ID rule).
        if let raw = value as? any RawRepresentable {
            let rawValue = raw.rawValue
            if let stringValue = rawValue as? String {
                sink.bytes.append(0x52)  // "R" raw-enum
                write(stringValue, into: &sink)
                return
            }
            if let intValue = rawValue as? Int {
                sink.bytes.append(0x52)
                write(intValue, into: &sink)
                return
            }
            if let int64Value = rawValue as? Int64 {
                sink.bytes.append(0x52)
                write(int64Value, into: &sink)
                return
            }
        }
        let mirror = Mirror(reflecting: value)
        let typeName = String(describing: type(of: value))
        sink.bytes.append(0x4F)  // "O" object
        write(typeName, into: &sink)
        var fields: [[UInt8]] = []
        for child in mirror.children {
            guard let label = child.label else {
                // Unlabeled children (tuples, some enums) fall back to
                // ordinal tags; no game state relies on them.
                var fieldSink = ByteSink()
                write("#", into: &fieldSink)
                try writeAny(child.value, into: &fieldSink)
                fields.append(fieldSink.bytes)
                continue
            }
            var fieldSink = ByteSink()
            write(label, into: &fieldSink)
            try writeAny(child.value, into: &fieldSink)
            fields.append(fieldSink.bytes)
        }
        write(fields.count, into: &sink)
        for field in fields {
            sink.bytes.append(contentsOf: field)
        }
    }
}
