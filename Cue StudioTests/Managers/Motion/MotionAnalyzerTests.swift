//
//  MotionAnalyzerTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import os
import Testing
@testable import Cue_Studio

/// The analyzer on videos whose motion is known (`MovingFootage`): the slide and the turn it measures from frame to frame, in
/// the frame's fractions and on screen's directions, and stopping and going on without measuring a frame twice.
@Suite("MotionAnalyzer")
struct MotionAnalyzerTests {
    private func analyze(_ url: URL) async throws -> MotionAnalysis {
        try await MotionAnalyzer().analyze(videoAt: url, continuing: nil, shouldStop: { false }, checkpoint: { _ in })
    }

    @Test func measuresHowThePictureSlides() async throws {
        // The grain goes 6 px right and 3 px down every frame.
        let url = try await MovingFootage.make(seconds: 1.5, width: 540, height: 960, motion: .init(background: { index in
            (CGPoint(x: Double(index) * 6, y: Double(index) * 3), 0)
        }))
        defer { try? FileManager.default.removeItem(at: url) }
        let analysis = try await analyze(url)
        #expect(analysis.isComplete)
        #expect(analysis.width == 540 && analysis.height == 960)
        #expect(analysis.shifts.count >= 40)
        let dx = analysis.shifts.map(\.dx).reduce(0, +) / Double(analysis.shifts.count)
        let dy = analysis.shifts.map(\.dy).reduce(0, +) / Double(analysis.shifts.count)
        #expect(abs(dx - 6.0 / 540) < 6.0 / 540 * 0.25, "dx \(dx * 540) px")
        #expect(abs(dy - 3.0 / 960) < 3.0 / 960 * 0.35, "dy \(dy * 960) px")
    }

    @Test func measuresHowThePictureTurns() async throws {
        // 0.006 rad clockwise every frame, about the center.
        let url = try await MovingFootage.make(seconds: 1.5, width: 540, height: 960, motion: .init(background: { index in
            (.zero, Double(index) * 0.006)
        }))
        defer { try? FileManager.default.removeItem(at: url) }
        let analysis = try await analyze(url)
        let angle = analysis.shifts.map(\.angle).reduce(0, +) / Double(max(1, analysis.shifts.count))
        #expect(abs(angle - 0.006) < 0.002, "angle \(angle)")
        let dx = analysis.shifts.map(\.dx).reduce(0, +) / Double(max(1, analysis.shifts.count))
        #expect(abs(dx) < 1.0 / 540, "a turn about the center isn't a slide: \(dx * 540) px")
    }

    /// Something moving through part of the frame (a hand, someone walking by) doesn't read as the camera moving.
    @Test func somethingMovingInTheFrameIsNotTheCamera() async throws {
        let still = try await MovingFootage.make(seconds: 1.5, width: 360, height: 640, motion: .init(
            square: { index in CGPoint(x: 60 + Double(index) * 6, y: 500) }, squareSide: 90
        ))
        defer { try? FileManager.default.removeItem(at: still) }
        let analysis = try await analyze(still)
        let moved = analysis.shifts.map { hypot($0.dx * 360, $0.dy * 640) }.reduce(0, +) / Double(max(1, analysis.shifts.count))
        #expect(moved < 0.5, "the still camera read as moving \(moved) px a frame")
        // The camera sliding with the square still in it: the slide is the camera's.
        let panning = try await MovingFootage.make(seconds: 1.5, width: 360, height: 640, motion: .init(
            background: { index in (CGPoint(x: Double(index) * 4, y: 0), 0) },
            square: { index in CGPoint(x: 300 - Double(index) * 5, y: 120) }, squareSide: 90
        ))
        defer { try? FileManager.default.removeItem(at: panning) }
        let pan = try await analyze(panning)
        let dx = pan.shifts.map(\.dx).reduce(0, +) / Double(max(1, pan.shifts.count)) * 360
        #expect(abs(dx - 4) < 1, "pan read as \(dx) px a frame")
    }

    @Test func theTilesLeaveThePeopleOut() {
        // A creator in the middle: the tiles they cover are left out.
        let subject = SubjectSample(time: 0, faces: [NormalizedBox(x: 0.4, y: 0.2, width: 0.2, height: 0.12)], bodies: [
            NormalizedBox(x: 0.3, y: 0.15, width: 0.4, height: 0.85),
        ])
        let tiles = BackgroundTiles.tiles(around: subject, aspect: 9.0 / 16.0)
        #expect(tiles.count >= BackgroundTiles.minimumCount && tiles.count < 24)
        // The middle columns go, the outer ones stay.
        #expect(tiles.allSatisfy { $0.x + $0.width <= 0.26 || $0.x >= 0.74 || $0.y + $0.height <= 0.18 })
        // Nobody: the whole grid. Filling the frame: the whole grid too.
        #expect(BackgroundTiles.tiles(around: nil, aspect: 9.0 / 16.0).count == 24)
        let filling = SubjectSample(time: 0, faces: [], bodies: [NormalizedBox(x: 0, y: 0, width: 1, height: 1)])
        #expect(BackgroundTiles.tiles(around: filling, aspect: 16.0 / 9.0).count == 24)
    }

    @Test func theCameraIsWhatMostTilesAgreeOn() throws {
        // Eight tiles slide 3 px right; one has a hand moving 20 px through it.
        var tiles = (0..<8).map { index in
            CameraMotion.Tile(x: Double(index % 4) * 60 - 90, y: Double(index / 4) * 100 - 50, dx: 3, dy: 0)
        }
        tiles.append(CameraMotion.Tile(x: 0, y: 0, dx: 20, dy: -12))
        let motion = try #require(CameraMotion.estimate(tiles))
        #expect(abs(motion.dx - 3) < 0.01 && abs(motion.dy) < 0.01 && abs(motion.angle) < 0.000_1)
        // A turn of 0.01 rad clockwise about the center.
        let turned = [(-100.0, -100.0), (100, -100), (100, 100), (-100, 100), (0, -150), (0, 150)].map { point in
            CameraMotion.Tile(x: point.0, y: point.1, dx: -0.01 * point.1, dy: 0.01 * point.0)
        }
        let turn = try #require(CameraMotion.estimate(turned))
        #expect(abs(turn.angle - 0.01) < 0.000_1)
    }

    @Test func looksForSubjectsTenTimesASecond() async throws {
        let url = try await MovingFootage.make(seconds: 2, width: 360, height: 640, motion: .init())
        defer { try? FileManager.default.removeItem(at: url) }
        let analysis = try await analyze(url)
        #expect((19...21).contains(analysis.subjects.count), "\(analysis.subjects.count) samples")
        #expect(analysis.subjects.allSatisfy { $0.faces.isEmpty })
    }

    @Test func stopsAndGoesOnWithoutMeasuringAFrameTwice() async throws {
        let url = try await MovingFootage.make(seconds: 3, width: 360, height: 640, motion: .init(background: { index in
            (CGPoint(x: Double(index) * 2, y: 0), 0)
        }))
        defer { try? FileManager.default.removeItem(at: url) }
        let whole = try await analyze(url)
        // Stopped at the first checkpoint, a second in.
        let analyzer = MotionAnalyzer(checkpointInterval: 1)
        let checkpoints = OSAllocatedUnfairLock(initialState: 0)
        let partial = try await analyzer.analyze(
            videoAt: url, continuing: nil, shouldStop: { checkpoints.withLock { $0 > 0 } },
            checkpoint: { _ in checkpoints.withLock { $0 += 1 } }
        )
        #expect(!partial.isComplete)
        #expect(partial.analyzedUntil > 0.9 && partial.analyzedUntil < 2)
        let resumed = try await analyzer.analyze(videoAt: url, continuing: partial, shouldStop: { false }, checkpoint: { _ in })
        #expect(resumed.isComplete)
        let times = resumed.shifts.map(\.time)
        #expect(zip(times, times.dropFirst()).allSatisfy { $0 < $1 }, "every frame measured once, in order")
        #expect(abs(resumed.shifts.count - whole.shifts.count) <= 1)
        let subjectTimes = resumed.subjects.map(\.time)
        #expect(zip(subjectTimes, subjectTimes.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test func keepsTheAnalysisNextToTheRecordingAndRemovesItWithIt() throws {
        let recording = URL.temporaryDirectory.appending(path: "rec-\(UUID().uuidString).mov")
        try Data([1, 2, 3]).write(to: recording)
        defer { try? FileManager.default.removeItem(at: recording) }
        var analysis = MotionAnalysis(duration: 2, width: 1080, height: 1920)
        analysis.subjects = [SubjectSample(time: 0.1, faces: [NormalizedBox(x: 0.3, y: 0.2, width: 0.4, height: 0.25)], bodies: [])]
        analysis.shifts = [FrameShift(time: 0.033, dx: 0.001, dy: -0.002, angle: 0.0005)]
        analysis.analyzedUntil = 2
        MotionAnalysisStore.save(analysis, forRecording: recording)
        let loaded = try #require(MotionAnalysisStore.complete(forRecording: recording))
        #expect(loaded.subjects.first?.faces.first.map { abs($0.width - 0.4) < 0.0001 } == true)
        #expect(loaded.shifts.count == 1)
        // Another version is made again, never used.
        analysis.version = MotionAnalysis.currentVersion + 1
        MotionAnalysisStore.save(analysis, forRecording: recording)
        #expect(MotionAnalysisStore.complete(forRecording: recording) == nil)
        MotionAnalysisStore.remove(forRecording: recording)
        #expect(MotionAnalysisStore.load(forRecording: recording) == nil)
    }
}
