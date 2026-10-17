//
//  CoverRendererTests.swift
//  Cue StudioTests
//

import CoreImage
import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// The cover is drawn from the recording its frame was picked on: in a montage, a frame of another take or video is that
/// recording's picture, never the take's at the same second.
@MainActor
@Suite("Cover renderer", .serialized)
struct CoverRendererTests {
    private func center(of image: UIImage) throws -> [Int] {
        let picture = RenderedPixels(try #require(CIImage(image: image)))
        let rgb = picture.rgb(at: CGPoint(x: picture.width / 2, y: picture.height / 2))
        return [Int(rgb.red), Int(rgb.green), Int(rgb.blue)]
    }

    private func matches(_ color: [Int], _ expected: [Int]) -> Bool {
        zip(color, expected).allSatisfy { abs($0 - $1) <= 30 }
    }

    @Test func aFrameOfAnotherRecordingIsDrawnFromThatRecording() async throws {
        // The take lasts 2 s (red, green); the other recording 6 s, purple from 4 s.
        let take = try await TestClip.make(seconds: 2)
        let other = try await TestClip.make(seconds: 6)
        defer {
            try? FileManager.default.removeItem(at: take)
            try? FileManager.default.removeItem(at: other)
        }
        let name = try EditMediaFiles.link(other)
        defer { EditMediaFiles.remove([name]) }
        var edit = TakeEdit(sourceDuration: 2, aspect: .portrait)
        var source = ClipSource(fileName: name, duration: 6, title: "Video")
        source.id = UUID()
        edit.sources = [source]
        edit.timeline.insertClip(source: source.id, duration: 6)
        // 2 s of the take, then 4.5 s into the other recording.
        edit.cover = VideoCover(source: .clipFrame(edit.coverFrame(atEdited: 6.5)))

        let cover = try #require(edit.cover)
        let image = try #require(await CoverRenderer.image(for: cover, videoURL: take, edit: edit, width: 180))
        #expect(matches(try center(of: image), TestClip.colors[4]))
    }

    @Test func aFrameOfTheTakeIsTheTakesPicture() async throws {
        let take = try await TestClip.make(seconds: 3)
        defer { try? FileManager.default.removeItem(at: take) }
        var edit = TakeEdit(sourceDuration: 3, aspect: .portrait)
        edit.cover = VideoCover(source: .frame(1.5))
        let cover = try #require(edit.cover)
        let image = try #require(await CoverRenderer.image(for: cover, videoURL: take, edit: edit, width: 180))
        #expect(matches(try center(of: image), TestClip.colors[1]))
    }

    @Test func aRecordingTheEditNoLongerKnowsDrawsNothing() async throws {
        let take = try await TestClip.make(seconds: 2)
        defer { try? FileManager.default.removeItem(at: take) }
        var edit = TakeEdit(sourceDuration: 2, aspect: .portrait)
        edit.cover = VideoCover(source: .clipFrame(CoverFrame(sourceID: UUID(), segmentID: nil, time: 1)))
        let cover = try #require(edit.cover)
        #expect(await CoverRenderer.image(for: cover, videoURL: take, edit: edit, width: 180) == nil)
    }
}
