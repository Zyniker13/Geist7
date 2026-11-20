// MARK: - DailyResultStore

import Foundation

/// The locally persisted daily-match results (RS-P7.1): one entry per UTC
/// day, so the daily screen can show whether today's match was won without
/// needing Game Center. Retention is bounded to the last 30 days.
public struct DailyResultStore {
    /// One day's outcome.
    public enum Result: String, Codable, Sendable, Equatable {
        case won
        case lost
    }

    private let defaults: UserDefaults
    private static let key = "rosette.daily-results.v1"
    private static let retention = 30

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The recorded result for `day`, or nil when not played.
    public func result(for day: Int) -> Result? {
        all[day]
    }

    /// All retained results, oldest day first (the stats export reads this).
    public func allResults() -> [(day: Int, result: Result)] {
        all.map { (day: $0.key, result: $0.value) }
            .sorted { $0.day < $1.day }
    }

    /// Record `day`'s result.
    public func record(day: Int, result: Result) {
        var all = all
        all[day] = result
        // Keep only the last `retention` days (bounded storage).
        if all.count > Self.retention {
            let keep = all.keys.sorted().suffix(Self.retention)
            all = all.filter { keep.contains($0.key) }
        }
        if let data = try? JSONEncoder().encode(all) {
            defaults.set(data, forKey: Self.key)
        }
    }

    private var all: [Int: Result] {
        guard let data = defaults.data(forKey: Self.key),
            let decoded = try? JSONDecoder().decode([Int: Result].self, from: data)
        else { return [:] }
        return decoded
    }
}
