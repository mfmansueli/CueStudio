//
//  SoundEffectSynthTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

/// The sound effects Cue synthesizes (`SoundEffectSynth.synthesized`): each one is made (nothing silent, nothing clipping, the
/// same every time, long enough to sit on the music track and no longer than a moment), as loud as the rest, written to a file
/// that plays; and an effect reaches an exported video where it was placed, over music. The recorded ones and the groups:
/// `SoundEffectFilesTests`.
@Suite("Sound effects")
struct SoundEffectSynthTests {
    private var synthesized: [SoundEffect] { SoundEffect.allCases.filter(SoundEffectSynth.synthesized.contains) }

    @Test func everySynthesizedEffectIsMadeWithinItsPeakAndTheSameEveryTime() {
        #expect(!synthesized.isEmpty)
        for effect in synthesized {
            let samples = SoundEffectSynth.samples(for: effect)
            let finite = samples.allSatisfy { $0.isFinite }
            #expect(finite, "\(effect)")
            let peak = samples.map(abs).max() ?? 0
            #expect(peak <= SoundEffectSynth.peak + 0.000_01, "\(effect): \(peak)")
            let seconds = Double(samples.count) / SoundEffectSynth.sampleRate
            #expect(seconds >= Double(MusicClip.minimumDuration) - 0.001, "\(effect)")
            #expect(seconds <= 2.5, "\(effect): \(seconds) s")
            #expect(samples == SoundEffectSynth.samples(for: effect), "\(effect) is the same every time")
            // Real sound, not a few clicks: its energy is spread over some time.
            let loud = samples.filter { abs($0) > 0.05 }.count
            #expect(loud > 200, "\(effect): \(loud)")
            // Centred on zero: no offset pushing the speaker one way.
            let sounding = samples.lastIndex { $0 != 0 } ?? 0
            let mean = samples[...sounding].reduce(0.0) { $0 + Double($1) } / Double(sounding + 1)
            #expect(abs(mean) < 0.01 * Double(peak), "\(effect): \(mean)")
            let denormal = samples.contains { $0 != 0 && abs($0) < Float.leastNormalMagnitude }
            #expect(!denormal, "\(effect)")
        }
    }

    /// The meter reads what BS.1770 says: a 997 Hz sine at full scale on one channel is −3.01 LUFS, 20 dB down is −23.01.
    @Test func theLoudnessMeterReadsAToneAsTheStandardDoes() {
        let tone = (0..<48_000).map { Float(sin(2 * .pi * 997 * Double($0) / SoundEffectSynth.sampleRate)) }
        #expect(abs(SoundEffectSynth.loudness(of: tone) + 3.01) < 0.05)
        #expect(abs(SoundEffectSynth.loudness(of: tone.map { $0 * 0.1 }) + 23.01) < 0.05)
        #expect(SoundEffectSynth.loudness(of: [Float](repeating: 0, count: 100)) == -.infinity)
    }

    /// Every synthesized effect is as loud as the rest (its loudest 400 ms); one that would have to pass the peak for it (a short
    /// tick) is at the peak instead, never louder than the rest.
    @Test func everySynthesizedEffectIsEquallyLoudUnlessItsPeakStopsIt() {
        for effect in synthesized {
            let samples = SoundEffectSynth.samples(for: effect)
            let loudness = SoundEffectSynth.loudness(of: samples)
            #expect(loudness <= SoundEffectSynth.targetLoudness + 1.5, "\(effect): \(loudness) LUFS")
            if abs(loudness - SoundEffectSynth.targetLoudness) > 1.5 {
                let peak = samples.map(abs).max() ?? 0
                #expect(abs(peak - SoundEffectSynth.peak) < 0.001, "\(effect): \(loudness) LUFS, peak \(peak)")
            }
        }
    }

    /// Each one starts and ends in silence (fades of a millisecond or more), so none clicks as it begins or stops. Ding and Wrong
    /// are left out: they keep the sound they had before the fades were the rule.
    @Test func everySynthesizedEffectBeginsAndEndsWithoutAClick() {
        for effect in synthesized where effect != .ding && effect != .buzzer {
            let samples = SoundEffectSynth.samples(for: effect)
            let sounding = samples.lastIndex { $0 != 0 } ?? 0
            #expect(abs(samples[0]) < 0.01, "\(effect) starts at \(samples[0])")
            #expect(abs(samples[sounding]) < 0.01, "\(effect) ends at \(samples[sounding])")
        }
    }

    @Test func eachSynthesizedEffectsFilePlays() throws {
        for effect in synthesized {
            let url = try SoundEffectSynth.file(for: effect)
            #expect(url.lastPathComponent == "\(effect.rawValue)-v\(SoundEffect.version).caf")
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
            let name = try EditMediaFiles.link(try SoundEffectFiles.file(for: .boom))
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
