import Foundation
import RSCore

// MARK: - CloudStore

/// The iCloud surface the app uses (RS-P7.1): save and load a JSON-encoded
/// value under a key. The real implementation wraps CloudKit
/// (`CloudKitCloudStore`); the offline local build uses `FileCloudStore`
/// (a local substitute, `_CONVENTIONS.md` §8.2) and the tests use
/// `InMemoryCloudStore`.
public protocol CloudStore: Sendable {
    /// Save `data` under `key`, replacing any existing value.
    func save(_ data: Data, forKey key: String) async throws
    /// Load the value under `key`, or nil if absent.
    func load(forKey key: String) async throws -> Data?
}

// MARK: - InMemoryCloudStore

/// An in-memory `CloudStore` (RS-P7.1). Used by the tests.
public final class InMemoryCloudStore: CloudStore, @unchecked Sendable {
    private let lock = NSLock()
    private var store: [String: Data] = [:]

    public init() {}

    public func save(_ data: Data, forKey key: String) async throws {
        lock.withLock { store[key] = data }
    }

    public func load(forKey key: String) async throws -> Data? {
        lock.withLock { store[key] }
    }
}

// MARK: - FileCloudStore

/// A file-based `CloudStore` (RS-P7.1): the local substitute for iCloud.
/// Each key is a file in a directory (JSON data). This keeps the app's
/// sync logic working with no Apple account or CloudKit container; the
/// same `CloudStore` interface is backed by CloudKit in the real build.
public final class FileCloudStore: CloudStore, @unchecked Sendable {
    private let directory: URL
    private let lock = NSLock()

    public init(directory: URL) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func url(forKey key: String) -> URL {
        // Sanitize the key to a safe file name.
        let safe = key.replacingOccurrences(of: "[^A-Za-z0-9._-]", with: "_", options: .regularExpression)
        return directory.appendingPathComponent(safe + ".json")
    }

    public func save(_ data: Data, forKey key: String) async throws {
        let target = url(forKey: key)
        try lock.withLock {
            try data.write(to: target, options: .atomic)
        }
    }

    public func load(forKey key: String) async throws -> Data? {
        try lock.withLock {
            let url = url(forKey: key)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return try Data(contentsOf: url)
        }
    }
}

// MARK: - CloudSyncService

/// The app-facing iCloud service (RS-P7.1). Wraps a `CloudStore` and syncs
/// the player's circuit state (purse and progress) so it is preserved
/// across devices. The purse is in-game gold only (no real money).
public final class CloudSyncService: Sendable {
    private let store: any CloudStore

    /// The key the circuit state is stored under.
    public static let circuitKey = "rosette.circuit.v1"

    public init(_ store: any CloudStore) {
        self.store = store
    }

    /// Push the circuit state to the store.
    public func pushCircuit(_ state: CircuitState) async throws {
        let data = try JSONEncoder().encode(state)
        try await store.save(data, forKey: Self.circuitKey)
    }

    /// Pull the circuit state from the store, or nil if absent.
    public func pullCircuit() async throws -> CircuitState? {
        guard let data = try await store.load(forKey: Self.circuitKey) else { return nil }
        return try JSONDecoder().decode(CircuitState.self, from: data)
    }
}

// MARK: - CloudKitCloudStore

/// The real iCloud `CloudStore` (RS-P7.1), wrapping CloudKit.
///
/// OWNER-ONLY / UNTESTED: requires a signed-in Apple account with a CloudKit
/// container (App Store Connect + a CloudKit capability + a container id).
/// Per `_CONVENTIONS.md` §8.2 this is a local substitute in the build; the
/// real account work is a maintainer issue. The API calls follow the
/// documented CloudKit flow (save / fetch a private record) but have not
/// been exercised against a live container.
#if canImport(CloudKit)
import CloudKit

public final class CloudKitCloudStore: CloudStore, @unchecked Sendable {
    private let container: CKContainer
    private let zone: CKRecordZone.ID

    public init(container: CKContainer = .default()) {
        self.container = container
        self.zone = CKRecordZone.ID(
            zoneName: CKRecordZone.ID.defaultZoneName,
            ownerName: CKCurrentUserDefaultName
        )
    }

    private func recordID(forKey key: String) -> CKRecord.ID {
        CKRecord.ID(recordName: key, zoneID: zone)
    }

    public func save(_ data: Data, forKey key: String) async throws {
        let record = CKRecord(recordType: "RosetteValue", recordID: recordID(forKey: key))
        record["value"] = data
        _ = try await container.privateCloudDatabase.modifyRecords(
            saving: [record],
            deleting: [],
            savePolicy: .allKeys
        )
    }

    public func load(forKey key: String) async throws -> Data? {
        do {
            let record = try await container.privateCloudDatabase.record(for: recordID(forKey: key))
            return record["value"] as? Data
        } catch let error as CKError where error.code == .unknownItem {
            // A missing record is not an error: return nil.
            return nil
        }
    }
}
#endif
