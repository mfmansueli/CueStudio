//
//  CoverMatchesVideoFrameTests.swift
//  Cue StudioTests
//

import AVFoundation
import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import Cue_Studio

extension RealExports {
    /// The cover is the frame the video shows at its moment, framed the same way (`FramePipeline`, `EditFraming`): the crop and
    /// its offset, Fit, a clip's zoom, Stabilize, Follow face, a recording of a montage brought to the take's frame, with the
    /// clip's background and look. Texts, captions, transitions and B-roll stay off the cover, so the edits here have none.
    @MainActor
    @Suite("The cover is the video's frame", .serialized, .timeLimit(.minutes(5)))
    struct CoverMatchesVideoFrameTests {
        /// How far the cover picked at `time` (edited seconds) is from the video's frame there.
        private func difference(_ edit: TakeEdit, take: URL, at time: TimeInterval, name: String) async throws -> Double {
            let composition = try await EditedComposition.build(source: take, edit: edit, options: .init(burnsInCaptions: false, shortSide: nil))
            let video = try await RenderParity.frame(composition.asset, composition: composition.videoComposition, at: time)
            let source = CoverSource.clipFrame(edit.coverFrame(atEdited: time))
            let cover = try #require(await CoverRenderer.picture(for: source, videoURL: take, edit: edit)?.cgImage)
            #expect(abs(Double(cover.width) / Double(cover.height) - Double(video.width) / Double(video.height)) < 0.02, "\(name)")
            let size = CGSize(width: 180, height: (180 / edit.aspect.widthOverHeight).rounded())
            let difference = try RenderParity.meanDifference(video, cover, size: size)
            Attachment.record(try #require(UIImage(cgImage: cover).pngData()), named: "cover-\(name).png")
            return difference
        }

        /// Grain that slides, so a frame framed differently can't look the same.
        private func footage(seconds: Double = 3, width: Int = 360, height: Int = 640) async throws -> URL {
            try await MovingFootage.make(seconds: seconds, width: width, height: height, motion: .init(background: { index in
                (CGPoint(x: Double(index) * 2, y: Double(index)), 0)
            }))
        }

        @Test func theCropItsOffsetAndTheLook() async throws {
            let take = try await footage()
            defer { try? FileManager.default.removeItem(at: take) }
            var edit = TakeEdit(sourceDuration: 3, aspect: .square)
            edit.voiceEnhancement = .off
            edit.cropOffset = 0.6
            edit.contrast = 30
            edit.filter = .warmFilm
            #expect(try await difference(edit, take: take, at: 1.2, name: "crop") < 3)
            edit.cropFit = .fit
            #expect(try await difference(edit, take: take, at: 1.2, name: "fit") < 3)
        }

        @Test func aClipsZoomAtThatMoment() async throws {
            let take = try await footage()
            defer { try? FileManager.default.removeItem(at: take) }
            var edit = TakeEdit(sourceDuration: 3, aspect: .portrait)
            edit.voiceEnhancement = .off
            var clip = try #require(edit.timeline.segments.first)
            clip.zoom = .pushIn
            clip.zoomAmount = 1
            _ = edit.timeline.replaceSegment(clip)
            #expect(try await difference(edit, take: take, at: 2.4, name: "zoom") < 3)
        }

        @Test func aSteadiedClip() async throws {
            // A camera shaking by up to 9 px a frame.
            let take = try await MovingFootage.make(seconds: 3, width: 360, height: 640, motion: .init(background: { index in
                (CGPoint(x: 9 * sin(Double(index) * 1.7), y: 6 * cos(Double(index) * 2.1)), 0)
            }))
            defer {
                MotionAnalysisStore.remove(forRecording: take)
                try? FileManager.default.removeItem(at: take)
            }
            var edit = TakeEdit(sourceDuration: 3, aspect: .portrait)
            edit.voiceEnhancement = .off
            var clip = try #require(edit.timeline.segments.first)
            clip.stabilization = .standard
            _ = edit.timeline.replaceSegment(clip)
            // The build analyzes the recording (the cover reads the analysis it saved).
            #expect(try await difference(edit, take: take, at: 1.5, name: "steady") < 3)
            #expect(MotionAnalysisStore.complete(forRecording: take) != nil)
        }

        @Test func theCropFollowingTheFace() async throws {
            let width = 360, height = 640
            let path: @Sendable (Int) -> CGPoint = { index in CGPoint(x: 180, y: 140 + Double(min(index, 60)) * 4) }
            let take = try await MovingFootage.make(seconds: 3, width: width, height: height, motion: .init(square: path, squareSide: 60))
            defer {
                MotionAnalysisStore.remove(forRecording: take)
                try? FileManager.default.removeItem(at: take)
            }
            var analysis = MotionAnalysis(duration: 3, width: Double(width), height: Double(height))
            analysis.subjects = stride(from: 0.0, to: 3, by: 0.1).map { time in
                let center = path(Int((time * 30).rounded()))
                let face = NormalizedBox(
                    center: CGPoint(x: center.x / Double(width), y: center.y / Double(height)),
                    width: 60.0 / Double(width), height: 60.0 / Double(height)
                )
                return SubjectSample(time: time, faces: [face], bodies: [])
            }
            analysis.analyzedUntil = 3
            MotionAnalysisStore.save(analysis, forRecording: take)
            var edit = TakeEdit(sourceDuration: 3, aspect: .square)
            edit.voiceEnhancement = .off
            edit.faceFollow = FaceFollow(pace: .quick)
            #expect(try await difference(edit, take: take, at: 2.5, name: "follow") < 3)
        }

        @Test func aRecordingOfAMontageAtAnotherSize() async throws {
            let take = try await footage()
            let other = try await footage(seconds: 2, width: 720, height: 1280)
            defer { [take, other].forEach { try? FileManager.default.removeItem(at: $0) } }
            let name = try EditMediaFiles.link(other)
            defer { EditMediaFiles.remove([name]) }
            var edit = TakeEdit(sourceDuration: 3, aspect: .vertical)
            edit.voiceEnhancement = .off
            edit.sharpness = 40
            let source = ClipSource(fileName: name, duration: 2, title: "Other")
            edit.sources = [source]
            _ = edit.timeline.insertClip(source: source.id, duration: 2)
            #expect(try await difference(edit, take: take, at: 4, name: "montage") < 3)
        }
    }
}
