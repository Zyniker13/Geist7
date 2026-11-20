import Foundation
import RSCore
import RSMeta
import RSPlatform

// MARK: - StatsRecorder

/// Accumulates per-match event counts from engine events and folds finished
/// matches into the persistent stats store (RS-P5.1; P9 beta export).
///
/// Counts are from player 0's perspective: captures by either side, rosette
/// landings by the local player, omens the local player played, pieces the
/// local player bore off, and doubles the local player offered.
struct StatsRecorder {
    private(set) var rosettesLanded = 0
    private(set) var piecesCaptured = 0
    private(set) var piecesCapturedByOpponent = 0
    private(set) var piecesBorneOff = 0
    private(set) var omensPlayed: [String] = []
    private(set) var doublesOffered = 0

    /// Fold one engine event into the per-match counters.
    mutating func observe(_ event: Event) {
        switch event {
        case .pieceCaptured(_, let by):
            if by == .player0 { piecesCaptured += 1 } else { piecesCapturedByOpponent += 1 }
        case .rosetteLanded(let player):
            if player == .player0 { rosettesLanded += 1 }
        case .pieceBorneOff(_, let player):
            if player == .player0 { piecesBorneOff += 1 }
        case .omenPlayed(let omenId, let player):
            if player == .player0 { omensPlayed.append(omenId) }
        case .doubleOffered(let by):
            if by == .player0 { doublesOffered += 1 }
        default:
            break
        }
    }

    /// Clear the counters for a fresh match.
    mutating func reset() {
        self = StatsRecorder()
    }

    /// Build the recorded result for a finished match.
    ///
    /// The outcome carries the authoritative won/gammon/stake/plies facts;
    /// the recorder carries the per-match event counts.
    func result(outcome: Outcome, dailyDay: Int?) -> MatchResult {
        MatchResult(
            won: outcome.winner == .player0,
            gammon: outcome.gammon,
            cubeValue: outcome.cubeValue,
            stake: outcome.initialStake,
            plies: outcome.plies,
            rosettesLanded: rosettesLanded,
            piecesCaptured: piecesCaptured,
            piecesCapturedByOpponent: piecesCapturedByOpponent,
            piecesBorneOff: piecesBorneOff,
            omensPlayed: omensPlayed,
            doublesOffered: doublesOffered,
            isDaily: dailyDay != nil,
            dailyDay: dailyDay)
    }
}

// MARK: - StatsStore

/// The app's shared on-device stats store.
enum StatsStore {
    /// The single shared store backed by the default on-device directory.
    static let shared = MetaStore(directory: MetaStore.defaultDirectory())
}

// MARK: - Stats export (P9)

/// The telemetry-free statistics export document (P9).
///
/// Everything in the document comes from the on-device stores. Nothing is
/// uploaded by the app: the player chooses whether and where to send the
/// exported file.
struct StatsExportDocument: Codable, Equatable {
    /// Format marker, so future formats can be recognized.
    let format: String
    /// Document format version.
    let version: Int
    /// When the export was generated (ISO-8601).
    let generatedAt: String
    /// Marketing version of the app that produced the export.
    let appVersion: String
    /// Build number of the app that produced the export.
    let build: String
    /// The lifetime match statistics (RS-P5.1).
    let stats: PlayerStats
    /// Every retained daily match result, oldest day first.
    let dailyResults: [DailyEntry]

    /// One daily match result.
    struct DailyEntry: Codable, Equatable {
        let day: Int
        let result: String
    }
}

/// Builds and writes the stats export file for the Settings screen (P9).
enum StatsExporter {
    /// The current format values.
    static let formatName = "rosette-stats-export"
    static let formatVersion = 1

    /// Build the export document from the on-device stores.
    ///
    /// - Parameters:
    ///   - stats: the lifetime statistics from the MetaStore.
    ///   - dailyResults: retained daily results, oldest day first.
    ///   - generatedAt: the ISO-8601 timestamp for the export (injectable so
    ///     tests are deterministic).
    ///   - appVersion: the marketing version string (injectable for tests).
    ///   - build: the build number string (injectable for tests).
    static func document(
        stats: PlayerStats,
        dailyResults: [StatsExportDocument.DailyEntry],
        generatedAt: String,
        appVersion: String,
        build: String
    ) -> StatsExportDocument {
        StatsExportDocument(
            format: formatName,
            version: formatVersion,
            generatedAt: generatedAt,
            appVersion: appVersion,
            build: build,
            stats: stats,
            dailyResults: dailyResults)
    }

    /// The current app's version and build, from the bundle.
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    /// Build the export document from the app's live on-device stores.
    static func liveDocument(generatedAt: String) -> StatsExportDocument {
        let store = StatsStore.shared
        let daily = DailyResultStore()
        let entries = daily.allResults().map { entry in
            StatsExportDocument.DailyEntry(day: entry.day, result: entry.result.rawValue)
        }
        return document(
            stats: store.loadStats(),
            dailyResults: entries,
            generatedAt: generatedAt,
            appVersion: appVersion,
            build: appBuild)
    }

    /// Write the export as JSON to a temp file and return its URL.
    ///
    /// The file name carries the date so successive exports never clobber
    /// each other in the share sheet's recents.
    static func writeJSON(_ export: StatsExportDocument, now: Date) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(export)
        let name = Self.fileName(for: now)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// The export file name for a date, e.g. `rosette-stats-2026-11-20.json`.
    static func fileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return "rosette-stats-\(formatter.string(from: date)).json"
    }
}
