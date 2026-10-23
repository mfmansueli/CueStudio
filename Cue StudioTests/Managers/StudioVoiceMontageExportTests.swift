//
//  StudioVoiceMontageExportTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

extension RealExports {
    /// Studio Voice over a montage with real sound: a take recorded about 9 dB quieter than the take it follows comes out within
    /// 2 dB of it once evened out, never clipping, and the preview plays the same files the export does. Each test takes
    /// seconds; 3 minutes leaves room for a loaded run and stops a stuck one before it holds the run for 10.
    @MainActor
    @Suite("Studio Voice in a montage", .serialized, .timeLimit(.minutes(3)))
    struct StudioVoiceMontageExportTests {
        /// A 2 s take with a tone all along, and a quieter copy of it stored as another recording of the montage.
        private func montage() async throws -> (take: URL, quiet: URL, name: String) {
            let take = try await TestClip.make(seconds: 2, loudSeconds: [0, 1])
            var lowered = TakeEdit(sourceDuration: 2, aspect: .portrait)
            lowered.voiceEnhancement = .off
            lowered.volume = 0.4
            let quiet = try await VideoExportService(sounds: RecordingSoundCache()).export(
                videoAt: take, options: ExportOptions(aspect: .portrait, edit: lowered, shortSide: 640, frameRate: 30)
            )
            return (take, quiet, try EditMediaFiles.link(quiet))
        }

        private func edit(quietName name: String, evensOut: Bool) -> TakeEdit {
            var edit = TakeEdit(sourceDuration: 2, aspect: .portrait)
            edit.voiceEnhancement = .off
            edit.evensOutVoices = evensOut
            var source = ClipSource(fileName: name, duration: 2, title: "Take 2")
            source.id = UUID()
            edit.sources = [source]
            edit.timeline.insertClip(source: source.id, duration: 2)
            return edit
        }

        @Test func aQuieterTakeComesOutAsLoudAsTheFirst() async throws {
            let files = try await montage()
            defer {
                for url in [files.take, files.quiet] { try? FileManager.default.removeItem(at: url) }
                EditMediaFiles.remove([files.name])
            }
            let quietBefore = try await TestClip.loudness(of: files.quiet, from: 0.2, to: 1.8)
            let takeLevel = try await TestClip.loudness(of: files.take, from: 0.2, to: 1.8)
            #expect(takeLevel - quietBefore > 6)

            let cache = RecordingSoundCache()
            for evensOut in [false, true] {
                let edit = edit(quietName: files.name, evensOut: evensOut)
                let output = try await VideoExportService(sounds: cache).export(
                    videoAt: files.take, options: ExportOptions(aspect: .portrait, edit: edit, shortSide: 640, frameRate: 30)
                )
                defer { try? FileManager.default.removeItem(at: output) }
                let first = try await TestClip.loudness(of: output, from: 0.2, to: 1.8)
                let second = try await TestClip.loudness(of: output, from: 2.2, to: 3.8)
                if evensOut {
                    #expect(abs(first - second) < 2, "Evened out: \(first) dB then \(second) dB")
                } else {
                    #expect(first - second > 6, "As recorded: \(first) dB then \(second) dB")
                }
            }
        }

        @Test func thePreviewPlaysTheSoundsTheExportUses() async throws {
            let files = try await montage()
            defer {
                for url in [files.take, files.quiet] { try? FileManager.default.removeItem(at: url) }
                EditMediaFiles.remove([files.name])
            }
            let cache = RecordingSoundCache()
            var edit = edit(quietName: files.name, evensOut: true)
            edit.voiceEnhancement = .soft
            let preview = try await RecordingSounds.prepare(for: edit, takeURL: files.take, cache: cache)
            let again = try await RecordingSounds.prepare(for: edit, takeURL: files.take, cache: cache)
            // Treated once: the second time is the same files.
            #expect(preview == again)
            #expect(preview.take != nil)
            #expect(preview.sources.count == 1)
            // Left out, the other take plays as recorded and nothing evens out.
            let source = try #require(edit.sources.first)
            edit.voiceReach = edit.voiceReach.setting(source.id, treated: false, among: [source.id])
            let alone = try await RecordingSounds.prepare(for: edit, takeURL: files.take, cache: cache)
            #expect(alone.sources.isEmpty)
            #expect(alone.take == preview.take || alone.take != nil)
        }
    }
}
