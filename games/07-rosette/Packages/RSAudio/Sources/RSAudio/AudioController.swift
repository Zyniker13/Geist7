// MARK: - AudioController

import AVFoundation
import Foundation
import RSCore

/// The one-shot sound effects the game plays (RS-P6.2).
public enum SFX: String, CaseIterable, Sendable {
    case dice
    case capture
    case rosette
    case matchEnd
    case click
}

/// The audio controller: an AVAudioEngine graph with a looping music node
/// and a small SFX pool of AVAudioPlayerNodes (per _CONVENTIONS.md §2).
///
/// All audio is synthesized in code (Synth/MusicScore); nothing is loaded
/// from disk. The controller is defensive: on a machine without audio
/// hardware (e.g. CI runners) it degrades to a silent no-op instead of
/// failing. Use it from the main thread.
public final class AudioController {
    private let engine = AVAudioEngine()
    private let musicNode = AVAudioPlayerNode()
    private var sfxNodes: [AVAudioPlayerNode] = []
    private var sfxIndex = 0
    private var musicBuffer: AVAudioPCMBuffer?
    private var sfxBuffers: [SFX: AVAudioPCMBuffer] = [:]
    private var buffersReady = false
    private var volume: Float = 0.5

    /// The music score currently scheduled (or about to be scheduled).
    public private(set) var score: MusicScore = .tavernLoop

    public init() {
        // Player nodes connect at mono (matching the synthesized buffers);
        // the main mixer upmixes to the hardware output format.
        let format = AVAudioFormat(standardFormatWithSampleRate: Synth.sampleRate, channels: 1)
        engine.attach(musicNode)
        if let format {
            engine.connect(musicNode, to: engine.mainMixerNode, format: format)
        }
        for _ in 0..<4 {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            if let format {
                engine.connect(node, to: engine.mainMixerNode, format: format)
            }
            sfxNodes.append(node)
        }
    }

    /// Render the music and SFX buffers once, on first use (keeps init
    /// cheap; synthesis takes a few hundred milliseconds).
    private func ensureBuffers() {
        guard !buffersReady else { return }
        makeBuffers()
        buffersReady = true
    }

    // MARK: - Music

    /// Start the engine and loop the current score. No-op if already
    /// running or if the engine cannot start (no audio hardware).
    public func startMusic(score: MusicScore = .tavernLoop, seed: UInt64 = 42) {
        self.score = score
        if musicBuffer == nil {
            musicBuffer = Self.makeBuffer(score.render(seed: seed))
        }
        guard !engine.isRunning else {
            musicNode.play()
            return
        }
        do {
            try engine.start()
        } catch {
            // No audio hardware (e.g. CI): stay silent.
            return
        }
        guard let buffer = musicBuffer else { return }
        musicNode.volume = volume
        musicNode.scheduleBuffer(buffer, at: nil, options: .loops)
        musicNode.play()
    }

    /// Stop the music and the engine.
    public func stopMusic() {
        musicNode.stop()
        if engine.isRunning {
            engine.stop()
        }
    }

    /// Whether the engine is currently running.
    public var isRunning: Bool { engine.isRunning }

    // MARK: - SFX

    /// Play a one-shot sound effect from the pool. No-op if the engine is
    /// not running.
    public func playSFX(_ sfx: SFX) {
        guard engine.isRunning else { return }
        ensureBuffers()
        guard let buffer = sfxBuffers[sfx] else { return }
        let node = sfxNodes[sfxIndex]
        sfxIndex = (sfxIndex + 1) % sfxNodes.count
        node.volume = volume
        node.scheduleBuffer(buffer, at: nil, options: [])
        if !node.isPlaying {
            node.play()
        }
    }

    /// Map a reducer event to the SFX it should trigger (pure; the
    /// rendering layer subscribes to `[Event]` and never infers rules).
    public static func sfx(for event: Event) -> SFX? {
        switch event {
        case .diceRolled:
            return .dice
        case .pieceCaptured:
            return .capture
        case .rosetteLanded:
            return .rosette
        case .matchWon:
            return .matchEnd
        case .pieceMoved, .pieceBorneOff, .doubleOffered, .cubeDoubled, .conceded, .omenPlayed,
            .stakeSet, .turnPassed:
            return nil
        }
    }

    /// Play the SFX for each event in a reducer event batch.
    public func handle(events: [Event]) {
        for event in events {
            if let sfx = Self.sfx(for: event) {
                playSFX(sfx)
            }
        }
    }

    // MARK: - Volume

    /// Mute/unmute all audio.
    public var isMuted: Bool {
        get { volume == 0 }
        set {
            volume = newValue ? 0 : 0.5
            musicNode.volume = volume
            for node in sfxNodes {
                node.volume = volume
            }
        }
    }

    // MARK: - Buffers

    private func makeBuffers() {
        var buffers: [SFX: AVAudioPCMBuffer] = [:]
        func add(_ key: SFX, _ samples: [Float]) {
            if let buffer = Self.makeBuffer(samples) {
                buffers[key] = buffer
            }
        }
        add(.dice, Synth.diceRoll())
        add(.capture, Synth.chime(freq: 523.25))
        add(.rosette, Synth.chime(freq: 659.25, duration: 1.0))
        add(.matchEnd, Synth.stinger())
        add(.click, Synth.frameDrum(freq: 300, duration: 0.12))
        sfxBuffers = buffers
        if musicBuffer == nil {
            musicBuffer = Self.makeBuffer(score.render())
        }
    }

    private static func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty,
            let format = AVAudioFormat(standardFormatWithSampleRate: Synth.sampleRate, channels: 1),
            let buffer = AVAudioPCMBuffer(
                pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))
        else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        if let channel = buffer.floatChannelData?[0] {
            for (i, s) in samples.enumerated() {
                channel[i] = s
            }
        }
        return buffer
    }
}
