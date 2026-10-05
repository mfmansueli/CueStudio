//
//  MusicExportTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

extension RealExports {
    /// Music reaches the exported file where it's placed on the edit, and a loud mix (the take, music
    /// and a voice-over together) is brought under the ceiling instead of clipping.
    @MainActor
    @Suite("Music export", .serialized, .timeLimit(.minutes(3)))
    struct MusicExportTests {
        private func export(_ edit: TakeEdit, of clip: URL) async throws -> URL {
            try await VideoExportService().export(videoAt: clip, options: ExportOptions(aspect: .portrait, edit: edit))
        }

        /// Copies `url` into the app's media folder, as an import would.
        private func stored(_ url: URL) throws -> String {
            let file = try EditMediaFiles.newFile(pathExtension: url.pathExtension)
            try FileManager.default.copyItem(at: url, to: file.url)
            return file.name
        }

        @Test func musicIsHeardWhereItIsPlaced() async throws {
            let clip = try await TestClip.make(seconds: 4, loudSeconds: [])
            let tone = try TestTone.make(seconds: 6, amplitude: 0.5)
            let name = try stored(tone)
            defer {
                try? FileManager.default.removeItem(at: clip)
                try? FileManager.default.removeItem(at: tone)
                EditMediaFiles.remove([name])
            }
            var edit = TakeEdit(sourceDuration: 4, aspect: .portrait)
            edit.voiceEnhancement = .off
            var music = MusicClip(fileName: name, title: "Tone", fileDuration: 6, start: 1, length: 2)
            music.volume = 1
            music.fadeIn = 0
            music.fadeOut = 0
            music.ducksUnderVoice = false
            edit.music = [music]

            let output = try await export(edit, of: clip)
            defer { try? FileManager.default.removeItem(at: output) }
            #expect(try await TestClip.loudness(of: output, from: 0.1, to: 0.9) < -40)
            #expect(try await TestClip.loudness(of: output, from: 1.2, to: 2.8) > -20)
            #expect(try await TestClip.loudness(of: output, from: 3.2, to: 3.9) < -40)
        }

        @Test func aLoudMixNeverClips() async throws {
            let clip = try await TestClip.make(seconds: 3, loudSeconds: [0, 1, 2])
            let song = try TestTone.make(seconds: 3, amplitude: 0.95)
            let voice = try TestTone.make(seconds: 3, amplitude: 0.95)
            let songName = try stored(song), voiceName = try stored(voice)
            defer {
                for url in [clip, song, voice] { try? FileManager.default.removeItem(at: url) }
                EditMediaFiles.remove([songName, voiceName])
            }
            var edit = TakeEdit(sourceDuration: 3, aspect: .portrait)
            edit.voiceEnhancement = .off
            var music = MusicClip(fileName: songName, title: "Loud", fileDuration: 3, start: 0, length: 3)
            music.volume = 1
            music.fadeIn = 0
            music.fadeOut = 0
            music.ducksUnderVoice = false
            edit.music = [music]
            var narration = VoiceOverClip(fileName: voiceName, duration: 3, anchor: 0)
            narration.volume = 1
            edit.voiceOvers = [narration]

            let output = try await export(edit, of: clip)
            defer { try? FileManager.default.removeItem(at: output) }
            let sound = try await AudioTrackExtractor.extract(from: output)
            defer { try? FileManager.default.removeItem(at: sound) }
            // Together they'd reach about 2.2; the export stays under full scale.
            let peak = try AudioCeiling.peak(of: sound)
            #expect(peak < 0.99)
            #expect(peak > 0.5)
        }
    }
}
