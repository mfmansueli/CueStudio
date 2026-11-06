//
//  ExportStagesTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

extension RealExports {
    /// A real export tells its stages as they come: preparing, the sound (Studio Voice and the mix, without a number), then the frames
    /// from 0 to 1 as the session measures them; never an invented percentage, and never back to an earlier stage.
    @MainActor
    @Suite("Export stages", .serialized, .timeLimit(.minutes(3)))
    struct ExportStagesTests {
        @Test func anEditWithMusicGoesThroughItsRealStages() async throws {
            let clip = try await TestClip.make(seconds: 3, loudSeconds: [])
            let tone = try TestTone.make(seconds: 3, amplitude: 0.5)
            let file = try EditMediaFiles.newFile(pathExtension: tone.pathExtension)
            try FileManager.default.copyItem(at: tone, to: file.url)
            defer {
                try? FileManager.default.removeItem(at: clip)
                try? FileManager.default.removeItem(at: tone)
                EditMediaFiles.remove([file.name])
            }
            var edit = TakeEdit(sourceDuration: 3, aspect: .portrait)
            var music = MusicClip(fileName: file.name, title: "Tone", fileDuration: 3, start: 0, length: 3)
            music.volume = 1
            edit.music = [music]
            var heard: [ExportProgress] = []
            let output = try await VideoExportService().export(videoAt: clip, options: ExportOptions(aspect: .portrait, edit: edit)) {
                heard.append($0)
            }
            defer { try? FileManager.default.removeItem(at: output) }
            #expect(heard.first == .preparing)
            #expect(heard.contains(ExportProgress(.sound)))
            #expect(!heard.contains { $0.stage == .motion || $0.stage == .fonts }, "Nothing to analyze or download")
            #expect(heard.last == ExportProgress(.rendering, fraction: 1))
            #expect(zip(heard, heard.dropFirst()).allSatisfy { $0.stage <= $1.stage })
            // Only the frames have a number.
            #expect(heard.allSatisfy { ($0.fraction != nil) == ($0.stage == .rendering) })
        }

        @Test func aTakeOnlyCroppedHasNoSoundStage() async throws {
            let clip = try await TestClip.make(seconds: 2, loudSeconds: [])
            defer { try? FileManager.default.removeItem(at: clip) }
            var heard: [ExportProgress] = []
            let output = try await VideoExportService().export(videoAt: clip, options: ExportOptions(aspect: .vertical)) { heard.append($0) }
            defer { try? FileManager.default.removeItem(at: output) }
            #expect(heard.first == .preparing)
            #expect(!heard.contains { $0.stage == .sound })
        }
    }
}
