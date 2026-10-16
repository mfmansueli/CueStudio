//
//  FreezeFrameExportTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

extension RealExports {
    /// Freeze frame: the frame under the playhead is written as a still clip and held in the montage; the export shows it for
    /// as long as the clip lasts and then the take goes on from where it stopped.
    @MainActor
    @Suite("Freeze frame export", .serialized, .timeLimit(.minutes(10)))
    struct FreezeFrameExportTests {
        @Test func theFrozenFrameHoldsAndTheTakeGoesOn() async throws {
            let take = try await TestClip.make(seconds: 4)
            defer { try? FileManager.default.removeItem(at: take) }
            let name = try await StillClipWriter.write(frameOf: take, at: 1.5, length: 5)
            defer { EditMediaFiles.remove([name]) }
            let still = AVURLAsset(url: EditMediaFiles.url(for: name))
            #expect(abs(try await still.load(.duration).seconds - 5) < 0.1)
            #expect(try await still.loadTracks(withMediaType: .audio).isEmpty)

            var edit = TakeEdit(sourceDuration: 4, aspect: .portrait)
            edit.voiceEnhancement = .off
            let source = ClipSource(fileName: name, duration: 5, title: "Freeze frame")
            edit.timeline.split(atEdited: 1.5)
            edit.timeline.insertClip(source: source.id, duration: 5, span: TimeSpan(start: 0, end: 2), at: 1)
            edit.sources = [source]
            let output = try await VideoExportService(sounds: RecordingSoundCache()).export(
                videoAt: take, options: ExportOptions(aspect: .portrait, edit: edit, shortSide: 640, frameRate: 30)
            )
            defer { try? FileManager.default.removeItem(at: output) }
            #expect(abs(try await AVURLAsset(url: output).load(.duration).seconds - 6) < 0.1)
            // Before, during (second 1 of the take, held) and after (the take from 1.5 s on).
            #expect(try await TestClip.second(shownAt: 0.5, in: output) == 0)
            #expect(try await TestClip.second(shownAt: 1.8, in: output) == 1)
            #expect(try await TestClip.second(shownAt: 3.3, in: output) == 1)
            #expect(try await TestClip.second(shownAt: 4.8, in: output) == 2)
            #expect(try await TestClip.second(shownAt: 5.8, in: output) == 3)
        }
    }
}
