// sim — headless CLI for Rosette (S1.3).
//
// Plays deterministic random-legal-move matches and prints a summary and a
// final combined hash; two runs with the same arguments print the same hash.
// With --golden-out it writes golden replay fixtures (S1.4).

import Foundation
import RSCore

struct SimOptions {
    var count = 200
    var seed: UInt64 = 1
    var goldenOut: String?
    var goldenCount = 10
}

struct GoldenReplay: Codable {
    var seed: UInt64
    var finalStateHash: UInt64
    var winner: String
    var gammon: Bool
    var plies: Int
    var actions: [Action]
}

@MainActor
func usage() -> Never {
    FileHandle.standardError.write(Data("""
    usage: sim [--count N] [--seed S] [--golden-out DIR] [--golden-count N]

      --count N         play N random-legal matches (default 200)
      --seed S          base seed (default 1)
      --golden-out DIR  write --golden-count golden replay fixtures to DIR
      --golden-count N  number of golden replays (default 10)
    """.utf8))
    exit(2)
}

@MainActor
func intValue(_ raw: String) -> Int {
    guard let parsed = Int(raw) else { usage() }
    return parsed
}

@MainActor
func uintValue(_ raw: String) -> UInt64 {
    guard let parsed = UInt64(raw) else { usage() }
    return parsed
}

@MainActor
func parseOptions(_ arguments: [String]) -> SimOptions {
    var options = SimOptions()
    var index = 0
    while index < arguments.count {
        switch arguments[index] {
        case "--count":
            index += 1
            guard index < arguments.count else { usage() }
            options.count = intValue(arguments[index])
        case "--seed":
            index += 1
            guard index < arguments.count else { usage() }
            options.seed = uintValue(arguments[index])
        case "--golden-out":
            index += 1
            guard index < arguments.count else { usage() }
            options.goldenOut = arguments[index]
        case "--golden-count":
            index += 1
            guard index < arguments.count else { usage() }
            options.goldenCount = intValue(arguments[index])
        default:
            usage()
        }
        index += 1
    }
    return options
}

/// FNV-1a mixing for the combined run hash.
struct HashMixer {
    private var hash: UInt64 = 0xcbf2_9ce4_8422_2325

    mutating func mix(_ value: UInt64) {
        hash ^= value
        hash &*= 0x0000_0100_0000_01B3
    }

    var value: UInt64 { hash }
}

@MainActor
func runSummary(_ options: SimOptions) throws {
    var winsPlayer0 = 0
    var winsPlayer1 = 0
    var gammons = 0
    var totalPlies = 0
    var mixer = HashMixer()
    for index in 0..<options.count {
        let seed = options.seed &+ UInt64(index)
        let record = try RandomMatch.play(seed: seed)
        guard let outcome = record.finalState.outcome else {
            throw RuleError.illegalAction("completed match without outcome")
        }
        if outcome.winner == .player0 {
            winsPlayer0 += 1
        } else {
            winsPlayer1 += 1
        }
        if outcome.gammon { gammons += 1 }
        totalPlies += outcome.plies
        mixer.mix(record.finalState.stateHash)
    }
    let averagePlies = Double(totalPlies) / Double(max(options.count, 1))
    print("games: \(options.count)")
    print("player0 wins: \(winsPlayer0)")
    print("player1 wins: \(winsPlayer1)")
    print("gammons: \(gammons)")
    print("average plies: \(String(format: "%.2f", averagePlies))")
    print("FINAL HASH: \(mixer.value)")
}

@MainActor
func writeGoldenReplays(_ options: SimOptions) throws {
    let directory = URL(fileURLWithPath: options.goldenOut ?? "Fixtures")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    for index in 1...options.goldenCount {
        let seed = options.seed &+ UInt64(index)
        let record = try RandomMatch.play(seed: seed)
        guard let outcome = record.finalState.outcome else {
            throw RuleError.illegalAction("completed match without outcome")
        }
        let replay = GoldenReplay(
            seed: seed,
            finalStateHash: record.finalState.stateHash,
            winner: outcome.winner == .player0 ? "player0" : "player1",
            gammon: outcome.gammon,
            plies: outcome.plies,
            actions: record.actions
        )
        let file = directory.appendingPathComponent(String(format: "replay-%02d.json", index))
        let data = try encoder.encode(replay)
        try data.write(to: file)
        print("wrote \(file.path) (seed \(seed), \(outcome.plies) plies)")
    }
}

@MainActor
final class SimRunner {
    static func main() {
        do {
            let options = parseOptions(Array(CommandLine.arguments.dropFirst()))
            if options.goldenOut != nil {
                try writeGoldenReplays(options)
            } else {
                try runSummary(options)
            }
        } catch {
            FileHandle.standardError.write(Data("sim failed: \(error)\n".utf8))
            exit(1)
        }
    }
}

SimRunner.main()
