import RSCore
import XCTest

@testable import RSAudio

final class RSAudioTests: XCTestCase {
    // MARK: - Synth determinism

    func testPluckedStringDeterministic() {
        let a = Synth.pluckedString(freq: 220, duration: 0.5, seed: 7)
        let b = Synth.pluckedString(freq: 220, duration: 0.5, seed: 7)
        XCTAssertEqual(a, b)
    }

    func testPluckedStringSeedChangesOutput() {
        let a = Synth.pluckedString(freq: 220, duration: 0.5, seed: 7)
        let b = Synth.pluckedString(freq: 220, duration: 0.5, seed: 8)
        XCTAssertNotEqual(a, b)
    }

    func testPluckedStringDecays() {
        let s = Synth.pluckedString(freq: 220, duration: 1.0, seed: 1)
        let half = s.count / 2
        let first = s[0..<half].reduce(0.0) { $0 + Double($1) * Double($1) }
        let second = s[half...].reduce(0.0) { $0 + Double($1) * Double($1) }
        XCTAssertLessThan(second, first)
    }

    func testFrameDrumDecays() {
        let s = Synth.frameDrum(freq: 180, duration: 0.35, seed: 1)
        let third = s.count / 3
        let early = s[0..<third].reduce(0.0) { $0 + Double($1) * Double($1) }
        let late = s[(2 * third)...].reduce(0.0) { $0 + Double($1) * Double($1) }
        XCTAssertLessThan(late, early)
    }

    func testReedPipeEnvelope() {
        let s = Synth.reedPipe(freq: 220, duration: 1.0, seed: 1)
        // Slow attack: the first 5 ms are near silence.
        let attack = s[0..<Int(0.005 * Synth.sampleRate)].reduce(0.0) { $0 + abs(Double($1)) }
        XCTAssertLessThan(attack / Double(s[0..<Int(0.005 * Synth.sampleRate)].count), 0.05)
        // The body is clearly audible.
        let mid = s[Int(0.4 * Synth.sampleRate)...Int(0.6 * Synth.sampleRate)]
        let midPeak = mid.reduce(0.0) { max($0, abs(Double($1))) }
        XCTAssertGreaterThan(midPeak, 0.05)
    }

    func testDiceRollAudible() {
        let s = Synth.diceRoll()
        XCTAssertFalse(s.isEmpty)
        let peak = s.reduce(0.0) { max($0, abs(Double($1))) }
        XCTAssertGreaterThan(peak, 0.01)
    }

    func testChimeNormalizedToPeak() {
        let s = Synth.chime(freq: 523.25)
        let peak = s.reduce(0.0) { max($0, abs(Double($1))) }
        XCTAssertEqual(peak, 0.5, accuracy: 0.001)
    }

    func testStingerAudibleAndBounded() {
        let s = Synth.stinger()
        XCTAssertFalse(s.isEmpty)
        let peak = s.reduce(0.0) { max($0, abs(Double($1))) }
        XCTAssertEqual(peak, 0.7, accuracy: 0.001)
    }

    func testAllInstrumentsFiniteAndBounded() {
        let buffers: [[Float]] = [
            Synth.pluckedString(freq: 146.83, duration: 0.9),
            Synth.frameDrum(),
            Synth.reedPipe(freq: 293.66, duration: 1.0),
            Synth.diceRoll(),
            Synth.chime(freq: 659.25, duration: 1.0),
            Synth.stinger(),
        ]
        for buffer in buffers {
            for sample in buffer {
                XCTAssertTrue(sample.isFinite)
                XCTAssertLessThanOrEqual(abs(sample), 1.0)
            }
        }
    }

    func testEmptyInputs() {
        XCTAssertTrue(Synth.pluckedString(freq: 220, duration: 0).isEmpty)
        XCTAssertTrue(Synth.pluckedString(freq: 0, duration: 0.5).isEmpty)
        XCTAssertTrue(Synth.frameDrum(duration: 0).isEmpty)
        XCTAssertTrue(Synth.reedPipe(freq: 220, duration: 0).isEmpty)
        XCTAssertTrue(Synth.diceRoll(duration: 0).isEmpty)
        XCTAssertTrue(Synth.chime(freq: 220, duration: 0).isEmpty)
    }

    // MARK: - Helpers

    func testNormalize() {
        var s: [Float] = [0.1, -0.2, 0.05]
        Synth.normalize(&s, peak: 0.5)
        let peak = s.reduce(0.0) { max($0, abs(Double($1))) }
        XCTAssertEqual(peak, 0.5, accuracy: 0.0001)
        // Signs preserved.
        XCTAssertLessThan(s[1], 0)
    }

    func testNormalizeAllZero() {
        var s: [Float] = [0, 0, 0]
        Synth.normalize(&s, peak: 0.5)
        XCTAssertEqual(s, [0, 0, 0])
    }

    func testMix() {
        var a: [Float] = [0, 0, 0, 0, 0]
        let b: [Float] = [1, 1]
        Synth.mix(&a, b, at: 1)
        XCTAssertEqual(a, [0, 1, 1, 0, 0])
        // Clamped at the end.
        var c: [Float] = [0, 0]
        Synth.mix(&c, [1, 1, 1], at: 1)
        XCTAssertEqual(c, [0, 1])
        // Negative offset clamps to the start; only the overlapping part lands.
        var d: [Float] = [0, 0, 0]
        Synth.mix(&d, [1, 1], at: -1)
        XCTAssertEqual(d, [1, 0, 0])
    }

    // MARK: - MusicScore

    func testTavernLoopDeterministic() {
        let a = MusicScore.tavernLoop.render(seed: 42)
        let b = MusicScore.tavernLoop.render(seed: 42)
        XCTAssertEqual(a, b)
    }

    func testTavernLoopSeedChangesOutput() {
        let a = MusicScore.tavernLoop.render(seed: 42)
        let b = MusicScore.tavernLoop.render(seed: 43)
        XCTAssertNotEqual(a, b)
    }

    func testTavernLoopLength() {
        let score = MusicScore.tavernLoop
        XCTAssertEqual(score.loopDuration, 8.0 * 4.0 * 60.0 / 84.0, accuracy: 0.0001)
        let rendered = score.render()
        let expected = Int((score.loopDuration + 1.0) * Synth.sampleRate)
        XCTAssertEqual(rendered.count, expected)
    }

    func testTavernLoopNotesStartInsideLoop() {
        for note in MusicScore.tavernLoop.notes {
            XCTAssertGreaterThanOrEqual(note.start, 0)
            XCTAssertLessThan(note.start, MusicScore.tavernLoop.loopDuration)
        }
    }

    func testTavernLoopUsesAllInstruments() {
        let instruments = Set(MusicScore.tavernLoop.notes.map { $0.instrument })
        XCTAssertEqual(instruments, Set(Instrument.allCases))
    }

    func testTavernLoopBounded() {
        let rendered = MusicScore.tavernLoop.render()
        let peak = rendered.reduce(0.0) { max($0, abs(Double($1))) }
        XCTAssertEqual(peak, 0.8, accuracy: 0.001)
        for sample in rendered {
            XCTAssertTrue(sample.isFinite)
        }
    }

    // MARK: - Event mapping

    func testEventMapping() {
        XCTAssertEqual(AudioController.sfx(for: .diceRolled(value: 3)), .dice)
        XCTAssertEqual(AudioController.sfx(for: .pieceCaptured(piece: 0, by: .player0)), .capture)
        XCTAssertEqual(AudioController.sfx(for: .rosetteLanded(player: .player0)), .rosette)
        XCTAssertEqual(
            AudioController.sfx(for: .matchWon(winner: .player0, gammon: false)), .matchEnd)
        XCTAssertNil(AudioController.sfx(for: .pieceMoved(piece: 0, from: 0, to: 1)))
        XCTAssertNil(AudioController.sfx(for: .pieceBorneOff(piece: 0, player: .player0)))
        XCTAssertNil(AudioController.sfx(for: .doubleOffered(by: .player0)))
        XCTAssertNil(AudioController.sfx(for: .cubeDoubled(newValue: 2, newOwner: .player0)))
        XCTAssertNil(AudioController.sfx(for: .conceded(by: .player0)))
        XCTAssertNil(AudioController.sfx(for: .omenPlayed(omenId: "omen", player: .player0)))
        XCTAssertNil(AudioController.sfx(for: .stakeSet(value: 10)))
        XCTAssertNil(AudioController.sfx(for: .turnPassed))
    }

    // MARK: - AudioController (headless-safe smoke)

    func testControllerInitHeadless() {
        // Must not crash on a machine without audio hardware.
        let controller = AudioController()
        XCTAssertFalse(controller.isRunning)
    }

    func testControllerMuteToggle() {
        let controller = AudioController()
        XCTAssertFalse(controller.isMuted)
        controller.isMuted = true
        XCTAssertTrue(controller.isMuted)
        controller.isMuted = false
        XCTAssertFalse(controller.isMuted)
    }

    func testControllerSfxNoOpWhenStopped() {
        let controller = AudioController()
        // Engine not running: all SFX paths are silent no-ops.
        for sfx in SFX.allCases {
            controller.playSFX(sfx)
        }
        controller.handle(events: [
            .diceRolled(value: 1), .pieceCaptured(piece: 0, by: .player0),
            .rosetteLanded(player: .player0), .matchWon(winner: .player0, gammon: false),
        ])
        // Still not running.
        XCTAssertFalse(controller.isRunning)
    }

    func testControllerStartStopMusic() {
        let controller = AudioController()
        controller.startMusic()
        controller.stopMusic()
        XCTAssertFalse(controller.isRunning)
    }
}
