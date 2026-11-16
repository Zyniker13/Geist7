// MARK: - RecordedAction / SavedMatch

import Foundation
import RSCore

/// A recorded action in a saved match. Mirrors RSCore's `Action` cases in a
/// Codable form so a saved match can be restored by deterministic replay:
/// rebuild the initial state from the stored configuration, then fold the
/// action history through `Reducer.apply` with the stored seed (INV-4/INV-7
/// guarantee the restored state is bit-identical to the saved one).
enum RecordedAction: Codable, Equatable {
    case roll
    case move(PieceID)
    case offerDouble
    case acceptDouble
    case concede
    case playOmen(String)
    case setStake(Int)
}

/// The persisted snapshot of one match.
struct SavedMatch: Codable, Equatable {
    static let currentVersion = 1

    let version: Int
    /// Seed for the dice stream (the omen stream is derived from it).
    let seed: UInt64
    let stakeValue: Int
    /// Omen held by player 0, by id ("reroll", "unsafeRosettes", "split").
    let omenId: String?
    let useAI: Bool
    /// The action history in application order.
    let actions: [RecordedAction]
}

// MARK: - SaveManager

/// Persists match snapshots as JSON in Documents/RosetteSaves.
enum SaveManager {
    /// The directory holding saved matches.
    static var savesDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("RosetteSaves", isDirectory: true)
    }

    /// Save a snapshot. The file name carries a wall-clock timestamp so saves
    /// sort chronologically by name; the game state itself stays deterministic.
    @discardableResult
    static func save(_ snapshot: SavedMatch) -> URL? {
        do {
            try FileManager.default.createDirectory(
                at: savesDirectory, withIntermediateDirectories: true
            )
            let url = savesDirectory.appendingPathComponent(fileName(for: snapshot))
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    /// All saved matches, newest first (file names sort by timestamp).
    static func allSaves() -> [URL] {
        let files =
            (try? FileManager.default.contentsOfDirectory(
                at: savesDirectory, includingPropertiesForKeys: nil
            )) ?? []
        return
            files
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    // MARK: - Autosave (S2.4 resume)

    /// The fixed autosave slot, overwritten on every applied action.
    static var autosaveURL: URL {
        savesDirectory.appendingPathComponent("autosave.json")
    }

    /// Write the autosave slot (overwrites the previous one).
    @discardableResult
    static func saveAutosave(_ snapshot: SavedMatch) -> URL? {
        do {
            try FileManager.default.createDirectory(
                at: savesDirectory, withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: autosaveURL, options: .atomic)
            return autosaveURL
        } catch {
            return nil
        }
    }

    /// Remove the autosave slot (called when a match completes).
    static func deleteAutosave() {
        try? FileManager.default.removeItem(at: autosaveURL)
    }

    /// The snapshot to resume: the autosave slot if present, else the newest
    /// timestamped save.
    static func resumeCandidate() -> SavedMatch? {
        if let data = try? Data(contentsOf: autosaveURL),
            let snapshot = try? JSONDecoder().decode(SavedMatch.self, from: data)
        {
            return snapshot
        }
        return latest()
    }

    /// Load the most recent save, if any.
    static func latest() -> SavedMatch? {
        guard let url = allSaves().first else { return nil }
        return load(from: url)
    }

    /// Load a snapshot from a file.
    static func load(from url: URL) -> SavedMatch? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SavedMatch.self, from: data)
    }

    /// Delete a save file.
    static func delete(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Delete all save files.
    static func deleteAll() {
        for url in allSaves() {
            delete(url)
        }
    }

    /// File name for a snapshot: wall-clock timestamp for ordering, plus the
    /// seed so the name alone identifies the dice stream.
    private static func fileName(for snapshot: SavedMatch) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let stamp = formatter.string(from: Date())
        return "save_\(stamp)_seed\(snapshot.seed).json"
    }
}
