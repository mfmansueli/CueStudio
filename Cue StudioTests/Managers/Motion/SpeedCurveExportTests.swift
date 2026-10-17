//
//  SpeedCurveExportTests.swift
//  Cue StudioTests
//

import AVFoundation
import CoreImage
import Foundation
import Testing
@testable import Cue_Studio

extension RealExports {
    /// Speed curves in real exports: the export is as long as the curve says, each frame shows the moment of the recording the
    /// curve puts there (no steps), and the sound neither drops out nor clicks, with and without "Keep voice pitch".
    @MainActor
    @Suite("Speed curve export", .serialized, .timeLimit(.minutes(10)))
    struct SpeedCurveExportTests {
        @Test func theCurvePlaysSmoothlyFrameByFrame() async throws {
            // The square crosses the frame at 4 px a frame: its place says which moment of the recording shows.
            let path: @Sendable (Int) -> CGPoint = { index in CGPoint(x: 30 + Double(index) * 3, y: 320) }
            let take = try await MovingFootage.make(seconds: 3.5, width: 360, height: 640, motion: .init(square: path, squareSide: 40))
            defer { try? FileManager.default.removeItem(at: take) }
            var edit = TakeEdit(sourceDuration: 3.5, aspect: .portrait)
            edit.voiceEnhancement = .off
            var timeline = edit.timeline
            var clip = try #require(timeline.segments.first)
            clip.speedCurve = SpeedCurvePreset.hero.curve
            _ = timeline.replaceSegment(clip)
            edit.timeline = timeline
            let output = try await VideoExportService(sounds: RecordingSoundCache()).export(
                videoAt: take, options: ExportOptions(aspect: .portrait, edit: edit, shortSide: 640, frameRate: 30)
            )
            defer { try? FileManager.default.removeItem(at: output) }
            let duration = try await AVURLAsset(url: output).load(.duration).seconds
            #expect(abs(duration - edit.editedDuration) < 0.07, "\(duration) s vs \(edit.editedDuration) s")
            for time in stride(from: 0.2, to: edit.editedDuration - 0.2, by: edit.editedDuration / 14) {
                let center = try #require(try await MotionExportTests.squareCenter(in: output, at: time), "no square at \(time) s")
                let source = edit.timeline.sourceTime(forEdited: time)
                let expected = path(Int((source * 30).rounded())).x / 360
                // Within an output frame's travel at the speed there, and a frame of the recording.
                let speed = clip.speedCurve?.speed(at: source / 3.5) ?? 1
                let reach = (speed + 1) * 3 + 1
                #expect(abs(center.x - expected) < reach / 360, "at \(time) s: \(center.x * 360) px, expected \(expected * 360) px")
            }
        }

        /// Windows of 10 ms below half the median level (leaving out 150 ms at each end), and their times.
        static func drops(in url: URL) async throws -> (count: Int, at: [Double], median: Float, clicks: Int) {
            let samples = try await BeatDetector.monoSamples(of: url)
            let rate = BeatTracker.sampleRate
            let window = Int(rate / 100)
            let levels = stride(from: Int(0.15 * rate), to: samples.count - Int(0.15 * rate) - window, by: window).map { start in
                sqrt(samples[start..<(start + window)].map { $0 * $0 }.reduce(0, +) / Float(window))
            }
            let median = levels.sorted()[levels.count / 2]
            let dropped = levels.indices.filter { levels[$0] < median * 0.5 }
            let clicks = zip(samples, samples.dropFirst()).filter { abs($1 - $0) > 0.35 }.count
            return (dropped.count, dropped.map { 0.15 + Double($0) / 100 }, median, clicks)
        }

        @Test(arguments: [true, false])
        func theSoundNeitherDropsNorClicks(keepsPitch: Bool) async throws {
            let take = try await TestClip.make(seconds: 6, loudSeconds: Set(0..<6))
            defer { try? FileManager.default.removeItem(at: take) }
            var edit = TakeEdit(sourceDuration: 6, aspect: .portrait)
            edit.voiceEnhancement = .off
            var timeline = edit.timeline
            var clip = try #require(timeline.segments.first)
            clip.speedCurve = SpeedCurvePreset.rampUp.curve
            clip.keepsPitch = keepsPitch
            _ = timeline.replaceSegment(clip)
            edit.timeline = timeline
            let output = try await VideoExportService(sounds: RecordingSoundCache()).export(
                videoAt: take, options: ExportOptions(aspect: .portrait, edit: edit, shortSide: 640, frameRate: 30)
            )
            defer { try? FileManager.default.removeItem(at: output) }
            let found = try await Self.drops(in: output)
            print("SPEED CURVE SOUND keepsPitch \(keepsPitch) · median \(found.median) · drops \(found.count) · clicks \(found.clicks)")
            #expect(found.median > 0.1)
            // A pure tone is the hardest sound to stretch: with the voice's pitch kept, Apple's time-pitch lets it dip for a
            // moment at most (20 ms in 6 s); speech hides that. Played as a tape, never.
            #expect(found.count <= (keepsPitch ? 2 : 0), "keepsPitch \(keepsPitch): \(found.count) windows of 10 ms dropped, at \(found.at.prefix(6))")
            #expect(found.clicks == 0, "keepsPitch \(keepsPitch): \(found.clicks) clicks")
        }
    }
}
