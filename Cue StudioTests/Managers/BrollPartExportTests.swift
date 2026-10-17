//
//  BrollPartExportTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

/// The part of a video laid over the take: picking a later part plays that part in the same place of the edit, never past the
/// file, and the preview builds the same composition.
@Suite("B-roll part")
struct BrollPartTests {
    @Test func thePartStaysInsideTheFile() {
        var media = MediaOverlay(kind: .video, fileName: "b.mov", aspect: 1, mediaDuration: 6, span: TimeSpan(start: 0, end: 2))
        #expect(media.startInFile == 0)
        #expect(media.longestDuration == 6)
        media.mediaStart = 4
        #expect(media.longestDuration == 2)
        media.mediaStart = 10
        #expect(media.startInFile == 6 - MediaOverlay.minimumDuration)
        let photo = MediaOverlay(kind: .photo, fileName: "p.jpg", aspect: 1, mediaDuration: nil, span: TimeSpan(start: 0, end: 3))
        #expect(photo.startInFile == 0)
    }

    @Test func mediaSavedBeforeStartAtTheBeginning() throws {
        let media = MediaOverlay(kind: .video, fileName: "b.mov", aspect: 1, mediaDuration: 6, span: TimeSpan(start: 0, end: 2))
        let decoded = try JSONDecoder().decode(MediaOverlay.self, from: JSONEncoder().encode(media))
        #expect(decoded.mediaStart == nil)
        #expect(decoded.startInFile == 0)
    }
}

extension RealExports {
    @MainActor
    @Suite("B-roll part export", .serialized, .timeLimit(.minutes(10)))
    struct BrollPartExportTests {
        @Test func aLaterPartOfTheVideoPlaysInTheSamePlace() async throws {
            // The take: 4 s. The B-roll: a 6 s colored clip, full screen from 1 to 3 s, from its second 3 (yellow, then purple).
            let take = try await TestClip.make(seconds: 4)
            let broll = try await TestClip.make(seconds: 6)
            defer {
                try? FileManager.default.removeItem(at: take)
                try? FileManager.default.removeItem(at: broll)
            }
            let name = try EditMediaFiles.link(broll)
            defer { EditMediaFiles.remove([name]) }
            var edit = TakeEdit(sourceDuration: 4, aspect: .portrait)
            edit.voiceEnhancement = .off
            var media = MediaOverlay(kind: .video, fileName: name, aspect: 9.0 / 16, mediaDuration: 6, span: TimeSpan(start: 1, end: 3))
            media.mediaStart = 3
            edit.media = [media]
            let output = try await VideoExportService(sounds: RecordingSoundCache()).export(
                videoAt: take, options: ExportOptions(aspect: .portrait, edit: edit, shortSide: 640, frameRate: 30)
            )
            defer { try? FileManager.default.removeItem(at: output) }
            // At 1.5 s of the edit: 0.5 s into the part, second 3 of the B-roll (yellow), not its second 0.
            #expect(try await TestClip.second(shownAt: 1.5, in: output) == 3)
            #expect(try await TestClip.second(shownAt: 2.5, in: output) == 4)
            // Outside it, the take.
            #expect(try await TestClip.second(shownAt: 3.5, in: output) == 3)
            #expect(try await TestClip.second(shownAt: 0.5, in: output) == 0)
        }
    }
}
