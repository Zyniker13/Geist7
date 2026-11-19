// MARK: - CloudSyncManager

import RSCore
import RSPlatform
import SwiftUI

/// App-facing iCloud sync wrapper (RS-P7.1). Persists the circuit state so
/// it survives reinstall and can move across devices.
///
/// The local substitute (`_CONVENTIONS.md` §8.2): this build has no CloudKit
/// container or Apple account, so the store is a `FileCloudStore` — the same
/// `CloudStore` interface the real `CloudKitCloudStore` implements. Switching
/// to the real container is a maintainer issue. Policy for this build: the
/// store copy wins at launch when present (the device pushes after every
/// circuit mutation, so on a single device the store is current); merging
/// concurrent edits across devices is part of the real container work.
@MainActor
final class CloudSyncManager: ObservableObject {
    /// When the store last accepted a push (Settings display).
    @Published private(set) var lastPushDate: Date?

    private let store: any CloudStore
    private static let circuitKey = "rosette.circuit.v1"

    /// The app-wide sync manager (injected into the environment at the app
    /// root; the circuit model uses the same instance).
    static let shared = CloudSyncManager()

    init(store: any CloudStore = FileCloudStore(
        directory: FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!.appendingPathComponent("rosette-cloud", isDirectory: true)
    )) {
        self.store = store
    }

    /// Push the circuit state to the store (best-effort: a failed push
    /// never blocks play — the circuit keeps working locally).
    func push(_ state: CircuitState) async {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? await store.save(data, forKey: Self.circuitKey)
        lastPushDate = Date()
    }

    /// Pull the stored circuit state, or nil when absent or unreadable.
    func pull() async -> CircuitState? {
        guard let data = try? await store.load(forKey: Self.circuitKey),
            let state = try? JSONDecoder().decode(CircuitState.self, from: data)
        else { return nil }
        return state
    }
}
