import Foundation

/// Value-iteration solver for the Finkel-style race (RS-P1.4).
///
/// The kernel follows the published RoyalUr.net formulation: a chance node
/// averages over dice outcomes and a decision node maximises the rolling
/// player's win chance, with turn changes expressed by colour-flipping the
/// position (`1 − V[mirrored]`). Values are stored from the rolling
/// player's perspective, so the solved first-player win probability is the
/// value of the empty-board position with every piece waiting to enter.
///
/// Only the total of borne-off pieces changes a position's layer, so the
/// solve descends layers from last-bear-off to none; within a layer every
/// transition (advances, captures, passes) is iterated to convergence.
public struct UrSolver {

    public struct Report: Sendable, Equatable {
        public var pieces: Int
        public var totalPositions: Int
        public var layerCounts: [Int]
        public var sweepsPerLayer: [Int]
        public var maxDeltaPerLayer: [Double]
        public var initialWinProbability: Double
    }

    public enum SolveError: Error, CustomStringConvertible {
        case diverged(layer: Int, maxDelta: Double)

        public var description: String {
            switch self {
            case .diverged(let layer, let maxDelta):
                return "layer \(layer) did not converge (max delta \(maxDelta))"
            }
        }
    }

    public let ranking: UrRanking
    public let pieces: Int

    public init(pieces: Int) {
        precondition(pieces >= 1 && pieces <= 7)
        self.pieces = pieces
        self.ranking = UrRanking(pieces: pieces)
    }

    /// Runs value iteration to convergence and returns the values in the
    /// ranking's dense order.
    public func solve(
        maxSweepsPerLayer: Int = 20000,
        tolerance: Double = 1e-12,
        progress: ((Int, Int, Int, Double) -> Void)? = nil
    ) -> (values: [Double], report: Report) {
        var values = [Double](repeating: 0.5, count: ranking.totalPositions)
        var next = [Double](repeating: 0.5, count: ranking.totalPositions)
        var layerCounts = [Int]()
        var sweepsPerLayer = [Int]()
        var maxDeltas = [Double]()

        for layer in stride(from: ranking.layerCount - 1, through: 0, by: -1) {
            let start = ranking.layerStart[layer]
            let end = ranking.layerStart[layer + 1]
            layerCounts.append(end - start)
            guard end > start else {
                sweepsPerLayer.append(0)
                maxDeltas.append(0)
                continue
            }
            for index in start..<end { next[index] = values[index] }
            var sweeps = 0
            var maxDelta = 0.0
            repeat {
                sweeps += 1
                maxDelta = sweepLayer(layer: layer, read: values, write: &next)
                swap(&values, &next)
                if let progress = progress, sweeps % 20 == 0 {
                    progress(layer, sweeps, end - start, maxDelta)
                }
            } while maxDelta > tolerance && sweeps < maxSweepsPerLayer
            sweepsPerLayer.append(sweeps)
            maxDeltas.append(maxDelta)
        }

        let initial = UrPosition(
            shared: 0, private0: 0, private1: 0, hand0: pieces, hand1: pieces
        )
        let initialProbability = values[ranking.index(of: initial)]
        let report = Report(
            pieces: pieces,
            totalPositions: ranking.totalPositions,
            layerCounts: layerCounts,
            sweepsPerLayer: sweepsPerLayer,
            maxDeltaPerLayer: maxDeltas,
            initialWinProbability: initialProbability
        )
        return (values, report)
    }

    /// One Bellman update evaluated against an arbitrary value table, public
    /// so tests and the INV-5 checker can verify fixed points and probe the
    /// engine's move semantics against the solver's.
    public func bellman(position: UrPosition, values: [Double]) -> Double {
        update(position: position, read: values, ranking: ranking)
    }

    /// One Jacobi sweep. Work is partitioned by shared pattern, each chunk
    /// owns a disjoint slice of the write buffer, and every value is computed
    /// from the previous sweep's buffer, so the result is deterministic no
    /// matter how the chunks are scheduled.
    func sweepLayer(layer: Int, read: [Double], write: inout [Double]) -> Double {
        let start = ranking.layerStart[layer]
        let end = ranking.layerStart[layer + 1]
        let workers = 12
        var maxima = [Double](repeating: 0, count: workers)
        let ranking = self.ranking

        maxima.withUnsafeMutableBufferPointer { maxBuffer in
            write.withUnsafeMutableBufferPointer { writeBuffer in
                DispatchQueue.concurrentPerform(iterations: workers) { worker in
                    let patternsPerWorker = (6561 + workers - 1) / workers
                    let firstPattern = worker * patternsPerWorker
                    let lastPattern = min(6561, firstPattern + patternsPerWorker) - 1
                    guard firstPattern <= lastPattern else { return }
                    var localMax = 0.0
                    var position = UrPosition(
                        shared: 0, private0: 0, private1: 0,
                        hand0: 0, hand1: 0
                    )
                    for s in firstPattern...lastPattern {
                        let width = ranking.cumShared[layer][s + 1] - ranking.cumShared[layer][s]
                        if width == 0 { continue }
                        var index = start + ranking.cumShared[layer][s]
                        let n0 = ranking.sharedCount0(s)
                        let n1 = ranking.sharedCount1(s)
                        let packedShared = UrPosition.base3ToPacked[s]
                        position = UrPosition(
                            shared: packedShared, private0: 0, private1: 0, hand0: 0, hand1: 0)
                        for priv0 in 0..<64 {
                            let on0 = n0 + priv0.nonzeroBitCount
                            guard on0 <= ranking.pieces else { continue }
                            for priv1 in 0..<64 {
                                let pc1 = priv1.nonzeroBitCount
                                let on1 = n1 + pc1
                                guard on1 <= ranking.pieces else { continue }
                                guard
                                    let bounds = ranking.handPairBounds(
                                        on0, on1, layer
                                    )
                                else { continue }
                                let k = 2 * ranking.pieces - on0 - on1 - layer
                                for hand0 in bounds.low...bounds.high {
                                    position = UrPosition(
                                        shared: packedShared,
                                        private0: UInt32(priv0),
                                        private1: UInt32(priv1),
                                        hand0: hand0,
                                        hand1: k - hand0
                                    )
                                    let newValue = update(
                                        position: position, read: read, ranking: ranking)
                                    let delta = abs(newValue - read[index])
                                    if delta > localMax { localMax = delta }
                                    writeBuffer[index] = newValue
                                    index += 1
                                }
                            }
                        }
                        precondition(
                            index == start + ranking.cumShared[layer][s] + width,
                            "sweep lost count at shared \(s)")
                    }
                    maxBuffer[worker] = localMax
                }
            }
        }
        return maxima.reduce(0.0) { max($0, $1) }
    }

    /// The Bellman update for one position. The stored orientation's first
    /// player is always the player about to roll.
    func update(position: UrPosition, read: [Double], ranking: UrRanking) -> Double {
        let pieceCount = pieces
        // Terminal positions: a player with no pieces in hand and none on
        // board has borne off everything. If the roller finished, they have
        // won; if the opponent finished first, the roller has lost. The
        // all-off state (unreachable) keeps the mirror-symmetric pass value.
        let onBoard0 = position.privateCount0 + position.sharedCount0
        let onBoard1 = position.privateCount1 + position.sharedCount1
        if position.hand0 + onBoard0 == 0 && position.hand1 + onBoard1 > 0 {
            return 1.0
        }
        if position.hand1 + onBoard1 == 0 && position.hand0 + onBoard0 > 0 {
            return 0.0
        }

        let ownShared = UrPosition.sharedMask(player: 0, shared: position.shared)
        var ownMask = UInt16(position.private0 & 0xF)
        ownMask |= UInt16(ownShared) << 4
        ownMask |= UInt16((position.private0 >> 4) & 3) << 12

        let passValue = 1.0 - read[ranking.index(of: ranking.mirrored(position))]

        var total = 0.0
        for roll in 0...4 {
            let probability =
                Double(UrRanking.diceWeights[roll])
                / Double(UrRanking.diceDenominator)
            if roll == 0 {
                total += probability * passValue
                continue
            }
            var best = -Double.infinity

            // Entry (R-3): a roll of r brings a waiting piece to step r−1 — the
            // roll carries the piece in from off the board. Only the destination
            // square is checked; passed-over squares do not block.
            if position.hand0 > 0 {
                let destination = roll - 1
                if ownMask & (UInt16(1) << UInt16(destination)) == 0 {
                    let successor = UrPosition(
                        shared: position.shared,
                        private0: position.private0 | (1 << UInt32(destination)),
                        private1: position.private1,
                        hand0: position.hand0 - 1,
                        hand1: position.hand1
                    )
                    let value: Double
                    if destination == 3 {
                        // The entry rosette grants another roll.
                        value = read[ranking.index(of: successor)]
                    } else {
                        value = 1.0 - read[ranking.index(of: ranking.mirrored(successor))]
                    }
                    if value > best { best = value }
                }
            }

            var mask = ownMask
            while mask != 0 {
                let bit = mask.trailingZeroBitCount
                mask &= mask &- 1
                let source = Int(bit)
                let destination = source + roll
                if destination > UrRanking.trackLength { continue }

                var successorPrivate = position.private0
                var successorShared = position.shared
                var successorHand1 = position.hand1
                var isRosetteLanding = false

                // Clear the source.
                if source < 4 {
                    successorPrivate &= ~(1 << UInt32(source))
                } else if source >= 12 {
                    successorPrivate &= ~(1 << UInt32(source - 12 + 4))
                } else {
                    successorShared &= ~(UInt32(3) << UInt32((source - 4) * 2))
                }

                if destination == UrRanking.trackLength {
                    // Exact bear-off (R-7). If it was the last piece, the mover wins.
                    let onBoard = ownMask.nonzeroBitCount
                    let borneOff = pieceCount - position.hand0 - onBoard
                    if borneOff + 1 == pieceCount {
                        if 1.0 > best { best = 1.0 }
                        continue
                    }
                } else if destination < UrRanking.sharedStart {
                    if ownMask & (UInt16(1) << UInt16(destination)) != 0 { continue }
                    successorPrivate |= 1 << UInt32(destination)
                } else if destination < 12 {
                    let digitShift = UInt32((destination - 4) * 2)
                    let occupant = (position.shared >> digitShift) & 3
                    if occupant == 1 { continue }
                    if occupant == 2 {
                        if destination == UrRanking.safeRosette { continue }
                        successorHand1 += 1
                        // Remove the captured piece before occupying the square; OR-ing
                        // alone would leave the impossible digit 3 behind.
                        successorShared &= ~(UInt32(3) << digitShift)
                    }
                    successorShared |= UInt32(1) << digitShift
                    isRosetteLanding = destination == 7
                } else {
                    let privBit = UInt32(1) << UInt32(destination - 12 + 4)
                    if position.private0 & privBit != 0 { continue }
                    successorPrivate |= privBit
                    isRosetteLanding = destination == 13
                }

                // Rosette on a private start/exit square also grants another roll.
                if destination == 3 { isRosetteLanding = true }

                let successor = UrPosition(
                    shared: successorShared,
                    private0: successorPrivate,
                    private1: position.private1,
                    hand0: position.hand0,
                    hand1: successorHand1
                )
                let value: Double
                if isRosetteLanding {
                    value = read[ranking.index(of: successor)]
                } else {
                    value = 1.0 - read[ranking.index(of: ranking.mirrored(successor))]
                }
                if value > best { best = value }
            }

            if best == -Double.infinity {
                best = passValue
            }
            total += probability * best
        }
        return total
    }
}
