import Foundation

/// Ranking and geometry for the solver's position space.
///
/// Positions are enumerated in a fixed nested order — shared pattern, first
/// player's private bitmap, second player's private bitmap, then the valid
/// hand-count pairs — which gives every position a dense index without a
/// hash map. Layers group positions by the total number of borne-off
/// pieces; a layer only reads itself and higher layers, so the solve runs
/// one layer at a time.
public struct UrRanking {

    /// Pieces per player (1…7). The Finkel ruleset uses 7.
    public let pieces: Int

    /// Path steps 0–3 are private starts, 4–11 shared, 12–13 private exits.
    public static let sharedStart = 4
    public static let sharedCount = 8
    public static let trackLength = 14

    /// Rosette steps that grant an extra roll (R-6, R-19): the last start
    /// square, the middle shared square, and the last exit square.
    public static let rosettes: Set<Int> = [3, 7, 13]
    /// The central rosette is the only shared one, so it is the only square
    /// where a capture can be blocked (R-5); rosettes on private squares can
    /// never hold an enemy piece.
    public static let safeRosette = 7

    /// Tetra4 dice: four binary tetrahedra, values 0…4 (R-2).
    public static let diceWeights: [Int] = [1, 4, 6, 4, 1]
    public static let diceDenominator = 16

    /// Cumulative count of positions with a shared pattern below `s`, per
    /// layer; `[layer][s]` with `sharedPatterns + 1` entries per layer.
    public let cumShared: [[Int]]

    /// Term A of the within-shared offset:
    /// `[layer][shared][privatePopcount0]`.
    public let termA: [[[Int]]]

    /// Term B of the within-shared offset:
    /// `[layer][shared][privatePopcount0][privatePopcount1]`.
    public let termB: [[[[Int]]]]

    /// Layer offsets into the dense index space; `layerCount + 1` entries.
    public let layerStart: [Int]

    private let privPrefix: [[Int]]
    private let sharedN0: [Int]
    private let sharedN1: [Int]
    private let binom6 = [1, 6, 15, 20, 15, 6, 1]

    public var layerCount: Int { 2 * pieces + 1 }
    public var totalPositions: Int { layerStart[layerCount] }
    public static var sharedPatterns: Int { 6561 }

    public init(pieces: Int) {
        precondition(pieces >= 1 && pieces <= 7)
        self.pieces = pieces
        let P = pieces

        // privPrefix[a][pc] = number of bitmaps b < a with popcount(b) = pc.
        var prefix = [[Int]](repeating: [Int](repeating: 0, count: 7), count: 64)
        for a in 0..<64 {
            for b in 0..<a {
                prefix[a][b.nonzeroBitCount] += 1
            }
        }
        self.privPrefix = prefix

        var n0Table = [Int](repeating: 0, count: 6561)
        var n1Table = [Int](repeating: 0, count: 6561)
        for s in 0..<6561 {
            var n0 = 0
            var n1 = 0
            var value = s
            for _ in 0..<8 {
                switch value % 3 {
                case 1: n0 += 1
                case 2: n1 += 1
                default: break
                }
                value /= 3
            }
            n0Table[s] = n0
            n1Table[s] = n1
        }
        self.sharedN0 = n0Table
        self.sharedN1 = n1Table

        // Number of valid hand pairs (h0, h1) with h0 + h1 = k, h0 ≤ P − on0
        // and h1 ≤ P − on1 (borne-off counts stay non-negative).
        func handPairs(on0: Int, on1: Int, layer: Int) -> Int {
            let k = 2 * P - on0 - on1 - layer
            guard k >= 0, k <= 2 * P else { return 0 }
            let low = max(0, k - (P - on1))
            let high = min(k, P - on0)
            return high >= low ? high - low + 1 : 0
        }
        self.handPairBounds = { (on0, on1, layer) in
            let k = 2 * P - on0 - on1 - layer
            guard k >= 0, k <= 2 * P else { return nil }
            let low = max(0, k - (P - on1))
            let high = min(k, P - on0)
            guard high >= low else { return nil }
            return (low, high)
        }

        let layers = 2 * P + 1
        var cum = [[Int]](repeating: [Int](repeating: 0, count: 6562), count: layers)
        var a = [[[Int]]]()
        var b = [[[[Int]]]]()
        var starts = [Int](repeating: 0, count: layers + 1)

        var running = 0
        for layer in 0..<layers {
            starts[layer] = running
            var cumLayer = [Int](repeating: 0, count: 6562)
            var layerA = [[Int]]()
            var layerB = [[[Int]]]()
            for s in 0..<6561 {
                let n0 = n0Table[s]
                let n1 = n1Table[s]
                var g = [Int](repeating: 0, count: 7)
                var rows = [[Int]](repeating: [Int](repeating: 0, count: 7), count: 7)
                var count = 0
                for pc0 in 0...6 {
                    let on0 = n0 + pc0
                    guard on0 <= P else { continue }
                    var row = [Int](repeating: 0, count: 7)
                    var gValue = 0
                    for pc1 in 0...6 {
                        let on1 = n1 + pc1
                        guard on1 <= P else { continue }
                        let pairsHere = handPairs(on0: on0, on1: on1, layer: layer)
                        guard pairsHere > 0 else { continue }
                        // Per-priv1-bitmap weight: only the hand-pair count — the
                        // bitmap-population factor lives in privPrefix, not here.
                        row[pc1] = pairsHere
                        gValue += binom6[pc1] * pairsHere
                    }
                    g[pc0] = gValue
                    rows[pc0] = row
                    count += binom6[pc0] * gValue
                }
                cumLayer[s] = count
                layerA.append(g)
                layerB.append(rows)
            }
            var runningSum = 0
            for s in 0..<6561 {
                cum[layer][s] = runningSum
                runningSum += cumLayer[s]
            }
            cum[layer][6561] = runningSum
            running += runningSum
            a.append(layerA)
            b.append(layerB)
            starts[layer + 1] = running
        }
        self.cumShared = cum
        self.termA = a
        self.termB = b
        self.layerStart = starts
    }

    public let handPairBounds: (Int, Int, Int) -> (low: Int, high: Int)?

    /// Number of first-player pieces on the shared squares of pattern `s`.
    public func sharedCount0(_ s: Int) -> Int { sharedN0[s] }
    /// Number of second-player pieces on the shared squares of pattern `s`.
    public func sharedCount1(_ s: Int) -> Int { sharedN1[s] }

    /// Layer of a position: total borne-off pieces.
    public func layer(of position: UrPosition) -> Int {
        let on0 = position.sharedCount0 + position.privateCount0
        let on1 = position.sharedCount1 + position.privateCount1
        return 2 * pieces - position.hand0 - position.hand1 - on0 - on1
    }

    /// Dense index of a valid position.
    public func index(of position: UrPosition) -> Int {
        let layer = layer(of: position)
        return layerStart[layer] + innerIndex(position, layer: layer)
    }

    /// Index of a position within its own layer.
    public func innerIndex(_ position: UrPosition, layer: Int) -> Int {
        let s = UrPosition.packedToBase3[Int(position.shared)]
        precondition(s >= 0, "position holds an impossible shared digit")
        let priv0 = Int(position.private0)
        let priv1 = Int(position.private1)
        let pc0 = priv0.nonzeroBitCount
        let pc1 = priv1.nonzeroBitCount
        let on0 = sharedN0[s] + pc0
        let on1 = sharedN1[s] + pc1

        var base = cumShared[layer][s]
        let aRow = termA[layer][s]
        for pc in 0...6 {
            let count = privPrefix[priv0][pc]
            if count != 0 { base += count * aRow[pc] }
        }
        let bRow = termB[layer][s][pc0]
        for pc in 0...6 {
            let count = privPrefix[priv1][pc]
            if count != 0 { base += count * bRow[pc] }
        }
        if let bounds = handPairBounds(on0, on1, layer) {
            base += position.hand0 - bounds.low
        }
        return base
    }

    /// The colour-swapped position: the other player becomes "player 0".
    public func mirrored(_ position: UrPosition) -> UrPosition {
        var shared: UInt32 = 0
        for index in 0..<8 {
            let digit = position.sharedDigit(index)
            // Swap the players (1 ↔ 2); empty and the packed both-players digit
            // are fixed points, which keeps the mirror an involution on the
            // whole 13-bit shared field.
            let flipped: UInt32 = digit == 1 ? 2 : (digit == 2 ? 1 : digit)
            shared |= flipped << UInt32(index * 2)
        }
        return UrPosition(
            shared: shared,
            private0: position.private1,
            private1: position.private0,
            hand0: position.hand1,
            hand1: position.hand0
        )
    }
}
