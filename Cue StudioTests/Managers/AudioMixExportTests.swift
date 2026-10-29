//
//  AudioMixExportTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

extension RealExports {
    /// Phase 8's sound in a real export: music goes down by the decibels asked under a narration and only there, a voice effect
    /// is in the file and as loud as the voice, a clip with a speed curve and a voice effect keeps the curve's length and its
    /// pitch shift, and a spoken narration plays where it was added. Music is a 5 kHz tone and voices sit under 3 kHz, so each is
    /// measured on its own (Goertzel).
    @MainActor
    @Suite("Audio mix export", .serialized, .timeLimit(.minutes(4)))
    struct AudioMixExportTests {
        private func export(_ edit: TakeEdit, of clip: URL) async throws -> (samples: [Float], rate: Double) {
            let output = try await VideoExportService().export(videoAt: clip, options: ExportOptions(aspect: .portrait, edit: edit))
            defer { try? FileManager.default.removeItem(at: output) }
            let sound = try await AudioTrackExtractor.extract(from: output)
            defer { try? FileManager.default.removeItem(at: sound) }
            return try TestVoice.samples(of: sound)
        }

        private func stored(_ url: URL) throws -> String {
            let file = try EditMediaFiles.newFile(pathExtension: url.pathExtension)
            try FileManager.default.copyItem(at: url, to: file.url)
            return file.name
        }

        private func music(_ name: String, seconds: Double) -> MusicClip {
            var music = MusicClip(fileName: name, title: "High", fileDuration: seconds, start: 0, length: seconds)
            music.volume = 1
            music.fadeIn = 0
            music.fadeOut = 0
            return music
        }

        @Test func musicGoesDownByItsDepthUnderANarrationOnly() async throws {
            let clip = try await TestClip.make(seconds: 7, loudSeconds: [])
            let high = try TestTone.make(seconds: 7) { Float(0.3 * sin(2 * .pi * 5000 * $0)) }
            let voice = try TestVoice.make(seconds: 2)
            let highName = try stored(high), voiceName = try stored(voice)
            defer {
                for url in [clip, high, voice] { try? FileManager.default.removeItem(at: url) }
                EditMediaFiles.remove([highName, voiceName])
            }
            var edit = TakeEdit(sourceDuration: 7, aspect: .portrait)
            edit.voiceEnhancement = .off
            var lowered = music(highName, seconds: 7)
            lowered.duck = MusicDuck(depth: 20, pauses: .comesBack)
            edit.music = [lowered]
            edit.voiceOvers = [VoiceOverClip(fileName: voiceName, duration: 2, anchor: 2)]

            let sound = try await export(edit, of: clip)
            func toneLevel(from start: Double, to end: Double) -> Double {
                TestVoice.level(at: 5000, in: TestVoice.slice(sound.samples, rate: sound.rate, from: start, to: end), rate: sound.rate)
            }
            let before = toneLevel(from: 0.5, to: 1.5), under = toneLevel(from: 2.4, to: 3.6), after = toneLevel(from: 5.2, to: 6.5)
            #expect(abs((before - under) - 20) < 2)
            #expect(abs(before - after) < 1)
            #expect((sound.samples.map(abs).max() ?? 0) < 0.99)
        }

        @Test func aVoiceEffectIsInTheFileAndAsLoudAsTheVoice() async throws {
            let clip = try await TestClip.make(seconds: 4, loudSeconds: [])
            let voice = try TestVoice.make(seconds: 3)
            let voiceName = try stored(voice)
            defer {
                for url in [clip, voice] { try? FileManager.default.removeItem(at: url) }
                EditMediaFiles.remove([voiceName])
            }
            var edit = TakeEdit(sourceDuration: 4, aspect: .portrait)
            edit.voiceEnhancement = .off
            edit.voiceOvers = [VoiceOverClip(fileName: voiceName, duration: 3, anchor: 0.5)]
            let plain = try await export(edit, of: clip)
            edit.voiceOvers[0].voiceEffect = VoiceEffectSetting(effect: .radio, amount: 1)
            let radio = try await export(edit, of: clip)

            func level(_ sound: (samples: [Float], rate: Double), at frequency: Double) -> Double {
                TestVoice.level(at: frequency, in: TestVoice.slice(sound.samples, rate: sound.rate, from: 1, to: 3), rate: sound.rate)
            }
            // Radio takes the voice's low end off (150 Hz) and keeps its middle (1.5 kHz): brought back to the voice's loudness,
            // the middle comes up as the low end goes.
            #expect(level(plain, at: 150) - level(radio, at: 150) > 20)
            let plainTilt = level(plain, at: 1500) - level(plain, at: 150), radioTilt = level(radio, at: 1500) - level(radio, at: 150)
            #expect(radioTilt - plainTilt > 30)
            #expect(level(radio, at: 1500) >= level(plain, at: 1500))
            // … and the voice is as loud as it was.
            func rms(_ sound: (samples: [Float], rate: Double)) -> Double {
                let part = TestVoice.slice(sound.samples, rate: sound.rate, from: 1, to: 3)
                return 10 * log10(part.reduce(0) { $0 + Double($1 * $1) } / Double(part.count))
            }
            #expect(abs(rms(plain) - rms(radio)) < 3)
        }

        @Test func aCurvedClipWithAnEffectKeepsTheCurvesLengthAndItsPitch() async throws {
            let clip = try await TestClip.make(seconds: 6, loudSeconds: [0, 1, 2, 3, 4, 5])
            defer { try? FileManager.default.removeItem(at: clip) }
            var edit = TakeEdit(sourceDuration: 6, aspect: .portrait)
            edit.voiceEnhancement = .off
            var segment = try #require(edit.timeline.segments.first)
            let curve = SpeedCurve(points: [.init(position: 0, speed: 0.5), .init(position: 1, speed: 2)])
            segment.speedCurve = curve
            segment.voiceEffect = VoiceEffectSetting(effect: .chipmunk, amount: 1)
            let replaced = edit.timeline.replaceSegment(segment)
            #expect(replaced)

            let output = try await VideoExportService().export(videoAt: clip, options: ExportOptions(aspect: .portrait, edit: edit))
            defer { try? FileManager.default.removeItem(at: output) }
            let length = try await AVURLAsset(url: output).load(.duration).seconds
            #expect(abs(length - curve.editedLength(sourceLength: 6)) < 0.1)
            let soundURL = try await AudioTrackExtractor.extract(from: output)
            defer { try? FileManager.default.removeItem(at: soundURL) }
            let sound = try TestVoice.samples(of: soundURL)
            // The take's 440 Hz goes up 9 semitones (×1.68, 740 Hz) and stays there while the curve plays it.
            let middle = TestVoice.slice(sound.samples, rate: sound.rate, from: length * 0.3, to: length * 0.6)
            #expect(TestVoice.level(at: 740, in: middle, rate: sound.rate) - TestVoice.level(at: 440, in: middle, rate: sound.rate) > 15)
        }

        @Test func aSpokenNarrationPlaysWhereItWasAdded() async throws {
            let clip = try await TestClip.make(seconds: 5, loudSeconds: [])
            defer { try? FileManager.default.removeItem(at: clip) }
            let narration = SpokenNarration(text: "Uma narração curta para o teste.", voiceID: "pt.felipe", language: "pt-BR")
            let made = try await NarrationMaker.make(narration, speaker: FakeNarrationSpeaker())
            defer { EditMediaFiles.remove([made.fileName]) }
            var edit = TakeEdit(sourceDuration: 5, aspect: .portrait)
            edit.voiceEnhancement = .off
            var spoken = VoiceOverClip(fileName: made.fileName, duration: made.duration, anchor: 1.5)
            spoken.spoken = narration
            edit.voiceOvers = [spoken]

            let sound = try await export(edit, of: clip)
            func rms(from start: Double, to end: Double) -> Double {
                let part = TestVoice.slice(sound.samples, rate: sound.rate, from: start, to: end)
                return 10 * log10(max(1e-12, part.reduce(0) { $0 + Double($1 * $1) } / Double(part.count)))
            }
            #expect(rms(from: 0.2, to: 1.3) < -50)
            #expect(abs(rms(from: 1.8, to: 1.5 + made.duration - 0.2) - Double(NarrationMaker.speechLevel)) < 3)
        }
    }
}
