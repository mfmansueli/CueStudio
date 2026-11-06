//
//  ExportIntermediatesTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

extension RealExports {
    /// What a real export makes on the way (the float mix of more than the take's sound, ~384 KB a second, and the limited mix the
    /// video plays) goes once the video is written, and a cancelled export leaves nothing behind either; the media the edit plays
    /// stays where it is.
    @MainActor
    @Suite("Export intermediates", .serialized, .timeLimit(.minutes(3)))
    struct ExportIntermediatesTests {
        private static let prefixes = ["Cue-master-", Mixdown.filePrefix]

        private func intermediates() -> Set<String> {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: URL.temporaryDirectory.path(percentEncoded: false))) ?? []
            return Set(names.filter { name in Self.prefixes.contains { name.hasPrefix($0) } })
        }

        private func editWithMusic() async throws -> (clip: URL, edit: TakeEdit, cleanUp: () -> Void) {
            let clip = try await TestClip.make(seconds: 4, loudSeconds: [])
            let tone = try TestTone.make(seconds: 4, amplitude: 0.5)
            let file = try EditMediaFiles.newFile(pathExtension: tone.pathExtension)
            try FileManager.default.copyItem(at: tone, to: file.url)
            var edit = TakeEdit(sourceDuration: 4, aspect: .portrait)
            edit.voiceEnhancement = .off
            var music = MusicClip(fileName: file.name, title: "Tone", fileDuration: 4, start: 0, length: 4)
            music.volume = 1
            edit.music = [music]
            return (clip, edit, {
                try? FileManager.default.removeItem(at: clip)
                try? FileManager.default.removeItem(at: tone)
                EditMediaFiles.remove([file.name])
            })
        }

        @Test func aFinishedExportLeavesOnlyItsVideo() async throws {
            let made = try await editWithMusic()
            defer { made.cleanUp() }
            let before = intermediates()
            let output = try await VideoExportService().export(videoAt: made.clip, options: ExportOptions(aspect: .portrait, edit: made.edit))
            defer { try? FileManager.default.removeItem(at: output) }
            #expect(FileManager.default.fileExists(atPath: output.path(percentEncoded: false)))
            #expect(intermediates().subtracting(before).isEmpty)
            // The music the edit plays is the edit's: untouched.
            #expect(made.edit.missingMedia().isEmpty)
        }

        @Test func aCancelledExportStopsAndLeavesNothing() async throws {
            let made = try await editWithMusic()
            defer { made.cleanUp() }
            let before = intermediates()
            let exporter = VideoExportService()
            let task = Task { @MainActor in
                withUnsafeCurrentTask { $0?.cancel() }
                return try await exporter.export(videoAt: made.clip, options: ExportOptions(aspect: .portrait, edit: made.edit))
            }
            await #expect(throws: CancellationError.self) { _ = try await task.value }
            #expect(intermediates().subtracting(before).isEmpty)
            #expect(made.edit.missingMedia().isEmpty)
        }
    }
}
