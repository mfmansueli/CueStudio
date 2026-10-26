//
//  BlurTrackingDeviceTests.swift
//  Cue StudioTests
//

import AVFoundation
import CoreImage
import Foundation
import Testing
import Vision
@testable import Cue_Studio

/// Small Blur areas tracked on one of the creator's takes, checked against where the thing really is: Vision's face landmarks
/// on every frame give the nose, an eye and the mouth, the truth. An oval drawn over one of them at a third of the take is
/// tracked as the editor does (Vision's tracker forwards then backwards), and every frame is scored: covered (every landmark
/// point inside the oval) or not, and marked unchecked or not. "Said covered but wasn't" must stay 0; "marked but covered" is a
/// false alarm. Each way of following is printed as `BLUR small …`, with where it slipped and how far (1.10: a point a tenth of
/// the oval's radius outside it), so a change is chosen on numbers measured on the iPhone.
///
/// Opt-in, on a device, on the take `CUE_REAL_TAKE` names (else the newest), read through a link and never changed:
/// `TEST_RUNNER_CUE_REAL_TAKE=<file in Takes> CUE_DEVICE="<iPhone>" scripts/test.sh device BlurTrackingDeviceTests`.
@MainActor
@Suite(
    "Small Blur areas tracked on this device", .serialized, .enabled(if: ProcessInfo.processInfo.environment["CUE_BLUR_E2E"] != nil),
    .timeLimit(.minutes(5))
)
struct BlurTrackingDeviceTests {
    /// Where the face's parts are on one frame (fractions of the upright frame from the top left).
    struct Truth: Sendable {
        let time: TimeInterval
        let parts: [String: [CGPoint]]
    }

    /// How one followed area did against the truth.
    struct Score: CustomStringConvertible {
        var frames = 0
        var saidCoveredButNot = 0
        var falseAlarms = 0
        var stretches = 0
        var uncheckedSeconds = 0.0
        var keyframes = 0
        /// How far out the farthest point was, on each frame said covered but not (1 is the oval's edge).
        var misses: [(time: TimeInterval, reach: Double)] = []

        var description: String {
            let far = misses.filter { $0.reach > 1.1 }.count
            let worst = misses.map(\.reach).max() ?? 0
            return String(
                format: "said covered but not %d of %d (%d past 1.10, worst %.2f) · false alarms %d · unchecked %d (%.2f s) · %d keyframes",
                saidCoveredButNot, frames, far, worst, falseAlarms, stretches, uncheckedSeconds, keyframes
            ) + (misses.isEmpty ? "" : " · at " + Self.runs(misses.map(\.time)))
        }

        /// The moments as runs: "3.2–3.5 s, 7.0 s".
        static func runs(_ times: [TimeInterval]) -> String {
            var runs: [(TimeInterval, TimeInterval)] = []
            for time in times.sorted() {
                if let last = runs.last, time - last.1 < 0.1 { runs[runs.count - 1].1 = time } else { runs.append((time, time)) }
            }
            return runs.prefix(12).map { $0.0 == $0.1 ? String(format: "%.1f", $0.0) : String(format: "%.1f–%.1f", $0.0, $0.1) }
                .joined(separator: ", ") + (runs.count > 12 ? "…" : "") + " s"
        }
    }

    @Test(arguments: ["nose", "leftEye", "mouth"])
    func aSmallAreaStaysOnItsTarget(_ part: String) async throws {
        KeepScreenAwake.enable()
        let named = ProcessInfo.processInfo.environment["CUE_REAL_TAKE"].map {
            URL.applicationSupportDirectory.appending(path: "Takes", directoryHint: .isDirectory).appending(path: $0)
        }
        let original = try #require(named ?? MotionAnalysisDeviceTests.newestTakes(1).first, "No takes on this iPhone")
        let take = URL.temporaryDirectory.appending(path: "blur-small-\(UUID().uuidString).\(original.pathExtension)")
        do {
            try FileManager.default.linkItem(at: original, to: take)
        } catch {
            try FileManager.default.copyItem(at: original, to: take)
        }
        defer { try? FileManager.default.removeItem(at: take) }
        let duration = try await AVURLAsset(url: take).load(.duration).seconds
        let frame = try await Self.uprightSize(of: take)

        let started = ContinuousClock.now
        let truths = try await Self.truths(of: take)
        print(String(format: "BLUR small truth · a face on %d frames of about %.0f, found in %.1f s", truths.count, duration * 30,
                     (ContinuousClock.now - started) / .seconds(1)))
        let at = duration * 0.35
        let first = try #require(truths.min { abs($0.time - at) < abs($1.time - at) }, "No face near a third of the take")
        let points = try #require(first.parts[part], "No \(part) found")
        let area = Self.oval(around: points)
        let span = TimeSpan(start: 0, end: duration)
        print(String(format: "BLUR small %@ · area %.3f × %.3f of the frame (%.0f × %.0f px) at %.1f s", part, area.width, area.height,
                     area.width * frame.width, area.height * frame.height, first.time))

        // As the editor tracks today.
        let tracked = NormalizedBox(center: area.center, width: max(0.04, area.width), height: max(0.04, area.height))
        let tracker = ObjectTracker()
        let began = ContinuousClock.now
        let ahead = try await tracker.track(videoAt: take, box: tracked, at: first.time, until: span.end) { _ in }
        let behind = try await tracker.track(videoAt: take, box: tracked, at: first.time, until: span.start) { _ in }
        let took = (ContinuousClock.now - began) / .seconds(1)
        let lostAhead = (ahead.last?.time ?? first.time) < span.end - 0.1
        let lostBehind = (behind.first?.time ?? first.time) > span.start + 0.1
        let lostAt = lostAhead ? ahead.last?.time ?? 0 : behind.first?.time ?? 0
        let lost = lostAhead || lostBehind ? String(format: "lost at %.2f s", lostAt) : "never lost"
        print(String(format: "BLUR small %@ · tracked in %.1f s · %d samples, %d under 0.5 · %@", part, took, ahead.count + behind.count,
                     (ahead + behind).filter { $0.confidence < 0.5 }.count, lost))

        func report(_ name: String, share: Double?, smallest: Double, fastest: Double?) {
            let result = BlurFollowing.followObject(
                ahead: ahead, behind: Array(behind.dropLast()), area: area, tracked: tracked, at: first.time, through: span,
                frameAspect: frame.width / max(1, frame.height), share: share, smallest: smallest, fastest: fastest
            )
            print("BLUR small \(part) · \(name) · \(Self.score(result, area: area, span: span, truths: truths, part: part))")
        }
        report("before (thinned to 0.4% of the frame, as small as 60% of drawn)", share: nil, smallest: 0.6, fastest: nil)
        report("never smaller than drawn, thinned to 4% of the area too", share: BlurFollowing.sizeShare, smallest: 1, fastest: nil)
        report("after (and a lasting shake marked)", share: BlurFollowing.sizeShare, smallest: 1, fastest: BlurFollowing.fastest)
        let sizes = (ahead + behind).map { min($0.box.width / tracked.width, $0.box.height / tracked.height) }
        print(String(format: "BLUR small %@ · Vision's box against the drawn one: smallest %.2f, %d%% of frames under 0.95, largest %.2f", part,
                     sizes.min() ?? 0, sizes.filter { $0 < 0.95 }.count * 100 / max(1, sizes.count), sizes.max() ?? 0))
    }

    // MARK: - Scoring

    /// An oval a creator would draw over `points`: their box, half again as large, so every point sits inside the oval.
    nonisolated static func oval(around points: [CGPoint]) -> NormalizedBox {
        let xs = points.map(\.x), ys = points.map(\.y)
        let minX = xs.min() ?? 0, maxX = xs.max() ?? 0, minY = ys.min() ?? 0, maxY = ys.max() ?? 0
        return NormalizedBox(
            center: CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2),
            width: max(0.03, (maxX - minX) * 1.6), height: max(0.03, (maxY - minY) * 1.6)
        )
    }

    nonisolated static func score(_ result: BlurFollowing.Result, area: NormalizedBox, span: TimeSpan, truths: [Truth], part: String) -> Score {
        var region = BlurRegion(target: .recording(nil), span: span, box: area)
        region.shape = .oval
        region = BlurFollowing.applying(result, to: region)
        var score = Score()
        score.stretches = region.openUnchecked.count
        score.uncheckedSeconds = region.uncheckedDuration
        score.keyframes = region.keyframes.count
        for truth in truths {
            guard let points = truth.parts[part], !points.isEmpty else { continue }
            let box = region.box(at: truth.time)
            let reach = points.map { point in
                let dx = (point.x - box.midX) / max(0.000_1, box.width / 2), dy = (point.y - box.midY) / max(0.000_1, box.height / 2)
                return (dx * dx + dy * dy).squareRoot()
            }.max() ?? 0
            let covered = reach <= 1
            let marked = region.openUnchecked.contains { $0.start - 0.000_1 <= truth.time && truth.time <= $0.end + 0.000_1 }
            score.frames += 1
            if !covered, !marked {
                score.saidCoveredButNot += 1
                score.misses.append((truth.time, reach))
            }
            if covered, marked { score.falseAlarms += 1 }
        }
        return score
    }

    // MARK: - The truth

    @concurrent
    nonisolated static func uprightSize(of url: URL) async throws -> CGSize {
        let track = try #require(try await AVURLAsset(url: url).loadTracks(withMediaType: .video).first)
        let (size, transform) = try await track.load(.naturalSize, .preferredTransform)
        let upright = CGRect(origin: .zero, size: size).applying(transform)
        return CGSize(width: abs(upright.width), height: abs(upright.height))
    }

    /// The largest face's nose, left eye and outer lips on every frame, drawn upright at 960 px on the long side.
    @concurrent
    nonisolated static func truths(of url: URL) async throws -> [Truth] {
        let asset = AVURLAsset(url: url)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let (naturalSize, transform) = try await track.load(.naturalSize, .preferredTransform)
        let upright = CGRect(origin: .zero, size: naturalSize).applying(transform)
        let scale = 960 / max(abs(upright.width), abs(upright.height))
        let size = CGSize(width: (abs(upright.width) * scale).rounded(), height: (abs(upright.height) * scale).rounded())
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        ])
        let provider = reader.outputProvider(for: output)
        try reader.start()
        defer { reader.cancelReading() }
        let context = CIContext(options: [.cacheIntermediates: false])
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, Int(size.width), Int(size.height), kCVPixelFormatType_32BGRA,
                            [kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()] as CFDictionary, &buffer)
        let drawn = try #require(buffer)
        var truths: [Truth] = []
        while let ready = try await provider.next() {
            let found: Truth? = ready.withUnsafeSampleBuffer { sample in
                guard let pixels = sample.imageBuffer else { return nil }
                let time = sample.presentationTimeStamp.seconds
                return autoreleasepool {
                    var image = CIImage(cvPixelBuffer: pixels).transformed(
                        by: FramePipeline.uprightTransform(transform, sourceHeight: CGFloat(CVPixelBufferGetHeight(pixels)))
                    )
                    image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
                        .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                    context.render(image, to: drawn)
                    let request = VNDetectFaceLandmarksRequest()
                    try? VNImageRequestHandler(cvPixelBuffer: drawn, orientation: .up).perform([request])
                    guard let face = request.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width }), let marks = face.landmarks
                    else { return nil }
                    let box = face.boundingBox
                    func points(_ region: VNFaceLandmarkRegion2D?) -> [CGPoint]? {
                        guard let region, region.pointCount > 0 else { return nil }
                        return region.normalizedPoints.map { CGPoint(x: box.minX + $0.x * box.width, y: 1 - (box.minY + $0.y * box.height)) }
                    }
                    var parts: [String: [CGPoint]] = [:]
                    parts["nose"] = points(marks.nose)
                    parts["leftEye"] = points(marks.leftEye)
                    parts["mouth"] = points(marks.outerLips)
                    return Truth(time: time, parts: parts)
                }
            }
            if let found { truths.append(found) }
        }
        return truths
    }
}
