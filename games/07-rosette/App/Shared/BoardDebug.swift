import Foundation

/// Optional timing instrumentation, enabled by the `-boardDebug` launch
/// argument. Appends elapsed-since-first-mark lines to `Documents/
/// boardDebug.txt` so a simulator probe can read the resume/board-entry
/// timeline from the host (P8 performance work; harmless in production).
enum BoardDebug {
    /// Wall clock is legitimate here: this is debug-only profiling
    /// instrumentation, not game logic (see .swiftlint.yml banned_api).
    private static let t0: Double? = {
        guard ProcessInfo.processInfo.arguments.contains("-boardDebug") else { return nil }
        return CFAbsoluteTimeGetCurrent()
    }()

    /// Append a timing line ("+0.123 s | <label>") when `-boardDebug` is set.
    static func mark(_ label: String) {
        guard let t0 else { return }
        let now = CFAbsoluteTimeGetCurrent()
        let line = String(format: "+%.3f s | %@\n", now - t0, label)
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = dir.appendingPathComponent("boardDebug.txt")
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
