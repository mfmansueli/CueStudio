//
//  EditedExportTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

extension RealExports {
    /// The exported file is the timeline: every trim, cut and removal is in it, and nothing removed
    /// comes back, in the picture or in the sound. Each second of the test clip has its own color;
    /// the seconds listed in `loud` have a tone, the others are silent.
    @MainActor
    @Suite("Edited export", .serialized, .timeLimit(.minutes(2)))
    struct EditedExportTests {
        private let loud: Set<Int> = [1, 3]

        private func export(_ edit: TakeEdit, of clip: URL) async throws -> URL {
            try await VideoExportService().export(videoAt: clip, options: ExportOptions(aspect: .portrait, edit: edit))
        }

        private func videoDuration(of url: URL) async throws -> TimeInterval {
            let asset = AVURLAsset(url: url)
            let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
            return try await track.load(.timeRange).duration.seconds
        }

        @Test func removingBAndDExportsAThenC() async throws {
            let clip = try await TestClip.make(seconds: 4, loudSeconds: loud)
            defer { try? FileManager.default.removeItem(at: clip) }
            var edit = TakeEdit(sourceDuration: 4, aspect: .portrait)
            for cut in [1.0, 2, 3] { edit.timeline.split(atEdited: cut) }
            edit.timeline.removeSegment(id: edit.timeline.segments[3].id)
            edit.timeline.removeSegment(id: edit.timeline.segments[1].id)
            #expect(edit.keptSpans == [TimeSpan(start: 0, end: 1), TimeSpan(start: 2, end: 3)])

            let output = try await export(edit, of: clip)
            defer { try? FileManager.default.removeItem(at: output) }
            #expect(abs(try await videoDuration(of: output) - 2) < 0.05)
            #expect(try await TestClip.second(shownAt: 0.5, in: output) == 0)
            #expect(try await TestClip.second(shownAt: 0.95, in: output) == 0)
            #expect(try await TestClip.second(shownAt: 1.05, in: output) == 2)
            #expect(try await TestClip.second(shownAt: 1.5, in: output) == 2)
            // B and D had the tone; A and C are silent, so none of it may be heard.
            #expect(try await TestClip.loudness(of: output, from: 0.05, to: 1.95) < -40)
        }

        @Test func trimCutAndRemoveAllReachTheFile() async throws {
            let clip = try await TestClip.make(seconds: 4, loudSeconds: loud)
            defer { try? FileManager.default.removeItem(at: clip) }
            var edit = TakeEdit(sourceDuration: 4, aspect: .portrait)
            edit.timeline.trimStart(to: 0.5)
            edit.timeline.trimEnd(to: 3.5)
            edit.timeline.split(atEdited: 0.5)
            edit.timeline.split(atEdited: 2.5)
            edit.timeline.removeSegment(id: edit.timeline.segments[1].id)
            #expect(edit.keptSpans == [TimeSpan(start: 0.5, end: 1), TimeSpan(start: 3, end: 3.5)])

            let output = try await export(edit, of: clip)
            defer { try? FileManager.default.removeItem(at: output) }
            #expect(abs(try await videoDuration(of: output) - 1) < 0.05)
            #expect(try await TestClip.second(shownAt: 0.25, in: output) == 0)
            #expect(try await TestClip.second(shownAt: 0.75, in: output) == 3)
            // Silent A first, then the tone of D.
            #expect(try await TestClip.loudness(of: output, from: 0.05, to: 0.45) < -40)
            #expect(try await TestClip.loudness(of: output, from: 0.55, to: 0.95) > -30)
        }

        @Test func anUntouchedTimelineExportsTheWholeTake() async throws {
            let clip = try await TestClip.make(seconds: 2)
            defer { try? FileManager.default.removeItem(at: clip) }
            let output = try await export(TakeEdit(sourceDuration: 2, aspect: .portrait), of: clip)
            defer { try? FileManager.default.removeItem(at: output) }
            #expect(abs(try await videoDuration(of: output) - 2) < 0.05)
            #expect(try await TestClip.second(shownAt: 1.5, in: output) == 1)
            // The recording keeps its size.
            let asset = AVURLAsset(url: output)
            let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
            let size = try await track.load(.naturalSize)
            #expect(size == CGSize(width: 360, height: 640))
        }

        @Test func thePreviewPlaysTheSamePieces() async throws {
            let clip = try await TestClip.make(seconds: 4)
            defer { try? FileManager.default.removeItem(at: clip) }
            var edit = TakeEdit(sourceDuration: 4, aspect: .portrait)
            edit.timeline.split(atEdited: 1)
            edit.timeline.split(atEdited: 2)
            edit.timeline.removeSegment(id: edit.timeline.segments[1].id)
            let item = try await TakeEditService().previewItem(forVideoAt: clip, edit: edit)
            #expect(abs(try await item.asset.load(.duration).seconds - 3) < 0.01)
        }
    }
}
