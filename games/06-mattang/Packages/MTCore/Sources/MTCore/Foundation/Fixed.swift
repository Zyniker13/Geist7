// Fixed.swift — Q32.32 fixed-point numeric type.
//
// _CONVENTIONS S0.2: all engine math runs on a `Fixed` Q32.32 type so
// results are bit-identical across devices and match simulator runs.
//
// Layout: one Int64 raw value; 32 integer bits (signed), 32 fraction
// bits. Range ±2^31, resolution 2^-32. Multiply and divide go through
// 128-bit intermediates implemented with UInt64 halves (no Int128
// dependency), then truncate back to Q32.32.

public struct Fixed: Hashable, Comparable, Codable, Sendable {
    /// Raw Q32.32 bit pattern.
    public private(set) var raw: Int64

    public init(raw: Int64) { self.raw = raw }

    // MARK: Constants

    public static let zero = Fixed(raw: 0)
    public static let one = Fixed(raw: 1 << 32)
    public static let half = Fixed(raw: 1 << 31)

    // MARK: Conversion

    public init(_ value: Int) {
        // Saturate so out-of-range integers clamp instead of wrapping.
        let clamped = min(max(value, Int(Int32.min)), Int(Int32.max))
        self.raw = Int64(clamped) << 32
    }

    /// Lossy conversion from Double, rounded to nearest representable.
    public init(_ value: Double) {
        let q = (value * 4_294_967_296.0).rounded()
        // Saturate to Int64 range to avoid UB-style wrap on huge inputs.
        if q >= 9.223372036854776e18 {
            self.raw = Int64.max
        } else if q <= -9.223372036854776e18 - 1 {
            self.raw = Int64.min
        } else {
            self.raw = Int64(q)
        }
    }

    public var doubleValue: Double {
        Double(raw) / 4_294_967_296.0
    }

    public var intValue: Int {
        Int(raw >> 32)
    }

    public var isZero: Bool {
        raw == 0
    }

    // MARK: Arithmetic

    public static func + (lhs: Fixed, rhs: Fixed) -> Fixed {
        // Truncating wrap matches hardware fixed-point behavior; tests
        // cover in-range values only.
        var result = lhs
        result.raw = lhs.raw &+ rhs.raw
        return result
    }

    public static func - (lhs: Fixed, rhs: Fixed) -> Fixed {
        var result = lhs
        result.raw = lhs.raw &- rhs.raw
        return result
    }

    /// Q32.32 multiply: full 128-bit product of magnitudes, then take
    /// bits 32..95 and reapply the sign.
    public static func * (lhs: Fixed, rhs: Fixed) -> Fixed {
        let neg = (lhs.raw < 0) != (rhs.raw < 0)
        // Magnitudes, not raw bit patterns: the unsigned 128-bit math
        // below is only correct for non-negative operands.
        let a = UInt64(lhs.raw.magnitude)
        let b = UInt64(rhs.raw.magnitude)
        let aHi = a >> 32
        let aLo = a & 0xFFFF_FFFF
        let bHi = b >> 32
        let bLo = b & 0xFFFF_FFFF

        let t0 = aLo &* bLo  // fits: both < 2^32
        // t1 fits: aLo < 2^32 and bHi < 2^32, so the product is < 2^64.
        let t1 = aLo &* bHi
        let t2 = aHi &* bLo  // fits
        let t3 = aHi &* bHi  // fits

        // product = t3<<64 + (t1+t2)<<32 + t0
        let mid = t1 &+ t2
        let midCarry: UInt64 = t1 > mid ? 1 : 0

        let lo = t0 &+ (mid << 32)
        let loCarry: UInt64 = t0 > lo ? 1 : 0
        let hi = t3 &+ (mid >> 32) &+ (midCarry << 32) &+ loCarry

        // Q32.32 result = bits 32..95 of the 128-bit product.
        let truncated = (hi << 32) | (lo >> 32)
        let magnitude = Int64(bitPattern: truncated)
        var result = lhs
        // Negate via wrapping UInt64 subtraction so the full two's
        // complement range (including Int64.min) stays representable.
        result.raw =
            neg
            ? Int64(bitPattern: 0 &- UInt64(bitPattern: magnitude))
            : magnitude
        return result
    }

    /// Q32.32 divide: 128-bit numerator (self << 32) divided by rhs,
    /// quotient taken as Q32.32.
    public static func / (lhs: Fixed, rhs: Fixed) -> Fixed {
        precondition(!rhs.isZero, "division by zero")
        let neg = (lhs.raw < 0) != (rhs.raw < 0)
        // Magnitudes: unsigned long division is only correct for
        // non-negative operands.
        let dividend = UInt64(lhs.raw.magnitude)
        let divisor = UInt64(rhs.raw.magnitude)

        // numerator = dividend << 32 as 128-bit (hi64, lo64).
        var hi = dividend >> 32
        var lo = dividend << 32

        // Binary long division, 64 quotient bits.
        var quotient: UInt64 = 0
        for _ in 0..<64 {
            // Shift (hi, lo) left one bit.
            let topBit = hi >> 63
            hi = (hi << 1) | (lo >> 63)
            lo = lo << 1
            quotient = quotient << 1
            if topBit == 1 || hi >= divisor {
                hi = hi &- divisor
                quotient |= 1
            }
        }
        let magnitude = Int64(bitPattern: quotient)
        var result = lhs
        result.raw =
            neg
            ? Int64(bitPattern: 0 &- UInt64(bitPattern: magnitude))
            : magnitude
        return result
    }

    public static prefix func - (value: Fixed) -> Fixed {
        var result = value
        result.raw = value.raw == Int64.min ? Int64.max : -value.raw
        return result
    }

    public static func < (lhs: Fixed, rhs: Fixed) -> Bool {
        lhs.raw < rhs.raw
    }

    public static func += (lhs: inout Fixed, rhs: Fixed) { lhs = lhs + rhs }
    public static func -= (lhs: inout Fixed, rhs: Fixed) { lhs = lhs - rhs }
    public static func *= (lhs: inout Fixed, rhs: Fixed) { lhs = lhs * rhs }
    public static func /= (lhs: inout Fixed, rhs: Fixed) { lhs = lhs / rhs }

    /// Linear interpolation: self + (other - self) * t, t in [0, 1].
    public func lerp(to other: Fixed, _ t: Fixed) -> Fixed {
        self + (other - self) * t
    }
}

extension Fixed: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        String(format: "%.6f", doubleValue)
    }

    public var debugDescription: String {
        "Fixed(\(description), raw=\(raw))"
    }
}
