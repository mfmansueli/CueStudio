//
//  StabilizationPathTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Stabilize takes the shake out and leaves the meant movement, with the least zoom that hides the edges, never past the
/// level's limit and never showing an edge.
@Suite("StabilizationPath")
struct StabilizationPathTests {
    /// A 9:16 recording whose picture drifts by `position(frame)` (fractions of the frame).
    private func analysis(frames: Int, position: (Int) -> (x: Double, y: Double, angle: Double)) -> MotionAnalysis {
        var analysis = MotionAnalysis(duration: Double(frames) / 30, width: 1080, height: 1920)
        var last = position(0)
        analysis.shifts = (1..<frames).map { index in
            let now = position(index)
            defer { last = now }
            return FrameShift(time: Double(index) / 30, dx: now.x - last.x, dy: now.y - last.y, angle: now.angle - last.angle)
        }
        analysis.analyzedUntil = analysis.duration
        return analysis
    }

    /// What's left of the picture's movement once corrected, frame to frame.
    private func residualJitter(_ path: StabilizationPath, _ position: (Int) -> (x: Double, y: Double, angle: Double), frames: Int) -> Double {
        let corrected = (1..<frames).map { index -> Double in
            let correction = path.correction(at: Double(index) / 30)
            return position(index).x - position(0).x + correction.dx
        }
        return zip(corrected, corrected.dropFirst()).map { abs($1 - $0) }.reduce(0, +) / Double(max(1, corrected.count - 1))
    }

    @Test func takesTheShakeOutAndKeepsThePan() throws {
        // A slow pan (to the right, 2% of the frame a second) with a quick shake of ±0.8%.
        let position: (Int) -> (x: Double, y: Double, angle: Double) = { index in
            (Double(index) * 0.02 / 30 + 0.008 * sin(Double(index) * 1.9), 0.006 * cos(Double(index) * 2.3), 0)
        }
        let frames = 300
        let path = try #require(StabilizationPath.make(analysis(frames: frames, position: position), level: .standard))
        let raw = (1..<frames).map { abs((position($0).x - position($0 - 1).x)) }.reduce(0, +) / Double(frames - 1)
        let left = residualJitter(path, position, frames: frames)
        #expect(left < raw * 0.3, "jitter \(raw) → \(left)")
        // The pan stays: the corrected picture still moves right about as much.
        let start = position(0).x + path.correction(at: 0).dx
        let end = position(frames - 1).x + path.correction(at: Double(frames - 1) / 30).dx
        #expect(end - start > 0.02 * 8)
        #expect(path.zoom > 1 && path.zoom <= StabilizationLevel.standard.maximumZoom)
    }

    @Test func neverShowsAnEdgeEvenWithABigJolt() throws {
        // A 10% jolt for a few frames: too big for the zoom, so it's cut short.
        let position: (Int) -> (x: Double, y: Double, angle: Double) = { index in
            ((100...105).contains(index) ? 0.1 : 0.003 * sin(Double(index)), 0, 0.002 * sin(Double(index) * 0.7))
        }
        let path = try #require(StabilizationPath.make(analysis(frames: 240, position: position), level: .gentle))
        #expect(path.zoom <= StabilizationLevel.gentle.maximumZoom + 0.000_1)
        for index in path.dx.indices {
            let needed = StabilizationPath.zoomNeeded(dx: path.dx[index], dy: path.dy[index], angle: path.angles[index], aspect: 9.0 / 16.0)
            #expect(needed <= path.zoom + 0.000_1, "frame \(index) needs \(needed) > \(path.zoom)")
        }
    }

    @Test func aSteadyRecordingIsNotZoomed() throws {
        let path = try #require(StabilizationPath.make(analysis(frames: 120) { _ in (0, 0, 0) }, level: .strong))
        #expect(path.zoom == 1)
        #expect(path.dx.allSatisfy { $0 == 0 })
    }

    @Test func strongerLevelsSmoothMore() throws {
        let position: (Int) -> (x: Double, y: Double, angle: Double) = { index in (0.01 * sin(Double(index) * 0.25), 0, 0) }
        let made = analysis(frames: 300, position: position)
        let gentle = try #require(StabilizationPath.make(made, level: .gentle))
        let strong = try #require(StabilizationPath.make(made, level: .strong))
        #expect(residualJitter(strong, position, frames: 300) < residualJitter(gentle, position, frames: 300))
    }

    @Test func readsBetweenFrames() {
        let path = StabilizationPath(times: [0, 1], dx: [0, 0.02], dy: [0, -0.02], angles: [0, 0.01], zoom: 1.05)
        let middle = path.correction(at: 0.5)
        #expect(abs(middle.dx - 0.01) < 0.000_1 && abs(middle.dy + 0.01) < 0.000_1 && abs(middle.angle - 0.005) < 0.000_1)
        #expect(path.correction(at: -1).dx == 0)
        #expect(path.correction(at: 5).dx == 0.02)
    }
}
