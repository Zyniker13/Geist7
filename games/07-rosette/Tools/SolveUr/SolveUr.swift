import Foundation
import RSCore

/// RS-P1.4 driver: solves the Finkel-style race by value iteration and
/// writes the solved table, its compressed variant, a JSON report, and
/// optionally a raw little-endian dump of the quantised values in the
/// ranking's dense order (for cross-checks against published tables).
@main
struct SolveUr {

    static func main() async throws {
        let args = Array(CommandLine.arguments.dropFirst())
        var pieces = 7
        var outputPath: String?
        var compressedPath: String?
        var reportPath: String?
        var dumpPath: String?
        var crossCheckPath: String?
        var rguSamplePath: String?
        var rguSampleOut: String?
        var rguSampleCount = 512
        var inv5Samples = 0
        var inv5Seed: UInt64 = 0x1D5D_1B47
        var tolerance = 1e-12
        var maxSweeps = 20000

        var i = 0
        while i < args.count {
            switch args[i] {
            case "--pieces":
                guard i + 1 < args.count, let v = Int(args[i + 1]) else {
                    print("error: --pieces requires an integer")
                    exit(1)
                }
                pieces = v
                i += 2
            case "--out":
                guard i + 1 < args.count else {
                    print("error: --out requires a path")
                    exit(1)
                }
                outputPath = args[i + 1]
                i += 2
            case "--compressed":
                guard i + 1 < args.count else {
                    print("error: --compressed requires a path")
                    exit(1)
                }
                compressedPath = args[i + 1]
                i += 2
            case "--report":
                guard i + 1 < args.count else {
                    print("error: --report requires a path")
                    exit(1)
                }
                reportPath = args[i + 1]
                i += 2
            case "--dump-values":
                guard i + 1 < args.count else {
                    print("error: --dump-values requires a path")
                    exit(1)
                }
                dumpPath = args[i + 1]
                i += 2
            case "--cross-check-rgu":
                guard i + 1 < args.count else {
                    print("error: --cross-check-rgu requires a path")
                    exit(1)
                }
                crossCheckPath = args[i + 1]
                i += 2
            case "--rgu-sample":
                guard i + 2 < args.count else {
                    print("error: --rgu-sample requires RGU_PATH OUT_PATH [COUNT]")
                    exit(1)
                }
                rguSamplePath = args[i + 1]
                rguSampleOut = args[i + 2]
                if i + 3 < args.count, !args[i + 3].hasPrefix("--"), let c = Int(args[i + 3]) {
                    rguSampleCount = c
                    i += 4
                } else {
                    i += 3
                }
            case "--inv5":
                guard i + 1 < args.count, let v = Int(args[i + 1]) else {
                    print("error: --inv5 requires a sample count")
                    exit(1)
                }
                inv5Samples = v
                i += 2
            case "--inv5-seed":
                guard i + 1 < args.count, let v = UInt64(args[i + 1]) else {
                    print("error: --inv5-seed requires an integer")
                    exit(1)
                }
                inv5Seed = v
                i += 2
            case "--tolerance":
                guard i + 1 < args.count, let v = Double(args[i + 1]) else {
                    print("error: --tolerance requires a number")
                    exit(1)
                }
                tolerance = v
                i += 2
            case "--max-sweeps":
                guard i + 1 < args.count, let v = Int(args[i + 1]) else {
                    print("error: --max-sweeps requires an integer")
                    exit(1)
                }
                maxSweeps = v
                i += 2
            case "--help", "-h":
                print(
                    """
                    Usage: SolveUr [options]
                      --pieces N         Number of pieces per player (1-7, default 7)
                      --out PATH         Write the table binary
                      --compressed PATH  Write the compressed table variant
                      --report PATH      Write a JSON report
                      --dump-values PATH Write raw little-endian UInt16 values (dense order)
                      --cross-check-rgu PATH  Verify solved values against a RoyalUr .rgu table
                      --rgu-sample RGU OUT [N]  Write N evenly-spaced (key, value) entries
                                            of an .rgu file to OUT as a JSON fixture
                      --inv5 N           Run the INV-5 engine-bridge probe on N random states
                      --inv5-seed S      Seed for the INV-5 sampler (default 0x1D5D1B47)
                      --tolerance D      Convergence tolerance (default 1e-12)
                      --max-sweeps N     Maximum sweeps per layer (default 20000)
                    """)
                return
            default:
                print("error: unknown option \(args[i])")
                exit(1)
            }
        }

        let solver = UrSolver(pieces: pieces)
        let label = "\(pieces)P"
        print("Solving \(label) ...")
        let start = Date()
        let (values, report) = solver.solve(
            maxSweepsPerLayer: maxSweeps,
            tolerance: tolerance
        ) { layer, sweep, count, delta in
            print("  layer \(layer) sweep \(sweep) / \(count) states, Δ=\(delta)")
        }
        let elapsed = Date().timeIntervalSince(start)
        print("Solved \(label) in \(elapsed) s")
        print("  positions: \(report.totalPositions)")
        print("  initial win probability: \(report.initialWinProbability)")

        let quantized = values.map { UInt16(max(0, min(65535, ($0 * 65535.0).rounded()))) }

        if let path = outputPath {
            let table = UrTable(
                pieces: pieces, values: quantized, layerStart: solver.ranking.layerStart
            )
            let data = table.serialized()
            try data.write(to: URL(fileURLWithPath: path))
            print("  wrote \(path) (\(data.count) bytes)")
        }

        if let path = compressedPath {
            let compressed = UrTableCodec.compress(quantized, layerStart: solver.ranking.layerStart)
            try compressed.write(to: URL(fileURLWithPath: path))
            print("  wrote \(path) (\(compressed.count) bytes)")
        }

        if let path = dumpPath {
            var data = Data(capacity: quantized.count * 2)
            for value in quantifiedLE(quantized) { data.append(value) }
            try data.write(to: URL(fileURLWithPath: path))
            print("  wrote \(path) (\(data.count) bytes)")
        }

        if let path = reportPath {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let reportData = try JSONEncoder().encode(CodableReport(from: report, seconds: elapsed))
            try reportData.write(to: URL(fileURLWithPath: path))
            print("  wrote report to \(path)")
        }

        if let path = crossCheckPath {
            let rgu = try UrRguCrossCheck.read(path: path)
            guard rgu.pieces == pieces else {
                print("error: rgu is for \(rgu.pieces) pieces, solving \(pieces)")
                exit(1)
            }
            let result = try UrRguCrossCheck.run(
                rgu: rgu, values: values, ranking: solver.ranking, verbose: true
            )
            print("  cross-check \(path): \(result.checked) entries, max |Δ| = \(result.maxDelta)")
        }

        if let rguPath = rguSamplePath, let outPath = rguSampleOut {
            try writeRguSample(
                rguPath: rguPath, outPath: outPath, count: rguSampleCount, pieces: pieces)
        }

        if inv5Samples > 0 {
            var rng = SeededRNG(seed: inv5Seed)
            let result = Inv5Check.run(
                solver: solver, values: values, samples: inv5Samples, rng: &rng)
            print("  INV-5 probe: \(result.checked) states, max |Δ| = \(result.maxDelta)")
            if let failure = result.failure {
                print("  INV-5 FAILURE: \(failure)")
                exit(1)
            }
            print("  INV-5 PASSED")
        }
    }

    /// Extracts an evenly-spaced sample of (key, value) entries from an .rgu
    /// file for the committed cross-check fixture.
    static func writeRguSample(
        rguPath: String, outPath: String, count: Int, pieces: Int
    ) throws {
        let rgu = try UrRguCrossCheck.read(path: rguPath)
        guard rgu.pieces == pieces else {
            print("error: rgu is for \(rgu.pieces) pieces, sampling for \(pieces)")
            exit(1)
        }
        struct Entry: Codable {
            var k: UInt32
            var v: UInt16
        }
        struct Sample: Codable {
            var source: String
            var upstreamLicense: String
            var upstreamAuthor: String
            var pieces: Int
            var upstreamEntries: Int
            var entries: [Entry]
        }
        var keys: [UInt32] = []
        var raws: [UInt16] = []
        for map in rgu.maps {
            keys.append(contentsOf: map.keys)
            raws.append(contentsOf: map.values)
        }
        let total = keys.count
        var entries = [Entry]()
        if total > 0 {
            for sampleIndex in 0..<count {
                let position = (sampleIndex * total) / count
                entries.append(Entry(k: keys[position], v: raws[position]))
            }
        }
        let sample = Sample(
            source: "RoyalUr.net solved two-piece table (finkel2p.rgu), sothatsit/RoyalUrModels",
            upstreamLicense: "MIT",
            upstreamAuthor: "Padraig Lamont / RoyalUr contributors",
            pieces: pieces,
            upstreamEntries: total,
            entries: entries
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(sample)
        try data.write(to: URL(fileURLWithPath: outPath))
        print("  wrote \(outPath) (\(entries.count) of \(total) entries)")
    }

    static func quantifiedLE(_ values: [UInt16]) -> [UInt8] {
        var bytes = [UInt8]()
        bytes.reserveCapacity(values.count * 2)
        for value in values {
            bytes.append(UInt8(truncatingIfNeeded: value))
            bytes.append(UInt8(truncatingIfNeeded: value >> 8))
        }
        return bytes
    }
}

/// A JSON-friendly mirror of UrSolver.Report.
struct CodableReport: Codable {
    var pieces: Int
    var totalPositions: Int
    var layerCounts: [Int]
    var sweepsPerLayer: [Int]
    var maxDeltaPerLayer: [Double]
    var initialWinProbability: Double
    var seconds: Double

    init(from report: UrSolver.Report, seconds: Double) {
        pieces = report.pieces
        totalPositions = report.totalPositions
        layerCounts = report.layerCounts
        sweepsPerLayer = report.sweepsPerLayer
        maxDeltaPerLayer = report.maxDeltaPerLayer
        initialWinProbability = report.initialWinProbability
        self.seconds = seconds
    }
}
