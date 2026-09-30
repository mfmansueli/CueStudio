//
//  QuickCreatorExportTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// What the Quick Creator tools add reaches the exported file, on the moments the timeline says:
/// speed, a photo and a video over the take, a text and a voice-over. Each second of the test
/// clip has its own color (see `TestClip`), so a frame tells which part of which file it shows.
@MainActor
@Suite("Quick Creator export", .serialized, .timeLimit(.minutes(3)))
struct QuickCreatorExportTests {
    private func export(_ edit: TakeEdit, of clip: URL) async throws -> URL {
        try await VideoExportService().export(videoAt: clip, options: ExportOptions(aspect: .portrait, edit: edit))
    }

    private func videoDuration(of url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        return try await track.load(.timeRange).duration.seconds
    }

    /// Copies `url` into the app's media folder, as an import would.
    private func stored(_ url: URL) throws -> String {
        let file = try EditMediaFiles.newFile(pathExtension: url.pathExtension)
        try FileManager.default.copyItem(at: url, to: file.url)
        return file.name
    }

    @Test func doubleSpeedPlaysTheTakeInHalfTheTimeWithItsSound() async throws {
        let clip = try await TestClip.make(seconds: 4, loudSeconds: [1, 3])
        defer { try? FileManager.default.removeItem(at: clip) }
        var edit = TakeEdit(sourceDuration: 4, aspect: .portrait)
        edit.timeline.setSpeed(2)
        edit.voiceEnhancement = .off

        let output = try await export(edit, of: clip)
        defer { try? FileManager.default.removeItem(at: output) }
        #expect(abs(try await videoDuration(of: output) - 2) < 0.06)
        #expect(try await TestClip.second(shownAt: 0.25, in: output) == 0)
        #expect(try await TestClip.second(shownAt: 0.75, in: output) == 1)
        #expect(try await TestClip.second(shownAt: 1.25, in: output) == 2)
        // Second 1 had the tone: now it's heard from 0.5 to 1.
        #expect(try await TestClip.loudness(of: output, from: 0.05, to: 0.45) < -40)
        #expect(try await TestClip.loudness(of: output, from: 0.6, to: 0.9) > -30)
    }

    @Test func aPhotoCoversTheTakeWhileItShows() async throws {
        let clip = try await TestClip.make(seconds: 3)
        defer { try? FileManager.default.removeItem(at: clip) }
        let color = TestClip.colors[4]
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 90, height: 160)).image { context in
            UIColor(red: CGFloat(color[0]) / 255, green: CGFloat(color[1]) / 255, blue: CGFloat(color[2]) / 255, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 90, height: 160))
        }
        let file = try EditMediaFiles.newFile(pathExtension: "jpg")
        try #require(photo.jpegData(compressionQuality: 1)).write(to: file.url)
        defer { EditMediaFiles.remove([file.name]) }

        var edit = TakeEdit(sourceDuration: 3, aspect: .portrait)
        edit.voiceEnhancement = .off
        edit.media = [MediaOverlay(kind: .photo, fileName: file.name, aspect: 90.0 / 160.0, mediaDuration: nil, span: TimeSpan(start: 1, end: 2))]
        let output = try await export(edit, of: clip)
        defer { try? FileManager.default.removeItem(at: output) }
        #expect(try await TestClip.second(shownAt: 0.5, in: output) == 0)
        #expect(try await TestClip.second(shownAt: 1.5, in: output) == 4)
        #expect(try await TestClip.second(shownAt: 2.5, in: output) == 2)
    }

    @Test func aVideoPlaysFromItsStartOverTheTake() async throws {
        let clip = try await TestClip.make(seconds: 4)
        let broll = try await TestClip.make(seconds: 2)
        defer {
            try? FileManager.default.removeItem(at: clip)
            try? FileManager.default.removeItem(at: broll)
        }
        let name = try stored(broll)
        defer { EditMediaFiles.remove([name]) }

        var edit = TakeEdit(sourceDuration: 4, aspect: .portrait)
        edit.voiceEnhancement = .off
        edit.media = [MediaOverlay(kind: .video, fileName: name, aspect: 9.0 / 16.0, mediaDuration: 2, span: TimeSpan(start: 1, end: 3))]
        let output = try await export(edit, of: clip)
        defer { try? FileManager.default.removeItem(at: output) }
        #expect(try await TestClip.second(shownAt: 0.5, in: output) == 0)
        // The B-roll's own first and second seconds, where the take shows its second and third.
        #expect(try await TestClip.second(shownAt: 1.5, in: output) == 0)
        #expect(try await TestClip.second(shownAt: 2.5, in: output) == 1)
        #expect(try await TestClip.second(shownAt: 3.5, in: output) == 3)
    }

    @Test func aTextShowsOnlyOnItsMoment() async throws {
        let clip = try await TestClip.make(seconds: 3)
        defer { try? FileManager.default.removeItem(at: clip) }
        var edit = TakeEdit(sourceDuration: 3, aspect: .portrait)
        edit.voiceEnhancement = .off
        var text = TextOverlay(role: .title, style: .clean, span: TimeSpan(start: 1, end: 2))
        text.text = "█████"
        text.background = .box
        text.center = .center
        text.size = 60
        edit.texts = [text]
        let output = try await export(edit, of: clip)
        defer { try? FileManager.default.removeItem(at: output) }
        #expect(try await TestClip.second(shownAt: 0.5, in: output) == 0)
        // The middle of the frame is the text's box, not the take.
        #expect(try await TestClip.second(shownAt: 1.5, in: output) == nil)
        #expect(try await TestClip.second(shownAt: 2.5, in: output) == 2)
    }

    @Test func aVoiceOverIsHeardFromWhereItStarts() async throws {
        let clip = try await TestClip.make(seconds: 4, loudSeconds: [])
        let voice = try await TestClip.make(seconds: 2, loudSeconds: [0, 1])
        defer {
            try? FileManager.default.removeItem(at: clip)
            try? FileManager.default.removeItem(at: voice)
        }
        let name = try stored(voice)
        defer { EditMediaFiles.remove([name]) }

        var edit = TakeEdit(sourceDuration: 4, aspect: .portrait)
        edit.voiceEnhancement = .off
        edit.voiceOvers = [VoiceOverClip(fileName: name, duration: 2, anchor: 2)]
        let output = try await export(edit, of: clip)
        defer { try? FileManager.default.removeItem(at: output) }
        #expect(abs(try await videoDuration(of: output) - 4) < 0.06)
        #expect(try await TestClip.loudness(of: output, from: 0.1, to: 1.9) < -40)
        #expect(try await TestClip.loudness(of: output, from: 2.1, to: 3.9) > -30)
    }
}
