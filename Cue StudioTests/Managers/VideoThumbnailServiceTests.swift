//
//  VideoThumbnailServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The limit counts the wait for the main actor too: in a parallel run, hundreds of main-actor tests queue there (a missing
/// video once took 19 s to answer), so it is 3 minutes, still far short of a hang's 10.
@MainActor
@Suite("VideoThumbnailService", .timeLimit(.minutes(3)))
struct VideoThumbnailServiceTests {
    @Test func timelineFramesAreRealFramesInOrder() async throws {
        let clip = try await TestClip.make(seconds: 3)
        defer { try? FileManager.default.removeItem(at: clip) }
        let frames = await VideoThumbnailService().frames(for: clip, at: [0.5, 1.5, 2.5], tolerance: 0.2)
        #expect(frames.count == 3)
        #expect(frames.allSatisfy { $0 != nil })
    }

    @Test func aMissingVideoGivesNoFrames() async {
        let missing = URL.temporaryDirectory.appending(path: "gone-\(UUID()).mov")
        let frames = await VideoThumbnailService().frames(for: missing, at: [0.5, 1], tolerance: 0.2)
        #expect(frames == [nil, nil])
    }
}
