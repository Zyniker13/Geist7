// MARK: - Synth

import Foundation
import RSCore

/// Deterministic procedural synthesis for Rosette's audio (RS-P6.2).
///
/// Every instrument is generated from scratch in code — no samples, no
/// third-party assets — so the audio is identical on every run and on
/// every platform. The timbres are reconstruction-inspired (RESEARCH.md
/// §6): lyre-like plucked strings, frame drums, and reed pipes. No claim
/// of authentic ancient music is made.
public enum Synth {
    /// The sample rate of every rendered buffer (44.1 kHz).
    public static let sampleRate: Double = 44_100

    private static let twoPi: Double = 2.0 * Double.pi

    /// A uniform value in `[-1, 1)` from the seeded RNG.
    private static func unitRandom(_ rng: inout SeededRNG) -> Float {
        Float(rng.next(1 << 16)) / 32_768.0 - 1.0
    }

    // MARK: - Instruments

    /// A plucked string (lyre) via Karplus-Strong synthesis.
    ///
    /// - Parameters:
    ///   - freq: Fundamental frequency in Hz.
    ///   - duration: Duration in seconds.
    ///   - seed: Determinism seed (same seed → identical samples).
    public static func pluckedString(freq: Double, duration: Double, seed: UInt64 = 1) -> [Float] {
        let n = Int(duration * sampleRate)
        guard n > 0, freq > 0 else { return [] }
        let period = max(1, Int((sampleRate / freq).rounded()))
        // Excitation: a short noise burst through a one-pole lowpass.
        var rng = SeededRNG(seed: seed)
        var delay = [Float](repeating: 0, count: period)
        var last: Float = 0
        for i in 0..<period {
            last = 0.5 * (last + unitRandom(&rng))
            delay[i] = last
        }
        // Karplus-Strong loop with a gentle per-sample decay.
        var out = [Float](repeating: 0, count: n)
        var read = 0
        for i in 0..<n {
            let current = delay[read]
            let next = delay[(read + 1) % period]
            delay[read] = 0.996 * 0.5 * (current + next)
            out[i] = current
            read = (read + 1) % period
        }
        return out
    }

    /// A frame-drum hit: a pitch-dropping membrane thump with a short
    /// hand-noise attack.
    public static func frameDrum(freq: Double = 180, duration: Double = 0.35, seed: UInt64 = 1)
        -> [Float]
    {
        let n = Int(duration * sampleRate)
        guard n > 0 else { return [] }
        var rng = SeededRNG(seed: seed)
        var out = [Float](repeating: 0, count: n)
        var phase = 0.0
        let decay = Float(exp(-1.0 / (0.08 * sampleRate)))
        var amp: Float = 1.0
        let attackSamples = Int(0.012 * sampleRate)
        for i in 0..<n {
            // The membrane pitch drops over the first ~20 ms.
            let f = freq * (1.0 + 0.5 * exp(-Double(i) / (0.02 * sampleRate)))
            phase += twoPi * f / sampleRate
            var s = Float(sin(phase))
            if i < attackSamples {
                s += unitRandom(&rng)
            }
            out[i] = s * amp
            amp *= decay
        }
        normalize(&out, peak: 0.9)
        return out
    }

    /// A reed pipe: a breathy tone with harmonics, a slow attack, and
    /// gentle vibrato.
    public static func reedPipe(freq: Double, duration: Double, seed: UInt64 = 1) -> [Float] {
        let n = Int(duration * sampleRate)
        guard n > 0, freq > 0 else { return [] }
        var rng = SeededRNG(seed: seed)
        var out = [Float](repeating: 0, count: n)
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let attack = min(1.0, t / 0.08)
            let release = min(1.0, max(0.0, duration - t) / 0.1)
            let gate = attack * release
            let vibrato = 1.0 + 0.004 * sin(twoPi * 5.0 * t)
            phase += twoPi * freq * vibrato / sampleRate
            var s = sin(phase) + 0.35 * sin(2.0 * phase) + 0.12 * sin(3.0 * phase)
            s += 0.05 * Double(unitRandom(&rng))
            out[i] = Float(s * 0.25 * gate)
        }
        return out
    }

    /// Dice on wood (tavern ambience, RESEARCH.md §6): a rolling rumble
    /// with a handful of short clack transients.
    public static func diceRoll(duration: Double = 0.5, seed: UInt64 = 1) -> [Float] {
        let n = Int(duration * sampleRate)
        guard n > 0 else { return [] }
        var rng = SeededRNG(seed: seed)
        var out = [Float](repeating: 0, count: n)
        let clackCount = 4 + rng.next(3)
        var clacks = [Int]()
        for _ in 0..<clackCount {
            clacks.append(rng.next(Int(Double(duration) * 0.85 * sampleRate)))
        }
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let swell = min(1.0, t / 0.1) * min(1.0, max(0.0, duration - t) / 0.15)
            var s = 0.12 * unitRandom(&rng) * Float(swell)
            for clack in clacks where i >= clack && i < clack + 40 {
                let age = Float(i - clack)
                s += 0.5 * exp(-age / 8.0) * unitRandom(&rng)
            }
            out[i] = s
        }
        return out
    }

    /// A bell-like chime: inharmonic partials with exponential decay.
    public static func chime(freq: Double, duration: Double = 0.8, seed: UInt64 = 1) -> [Float] {
        let n = Int(duration * sampleRate)
        guard n > 0, freq > 0 else { return [] }
        var out = [Float](repeating: 0, count: n)
        // Inharmonic partial ratios (bell-like): 1, 2.01, 2.94, 4.2.
        let partials: [(ratio: Double, gain: Double)] = [
            (1.0, 1.0), (2.01, 0.5), (2.94, 0.25), (4.2, 0.12),
        ]
        for partial in partials {
            var phase = 0.0
            let decay = exp(-1.0 / (duration * 0.4 * sampleRate) * (partial.ratio > 2 ? 0.5 : 1.0))
            for i in 0..<n {
                phase += twoPi * freq * partial.ratio / sampleRate
                out[i] += Float(sin(phase) * partial.gain * pow(decay, Double(i)))
            }
        }
        normalize(&out, peak: 0.5)
        return out
    }

    /// A short dramatic hit for match end: a low drum under a low string.
    public static func stinger(seed: UInt64 = 1) -> [Float] {
        let duration = 1.2
        let n = Int(duration * sampleRate)
        var out = [Float](repeating: 0, count: n)
        let drum = frameDrum(freq: 90, duration: 0.6, seed: seed)
        let string = pluckedString(freq: 73.42, duration: 1.0, seed: seed &+ 1)  // D2
        for i in 0..<n {
            var s: Float = 0
            if i < drum.count { s += drum[i] * 0.8 }
            if i < string.count { s += string[i] * 0.6 }
            out[i] = s
        }
        normalize(&out, peak: 0.7)
        return out
    }

    // MARK: - Helpers

    /// Scale a buffer in place so its peak amplitude equals `peak`.
    public static func normalize(_ buffer: inout [Float], peak: Float) {
        let maxAbs = buffer.reduce(Float(0)) { max($0, abs($1)) }
        guard maxAbs > 0 else { return }
        let scale = peak / maxAbs
        for i in 0..<buffer.count { buffer[i] *= scale }
    }

    /// Mix `other` into `buffer` starting at `offset` samples (in place,
    /// clamped to the buffer bounds).
    public static func mix(_ buffer: inout [Float], _ other: [Float], at offset: Int) {
        let start = max(0, offset)
        let end = min(buffer.count, offset + other.count)
        guard end > start else { return }
        for i in start..<end {
            buffer[i] += other[i - offset]
        }
    }
}
