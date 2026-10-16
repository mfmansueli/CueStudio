//
//  SoundEffectSynthTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

/// Cue's own sound effects: each one is made (nothing silent, nothing clipping, the same every time, long enough to sit on the
/// music track), written to a file that plays, and reaches an exported video where it was placed, over music.
@Suite("Sound effects")
struct SoundEffectSynthTests {
    @Test func everyEffectIsMadeAtItsLevelAndTheSameEveryTime() {
        for effect in SoundEffect.allCases {
            let samples = SoundEffectSynth.samples(for: effect)
            let finite = samples.allSatisfy { $0.isFinite }
            #expect(finite, "\(effect)")
            let peak = samples.map(abs).max() ?? 0
            #expect(abs(peak - SoundEffectSynth.peak) < 0.001, "\(effect): \(peak)")
            #expect(Double(samples.count) / SoundEffectSynth.sampleRate >= Double(MusicClip.minimumDuration) - 0.001, "\(effect)")
            #expect(samples == SoundEffectSynth.samples(for: effect), "\(effect) is the same every time")
            // Real sound, not a few clicks: its energy is spread over some time.
            let loud = samples.filter { abs($0) > 0.05 }.count
            #expect(loud > 200, "\(effect): \(loud)")
        }
    }

    @Test func eachEffectsFilePlays() throws {
        for effect in SoundEffect.allCases {
            let url = try SoundEffectSynth.file(for: effect)
            let file = try AVAudioFile(forReading: url)
            #expect(file.length == AVAudioFramePosition(SoundEffectSynth.samples(for: effect).count))
            #expect(file.fileFormat.sampleRate == SoundEffectSynth.sampleRate)
        }
    }
}

extension RealExports {
    @MainActor
    @Suite("Sound effect export", .serialized, .timeLimit(.minutes(5)))
    struct SoundEffectExportTests {
        @Test func anEffectIsHeardWhereItWasPutOverMusic() async throws {
            let clip = try await TestClip.make(seconds: 4, loudSeconds: [])
            defer { try? FileManager.default.removeItem(at: clip) }
            let name = try EditMediaFiles.link(try SoundEffectSynth.file(for: .boom))
            defer { EditMediaFiles.remove([name]) }
            var edit = TakeEdit(sourceDuration: 4, aspect: .portrait)
            edit.voiceEnhancement = .off
            var boom = MusicClip(fileName: name, title: "Boom", fileDuration: 1.4, start: 2, length: 1.4)
            boom.effect = .boom
            boom.volume = 1
            boom.fadeIn = 0
            boom.fadeOut = 0
            boom.ducksUnderVoice = false
            edit.music = [boom]
            let output = try await VideoExportService(sounds: RecordingSoundCache()).export(
                videoAt: clip, options: ExportOptions(aspect: .portrait, edit: edit)
            )
            defer { try? FileManager.default.removeItem(at: output) }
            #expect(try await TestClip.loudness(of: output, from: 0.2, to: 1.8) < -40)
            #expect(try await TestClip.loudness(of: output, from: 2.0, to: 2.5) > -30)
        }
    }
}
