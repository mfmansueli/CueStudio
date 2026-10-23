//
//  ObjectTrackerTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// Track follows a moving object through a recording, forwards and backwards from where it's picked, and turns the path into
/// a few editable keyframes that keep to it.
@Suite("ObjectTracker")
struct ObjectTrackerTests {
    /// A square crossing a 9:16 frame, 3 px a frame to the right and 1 px down.
    static let path: @Sendable (Int) -> CGPoint = { index in CGPoint(x: 60 + Double(index) * 3, y: 200 + Double(index)) }

    @Test func followsTheSquareBothWays() async throws {
        let url = try await MovingFootage.make(seconds: 3, width: 360, height: 640, motion: .init(square: Self.path, squareSide: 70))
        defer { try? FileManager.default.removeItem(at: url) }
        // Picked at 1.5 s (frame 45).
        let start = Self.path(45)
        let box = NormalizedBox(center: CGPoint(x: start.x / 360, y: start.y / 640), width: 70.0 / 360, height: 70.0 / 640)
        let tracker = ObjectTracker()
        let ahead = try await tracker.track(videoAt: url, box: box, at: 1.5, until: 2.9) { _ in }
        let behind = try await tracker.track(videoAt: url, box: box, at: 1.5, until: 0.2) { _ in }
        #expect(ahead.count > 30 && behind.count > 30)
        for sample in [ahead.last, behind.first].compactMap({ $0 }) {
            let truth = Self.path(Int((sample.time * 30).rounded()))
            #expect(abs(sample.box.midX * 360 - truth.x) < 12, "x at \(sample.time) s: \(sample.box.midX * 360) vs \(truth.x)")
            #expect(abs(sample.box.midY * 640 - truth.y) < 12, "y at \(sample.time) s: \(sample.box.midY * 640) vs \(truth.y)")
        }
        #expect(behind.first.map { $0.time < 0.4 } == true)
        #expect(zip(behind, behind.dropFirst()).allSatisfy { $0.time < $1.time })
    }

    @Test func aStraightPathNeedsTwoKeyframes() {
        let points = (0...60).map { TrackedMotion.Point(time: Double($0) / 30, center: OverlayPoint(x: 0.2 + Double($0) * 0.01, y: 0.5)) }
        let keyframes = TrackedMotion.keyframes(for: points) { _ in (1, 1) }
        #expect(keyframes.count == 2)
        #expect(keyframes.allSatisfy { $0.easing == .linear })
    }

    @Test func aCurvedPathKeepsCloseWithFewKeyframes() {
        let points = (0...90).map { index in
            TrackedMotion.Point(time: Double(index) / 30, center: OverlayPoint(x: 0.5 + 0.3 * sin(Double(index) / 15), y: 0.5 + 0.2 * cos(Double(index) / 15)))
        }
        let keyframes = TrackedMotion.keyframes(for: points) { _ in (1.2, 0.8) }
        #expect(keyframes.count >= 4 && keyframes.count <= 30, "\(keyframes.count) keyframes")
        let motion = OverlayMotion(keyframes)
        for point in points {
            let state = motion.state(at: point.time)
            let off = hypot((state?.center.x ?? 0) - point.center.x, (state?.center.y ?? 0) - point.center.y)
            #expect(off <= TrackedMotion.tolerance + 0.000_1)
        }
        #expect(keyframes.allSatisfy { $0.scale == 1.2 && $0.opacity == 0.8 })
    }

    @Test func aPointOfTheRecordingAndOfTheVideoGoBothWays() {
        // A 9:16 recording in a 1:1 crop in its middle, and in Fit.
        let size = CGSize(width: 1080, height: 1920)
        let crop = CropMath.crop(in: size, aspect: 1, offset: 0)
        let point = CGPoint(x: 0.3, y: 0.45)
        for fits in [false, true] {
            let placement = FramePlacement(uprightSize: size, crop: crop, fits: fits)
            let video = placement.videoPoint(for: point, at: 0)
            let back = placement.recordingPoint(for: video, at: 0)
            #expect(abs(back.x - point.x) < 0.000_1 && abs(back.y - point.y) < 0.000_1)
        }
        let cropped = FramePlacement(uprightSize: size, crop: crop).videoPoint(for: CGPoint(x: 0.5, y: 0.5), at: 0)
        #expect(abs(cropped.x - 0.5) < 0.000_1 && abs(cropped.y - 0.5) < 0.000_1)
        let side = FramePlacement(uprightSize: size, crop: crop).recordingSize(forVideoWidth: 0.1)
        #expect(abs(side.width - 0.1) < 0.000_1 && abs(side.height - 0.1 * 1080 / 1920) < 0.000_1)
    }

    @Test func aSteadiedClipPlacesPointsWhereTheCompositorDrawsThem() {
        let size = CGSize(width: 1080, height: 1920)
        let crop = CropMath.crop(in: size, aspect: 1, offset: 0)
        var placement = FramePlacement(uprightSize: size, crop: crop)
        placement.steady = StabilizationPath(times: [0, 1], dx: [0.02, 0.02], dy: [-0.01, -0.01], angles: [0.01, 0.01], zoom: 1.05)
        let point = CGPoint(x: 0.3, y: 0.45)
        // `FramePipeline.steadied`'s transform, in Core Image's coordinates (y up), then the crop.
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let transform = CGAffineTransform(translationX: -center.x, y: -center.y)
            .concatenating(CGAffineTransform(rotationAngle: -0.01))
            .concatenating(CGAffineTransform(scaleX: 1.05, y: 1.05))
            .concatenating(CGAffineTransform(translationX: center.x + 0.02 * size.width, y: center.y + 0.01 * size.height))
        let drawn = CGPoint(x: point.x * size.width, y: size.height - point.y * size.height).applying(transform)
        let video = placement.videoPoint(for: point, at: 0.5)
        #expect(abs(video.x - (drawn.x - crop.minX) / crop.width) < 0.000_1)
        #expect(abs(video.y - (size.height - drawn.y - crop.minY) / crop.height) < 0.000_1)
        let back = placement.recordingPoint(for: video, at: 0.5)
        #expect(abs(back.x - point.x) < 0.000_1 && abs(back.y - point.y) < 0.000_1)
        // Zoomed in, the same share of the video covers less of the recording.
        #expect(abs(placement.recordingSize(forVideoWidth: 0.1).width - 0.1 / 1.05) < 0.000_1)
    }
}
