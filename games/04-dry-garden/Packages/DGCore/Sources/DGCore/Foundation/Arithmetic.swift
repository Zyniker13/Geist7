// Arithmetic.swift — small integer helpers shared by the lattice code.

/// Floored modulo: the result is always in 0..<rhs, even for negative
/// lhs (Swift's `%` truncates toward zero and can return negatives).
@inlinable
public func flooredMod(_ lhs: Int, _ rhs: Int) -> Int {
    precondition(rhs > 0, "modulus must be positive")
    let remainder = lhs % rhs
    return remainder < 0 ? remainder + rhs : remainder
}
