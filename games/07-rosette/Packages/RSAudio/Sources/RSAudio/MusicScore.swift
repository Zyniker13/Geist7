// MARK: - MusicScore

import Foundation

/// The instruments available to a music score (RESEARCH.md §6).
public enum Instrument: String, CaseIterable, Sendable {
    case lyre
    case frameDrum
    case reed
}

/// One note in a music score (RS-P6.2).
public struct MusicNote: Equatable, Sendable {
    public let instrument: Instrument
    public let freq: Double
    public let start: Double
    public let duration: Double
    public let velocity: Double

    public init(
        instrument: Instrument,
        freq: Double,
        start: Double,
        duration: Double,
        velocity: Double = 1.0
    ) {
        self.instrument = instrument
        self.freq = freq
        self.start = start
        self.duration = duration
        self.velocity = velocity
    }
}

/// A deterministic music score: a list of notes on a fixed timeline.
///
/// Rendering a score is pure computation (Synth), so the same score and
/// seed always produce identical samples.
public struct MusicScore: Equatable, Sendable {
    public let tempo: Double
    public let bars: Int
    public let notes: [MusicNote]

    public init(tempo: Double, bars: Int, notes: [MusicNote]) {
        self.tempo = tempo
        self.bars = bars
        self.notes = notes
    }

    /// Seconds per beat (quarter note).
    public var secondsPerBeat: Double { 60.0 / tempo }

    /// Total loop duration in seconds (bars of 4/4).
    public var loopDuration: Double { Double(bars) * 4.0 * secondsPerBeat }

    /// Render the score to mono PCM samples at `Synth.sampleRate`.
    ///
    /// The buffer is `loopDuration + 1.0` seconds long so note releases
    /// can ring out; the extra tail is silent by construction of the
    /// envelopes.
    public func render(seed: UInt64 = 42) -> [Float] {
        let total = Int((loopDuration + 1.0) * Synth.sampleRate)
        var out = [Float](repeating: 0, count: total)
        for (index, note) in notes.enumerated() {
            let samples: [Float]
            switch note.instrument {
            case .lyre:
                samples = Synth.pluckedString(
                    freq: note.freq, duration: note.duration, seed: seed &+ UInt64(index)
                )
            case .frameDrum:
                samples = Synth.frameDrum(
                    freq: note.freq, duration: note.duration, seed: seed &+ UInt64(index)
                )
            case .reed:
                samples = Synth.reedPipe(
                    freq: note.freq, duration: note.duration, seed: seed &+ UInt64(index)
                )
            }
            let offset = Int(note.start * Synth.sampleRate)
            for i in 0..<samples.count where offset + i < total {
                out[offset + i] += samples[i] * Float(note.velocity)
            }
        }
        Synth.normalize(&out, peak: 0.8)
        return out
    }
}

extension MusicScore {
    /// The original tavern loop (RS-P6.2): 8 bars of 4/4 at 84 BPM in D
    /// Dorian — lyre arpeggios, a frame-drum backbeat, and a sparse reed
    /// melody. Reconstruction-inspired; no claim of authenticity.
    public static let tavernLoop: MusicScore = {
        let tempo: Double = 84
        let spb = 60.0 / tempo
        var notes: [MusicNote] = []

        // Frame drum: backbeat on beats 1 and 3, soft off-beat on even bars.
        for bar in 0..<8 {
            let barStart = Double(bar) * 4.0 * spb
            notes.append(
                MusicNote(
                    instrument: .frameDrum, freq: 180, start: barStart, duration: 0.35,
                    velocity: 1.0)
            )
            notes.append(
                MusicNote(
                    instrument: .frameDrum, freq: 160, start: barStart + 2.0 * spb, duration: 0.35,
                    velocity: 0.8)
            )
            if bar % 2 == 0 {
                notes.append(
                    MusicNote(
                        instrument: .frameDrum, freq: 200, start: barStart + 1.5 * spb,
                        duration: 0.2, velocity: 0.4
                    )
                )
            }
        }

        // Lyre: D-minor arpeggio (D F A D) on even bars, E-minor (E G B E) on odd.
        let even: [Double] = [146.83, 174.61, 220.00, 293.66]
        let odd: [Double] = [164.81, 196.00, 246.94, 329.63]
        for bar in 0..<8 {
            let barStart = Double(bar) * 4.0 * spb
            let scale = bar % 2 == 0 ? even : odd
            for (i, f) in scale.enumerated() {
                notes.append(
                    MusicNote(
                        instrument: .lyre, freq: f, start: barStart + Double(i) * spb,
                        duration: 0.9, velocity: 0.9
                    )
                )
            }
        }

        // Reed: a sparse melody over the 8 bars (D Dorian).
        // (bar, beat, length in beats)
        let melody: [(Int, Double, Double)] = [
            (0, 0, 2), (0, 3, 1), (1, 2, 2),
            (2, 0, 1), (2, 2, 2), (3, 3, 1),
            (4, 0, 2), (4, 3, 1), (5, 2, 2),
            (6, 0, 1), (6, 2, 2), (7, 3, 1),
        ]
        let scaleFreqs: [Double] = [220.00, 246.94, 261.63, 293.66, 329.63, 349.23, 392.00]
        for (bar, beat, len) in melody {
            let f = scaleFreqs[(bar * 3 + Int(beat)) % scaleFreqs.count]
            notes.append(
                MusicNote(
                    instrument: .reed, freq: f, start: Double(bar) * 4.0 * spb + beat * spb,
                    duration: len * spb + 0.2, velocity: 0.7
                )
            )
        }

        return MusicScore(tempo: tempo, bars: 8, notes: notes)
    }()
}
