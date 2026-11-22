// MemoBox.swift — a tiny boxed memo for immutable value types.
//
// `Chart` (and any other immutable value) computes a derived set once
// per copy instead of on every read. The class box breaks the
// copy-on-write; a data race can only cause a redundant rebuild, so
// no lock is needed for correctness.

final class MemoBox<Value>: @unchecked Sendable {
    private var storage: Value?
    var value: Value? {
        get { storage }
        set { storage = newValue }
    }
}
