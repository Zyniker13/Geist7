// sim.swift — S1.3: headless seeded playouts (the G1 `make sim` tool).
//
// Usage: sim N [--seed S] [--courtyard NAME] [--verbose] [--json]
//
// Plays N random-legal games from successive seeds (S, S+1, …), prints
// a summary (win split, plies, end conditions, law metrics), and the
// aggregate final-state hash chain. Exit 0 only when every game played
// legally to a finished state (0 crashes, 0 illegal states, INV-10
// spot checks included).

import DGCore
import Foundation

@main
struct SimTool {
    static func main() throws {
        let arguments = CommandLine.arguments.dropFirst()
        var count = 0
        var baseSeed: UInt64 = 1
        var verbose = false
        var json = false
        let mask: [String] = CourtyardFixtures.defaultMask
        let features: [Feature] = CourtyardFixtures.defaultFeatures
        let courtyardName = "long_wall"

        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--seed":
                if let value = iterator.next() {
                    baseSeed = UInt64(value) ?? 1
                }
            case "--verbose":
                verbose = true
            case "--json":
                json = true
            case "--courtyard":
                // P1 ships the built-in fixture courtyards only; the
                // name argument selects among them.
                if let value = iterator.next(), value != "long_wall" {
                    FileHandle.standardError.write(
                        Data("sim: unknown courtyard \(value); P1 ships long_wall\n".utf8))
                    exit(2)
                }
            default:
                if let parsed = Int(argument), parsed > 0 {
                    count = parsed
                } else {
                    FileHandle.standardError.write(
                        Data("sim: unknown argument \(argument)\n".utf8))
                    usage()
                    exit(2)
                }
            }
        }
        guard count > 0 else {
            usage()
            exit(2)
        }

        let courtyard = try Courtyard.parse(
            id: courtyardName, name: courtyardName, mask: mask,
            features: features, veranda: "bottom")

        let started = DispatchTime.now()
        var summaries: [PlayoutSummary] = []
        summaries.reserveCapacity(count)
        for offset in 0..<count {
            let seed = baseSeed &+ UInt64(offset)
            let summary = try Playout.play(
                seed: seed, courtyard: courtyard, balance: .standard())
            summaries.append(summary)
            if verbose {
                print(
                    "seed \(seed): \(summary.plies) plies, " +
                        "\(summary.placements) placements, " +
                        "\(summary.rakeMoves) rakes, " +
                        "\(summary.passes) passes, " +
                        "ended \(summary.endedBy), " +
                        "P\(summary.winner) wins " +
                        "\(summary.scores[.one] ?? 0)-\(summary.scores[.two] ?? 0)")
            }
        }
        let elapsed = DispatchTime.now().uptimeNanoseconds - started.uptimeNanoseconds

        // Aggregate hash chain: every game's final hash feeds one chain
        // so two runs of the tool compare byte-for-byte.
        var chain: UInt64 = 0xCBF2_9CE4_8422_2325
        for summary in summaries {
            chain ^= summary.finalHash
            chain = chain &* 0x0000_0100_0000_01B3
        }

        if json {
            let winsOne = summaries.filter { $0.winner == "one" }.count
            let winsTwo = summaries.filter { $0.winner == "two" }.count
            let totalPlies = summaries.reduce(0) { $0 + $1.plies }
            let totalRakes = summaries.reduce(0) { $0 + $1.rakeMoves }
            let printJSON: [String: String] = [
                "games": String(count),
                "winsOne": String(winsOne),
                "winsTwo": String(winsTwo),
                "meanPlies": String(
                    Double(totalPlies) / Double(max(1, count))),
                "meanRakes": String(
                    Double(totalRakes) / Double(max(1, count))),
                "hashChain": String(format: "%016llx", chain),
                "elapsedMs": String(
                    describing: Double(elapsed) / 1_000_000.0),
                "msPerGame": String(
                    describing: Double(elapsed) / 1_000_000.0 / Double(count)),
            ]
            let data = try JSONSerialization.data(
                withJSONObject: printJSON, options: [.sortedKeys])
            print(String(decoding: data, as: UTF8.self))
        } else {
            let winsOne = summaries.filter { $0.winner == "one" }.count
            let winsTwo = summaries.filter { $0.winner == "two" }.count
            let totalPlies = summaries.reduce(0) { $0 + $1.plies }
            let totalRakes = summaries.reduce(0) { $0 + $1.rakeMoves }
            let totalPasses = summaries.reduce(0) { $0 + $1.passes }
            let endedDouble = summaries.filter { $0.endedBy == "doublePass" }.count
            let endedMaterial = summaries.filter { $0.endedBy == "material" }.count
            let oddGroupDecisive = summaries.filter { summary in
                let bonusOne = 4 * max(0, summary.oddGroupsOne - 1)
                    + 9 * max(0, summary.oddGroupsOne - 2)
                    + 15 * max(0, summary.oddGroupsOne - 3)
                let bonusTwo = 4 * max(0, summary.oddGroupsTwo - 1)
                    + 9 * max(0, summary.oddGroupsTwo - 2)
                    + 15 * max(0, summary.oddGroupsTwo - 3)
                return bonusOne != bonusTwo
            }.count
            let margins = summaries.map { summary in
                abs((summary.scores[.one] ?? 0) - (summary.scores[.two] ?? 0))
            }.sorted()
            let medianMargin = margins.isEmpty ? 0 : margins[margins.count / 2]
            print("sim: \(count) games, courtyard \(courtyardName)")
            print("  wins P1 \(winsOne) / P2 \(winsTwo) (P1 rate \(String(format: "%.1f", 100.0 * Double(winsOne) / Double(count)))%)")
            print("  mean plies \(String(format: "%.1f", Double(totalPlies) / Double(count))), mean rakes \(String(format: "%.2f", Double(totalRakes) / Double(count))), passes \(totalPasses)")
            print("  ended: doublePass \(endedDouble), material \(endedMaterial)")
            print("  odd-group bonus present: \(oddGroupDecisive) games (\(String(format: "%.1f", 100.0 * Double(oddGroupDecisive) / Double(count)))%)")
            print("  median margin \(medianMargin) cells")
            print("  hash chain \(String(format: "%016llx", chain))")
            print("  \(String(format: "%.3f", Double(elapsed) / 1_000_000.0 / Double(count))) ms/game (\(String(format: "%.1f", Double(elapsed) / 1_000_000.0)) ms total)")
        }
    }

    static func usage() {
        FileHandle.standardError.write(
            Data("""
            usage: sim N [--seed S] [--verbose] [--json]
              N           number of random-legal games (required)
              --seed S    first seed (default 1; game i uses S+i)
            """.utf8))
    }
}
