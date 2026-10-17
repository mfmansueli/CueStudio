//
//  MotionExportTests.swift
//  Cue StudioTests
//

import AVFoundation
import CoreImage
import Foundation
import Testing
@testable import Cue_Studio

extension RealExports {
    /// Follow face and Stabilize in real exports: the crop follows what the analysis found, and a shaking recording comes out
    /// steadier (measured again with the same analyzer).
    @MainActor
    @Suite("Motion export", .serialized, .timeLimit(.minutes(10)))
    struct MotionExportTests {
        /// The yellow square's center in the output frame at `time`, as a fraction of the width and height; nil when it isn't there.
        static func squareCenter(in url: URL, at time: TimeInterval) async throws -> CGPoint? {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            let image = try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image
            let pixels = RenderedPixels(CIImage(cgImage: image))
            var sumX = 0.0, sumY = 0.0, count = 0.0
            for y in stride(from: 0, to: pixels.height, by: 2) {
                for x in stride(from: 0, to: pixels.width, by: 2) {
                    let color = pixels.rgb(at: CGPoint(x: x, y: y))
                    if color.red > 200, color.green > 190, color.blue < 110 {
                        sumX += Double(x)
                        sumY += Double(y)
                        count += 1
                    }
                }
            }
            guard count > 10 else { return nil }
            // y up in the pixels: from the top.
            return CGPoint(x: sumX / count / Double(pixels.width), y: 1 - sumY / count / Double(pixels.height))
        }

        @Test func theSquareCropFollowsTheFace() async throws {
            // A "face" (the square) walks from the top to the bottom of a 9:16 recording over 4 s.
            let width = 360, height = 640
            let path: @Sendable (Int) -> CGPoint = { index in
                CGPoint(x: 180, y: 140 + Double(min(index, 60)) * 4)
            }
            let take = try await MovingFootage.make(seconds: 4, width: width, height: height, motion: .init(square: path, squareSide: 60))
            defer {
                MotionAnalysisStore.remove(forRecording: take)
                try? FileManager.default.removeItem(at: take)
            }
            var analysis = MotionAnalysis(duration: 4, width: Double(width), height: Double(height))
            analysis.subjects = stride(from: 0.0, to: 4, by: 0.1).map { time in
                let center = path(Int((time * 30).rounded()))
                let face = NormalizedBox(
                    center: CGPoint(x: center.x / Double(width), y: center.y / Double(height)), width: 60.0 / Double(width), height: 60.0 / Double(height)
                )
                return SubjectSample(time: time, faces: [face], bodies: [])
            }
            analysis.analyzedUntil = 4
            MotionAnalysisStore.save(analysis, forRecording: take)

            var edit = TakeEdit(sourceDuration: 4, aspect: .square)
            edit.voiceEnhancement = .off
            edit.faceFollow = FaceFollow(pace: .quick)
            let output = try await VideoExportService(sounds: RecordingSoundCache()).export(
                videoAt: take, options: ExportOptions(aspect: .square, edit: edit, shortSide: 360, frameRate: 30)
            )
            defer { try? FileManager.default.removeItem(at: output) }
            // Followed, the square stays near the frame's middle, a little above (the headroom); in the still crop of the same
            // edit it travels down the frame.
            var followed: [Double] = []
            for time in [0.3, 1.5, 3.5] {
                let center = try #require(try await Self.squareCenter(in: output, at: time), "no square at \(time) s")
                #expect(abs(center.y - 0.4) < 0.15, "at \(time) s the square is at \(center.y)")
                followed.append(center.y)
            }
            edit.faceFollow = nil
            let still = try await VideoExportService(sounds: RecordingSoundCache()).export(
                videoAt: take, options: ExportOptions(aspect: .square, edit: edit, shortSide: 360, frameRate: 30)
            )
            defer { try? FileManager.default.removeItem(at: still) }
            let top = try #require(try await Self.squareCenter(in: still, at: 0.3)).y
            let bottom = try #require(try await Self.squareCenter(in: still, at: 3.5)).y
            #expect(bottom - top > 0.4)
            #expect((followed.max() ?? 0) - (followed.min() ?? 0) < 0.2)
        }

        @Test func aShakingRecordingComesOutSteadier() async throws {
            // A camera shaking by up to 9 px a frame.
            let take = try await MovingFootage.make(seconds: 4, width: 360, height: 640, motion: .init(background: { index in
                (CGPoint(x: 9 * sin(Double(index) * 1.7), y: 6 * cos(Double(index) * 2.1)), 0)
            }))
            defer {
                MotionAnalysisStore.remove(forRecording: take)
                try? FileManager.default.removeItem(at: take)
            }
            var edit = TakeEdit(sourceDuration: 4, aspect: .portrait)
            edit.voiceEnhancement = .off
            var timeline = edit.timeline
            var clip = try #require(timeline.segments.first)
            clip.stabilization = .standard
            _ = timeline.replaceSegment(clip)
            edit.timeline = timeline
            // The export analyzes the recording it needs (no analysis yet).
            #expect(MotionAnalysisStore.load(forRecording: take) == nil)
            let output = try await VideoExportService(sounds: RecordingSoundCache()).export(
                videoAt: take, options: ExportOptions(aspect: .portrait, edit: edit, shortSide: 640, frameRate: 30)
            )
            defer { try? FileManager.default.removeItem(at: output) }
            #expect(MotionAnalysisStore.complete(forRecording: take) != nil)
            let before = try await Self.meanShake(of: take)
            let after = try await Self.meanShake(of: output)
            #expect(after < before * 0.45, "shake \(before) px → \(after) px a frame")
        }

        /// The shake: how much the camera's slide changes from one frame to the next, on average, in pixels of a 512-point copy
        /// (a steady pan has none; a shaking camera has a lot).
        static func meanShake(of url: URL) async throws -> Double {
            let analysis = try await MotionAnalyzer().analyze(
                videoAt: url, continuing: nil, shouldStop: { false }, checkpoint: { _ in }
            )
            let shifts = Array(analysis.shifts.dropFirst(3))
            let scale = 512 / max(analysis.width, analysis.height)
            let changes = zip(shifts, shifts.dropFirst()).map { before, after in
                hypot((after.dx - before.dx) * analysis.width * scale, (after.dy - before.dy) * analysis.height * scale)
            }
            return changes.reduce(0, +) / Double(max(1, changes.count))
        }
    }
}
