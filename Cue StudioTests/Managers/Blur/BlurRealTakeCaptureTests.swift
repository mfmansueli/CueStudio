//
//  BlurRealTakeCaptureTests.swift
//  Cue StudioTests
//

import AVFoundation
import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// Blur area on a real recording of a face, read from the Mac (opt-in): the faces found at a moment, the face followed through
/// the motion analysis kept next to the file (and by Vision's tracker), how much of the face each frame's area covers (the
/// analysis's face boxes against the area's box), and an export with the face pixelated, with stills of it for a person to look
/// at. Printed as `REALBLUR …`; files in `CUE_REAL_FACE_OUTPUT`.
///
/// `TEST_RUNNER_CUE_REAL_FACE_TAKE=/path/take.mov TEST_RUNNER_CUE_REAL_FACE_OUTPUT=/path/folder scripts/test.sh only
/// "Cue StudioTests/RealExports/BlurRealTakeCaptureTests"` (a `.cuemotion` next to the take is used when there is one).
extension RealExports {
    @MainActor
    @Suite(
        "Blur area on a real face", .serialized, .enabled(if: ProcessInfo.processInfo.environment["CUE_REAL_FACE_TAKE"] != nil),
        .timeLimit(.minutes(10))
    )
    struct BlurRealTakeCaptureTests {
        private var take: URL { URL(fileURLWithPath: ProcessInfo.processInfo.environment["CUE_REAL_FACE_TAKE"] ?? "") }
        private var output: URL {
            URL(fileURLWithPath: ProcessInfo.processInfo.environment["CUE_REAL_FACE_OUTPUT"] ?? NSTemporaryDirectory(), isDirectory: true)
        }

        /// How much of `face` the area covers, 0 to 1 (an oval covers its box's inscribed ellipse: its corners don't count).
        private func covered(_ face: NormalizedBox, by area: NormalizedBox, oval: Bool) -> Double {
            guard face.area > 0 else { return 1 }
            guard oval else { return face.sharedArea(with: area) / face.area }
            // Sample the face's box on a grid.
            var inside = 0, total = 0
            for i in 0..<20 {
                for j in 0..<20 {
                    let x = face.x + face.width * (Double(i) + 0.5) / 20, y = face.y + face.height * (Double(j) + 0.5) / 20
                    let dx = (x - area.midX) / max(0.000_1, area.width / 2), dy = (y - area.midY) / max(0.000_1, area.height / 2)
                    total += 1
                    if dx * dx + dy * dy <= 1 { inside += 1 }
                }
            }
            return Double(inside) / Double(max(1, total))
        }

        @Test func aRealFaceIsFoundFollowedCoveredAndExported() async throws {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            let duration = try await AVURLAsset(url: take).load(.duration).seconds
            let at = min(2, duration / 3)
            let found = await FaceFinder().faces(in: take, isVideo: true, at: at) ?? []
            print("REALBLUR faces at \(at) s (Vision on the frame): \(found.map { String(format: "%.2f×%.2f at %.2f,%.2f", $0.width, $0.height, $0.minX, $0.minY) })")
            let first = try #require(found.first, "No face found")
            let face = NormalizedBox(x: first.minX, y: first.minY, width: first.width, height: first.height)
            let area = BlurRegion.area(aroundFace: face)
            let span = TimeSpan(start: 0, end: duration)

            // Followed through the analysis next to the file, if there is one.
            var region = BlurRegion(target: .recording(nil), span: span, box: area, subject: .face)
            if let analysis = MotionAnalysisStore.complete(forRecording: take) {
                let started = ContinuousClock.now
                let result = BlurFollowing.followFace(analysis.subjects, area: area, face: face, at: at, through: span)
                let took = (ContinuousClock.now - started) / .seconds(1)
                region = BlurFollowing.applying(result, to: region)
                // Coverage: every face the analysis saw, against the area at that moment.
                var worst = 1.0, leaks = 0, measured = 0
                for sample in analysis.subjects {
                    guard let seen = sample.faces.max(by: { $0.area < $1.area }) else { continue }
                    measured += 1
                    let share = covered(seen, by: region.box(at: sample.time), oval: region.shape == .oval)
                    worst = min(worst, share)
                    if share < 0.98 { leaks += 1 }
                }
                print(String(format: "REALBLUR analysis follow · %.1f s in %.3f s · %d keyframes · unchecked %.1f s · face covered worst %.0f%% · samples under 98%%: %d of %d",
                             duration, took, result.keyframes.count, region.uncheckedDuration, worst * 100, leaks, measured))
            } else {
                print("REALBLUR no motion analysis next to the take")
            }

            // Vision's tracker on the same face, for comparison (5 s ahead).
            let started = ContinuousClock.now
            let samples = try await ObjectTracker().track(videoAt: take, box: area, at: at, until: min(duration, at + 5)) { _ in }
            let elapsed = (ContinuousClock.now - started) / .seconds(1)
            print(String(format: "REALBLUR Vision tracker · %.1f s followed in %.1f s · %d samples · last confidence %.2f",
                         (samples.last?.time ?? at) - at, elapsed, samples.count, samples.last?.confidence ?? 0))

            // The export with the face pixelated, and stills of it.
            var edit = TakeEdit(sourceDuration: duration, aspect: .portrait)
            edit.voiceEnhancement = .off
            edit.timeline.trimEnd(to: min(duration, 12))
            edit.blurRegions = [region]
            let exported = try await VideoExportService(sounds: RecordingSoundCache()).export(
                videoAt: take, options: ExportOptions(aspect: .portrait, edit: edit, shortSide: 720, frameRate: 30)
            )
            let kept = output.appending(path: "real-face-pixelate.mp4")
            try? FileManager.default.removeItem(at: kept)
            try FileManager.default.moveItem(at: exported, to: kept)
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: kept))
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            for time in [0.5, 3.0, 6.0, 9.0, 11.5] {
                let image = try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image
                let destination = try #require(CGImageDestinationCreateWithURL(
                    output.appending(path: String(format: "real-face-%.1f.png", time)) as CFURL, "public.png" as CFString, 1, nil
                ))
                CGImageDestinationAddImage(destination, image, nil)
                CGImageDestinationFinalize(destination)
            }
            print("REALBLUR export and stills in \(output.path(percentEncoded: false))")
        }
    }
}
