//
//  EditorMotionDeviceTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

/// The editor's motion tools on this iPhone, on COPIES of the newest takes (never the takes themselves): how long an export
/// with Follow face or Stabilize takes against the same export without, how smooth the followed crop is, and how much steadier
/// a stabilized take comes out (measured again with the analyzer). Printed as `EDITOR MOTION …`.
///
/// Opt-in and on a device: `CUE_DEVICE="<iPhone>" scripts/test.sh device EditorMotionDeviceTests`.
@MainActor
@Suite(
    "Editor motion on this device",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["CUE_MOTION_E2E"] != nil),
    .timeLimit(.minutes(5))
)
struct EditorMotionDeviceTests {
    private func copyOfNewestTake(_ index: Int = 0) throws -> URL {
        let takes = MotionAnalysisDeviceTests.newestTakes(index + 1)
        try #require(takes.count > index, "No takes on this iPhone")
        let original = takes[index]
        let copy = URL.temporaryDirectory.appending(path: "motion-\(UUID().uuidString).\(original.pathExtension)")
        try FileManager.default.copyItem(at: original, to: copy)
        return copy
    }

    private func export(_ take: URL, _ edit: TakeEdit, aspect: AspectRatio) async throws -> (url: URL, seconds: Double) {
        let started = ContinuousClock.now
        let output = try await VideoExportService(sounds: RecordingSoundCache()).export(
            videoAt: take, options: ExportOptions(aspect: aspect, edit: edit, shortSide: 1080, frameRate: 30)
        )
        return (output, (ContinuousClock.now - started) / .seconds(1))
    }

    private func edit(for take: URL, aspect: AspectRatio) async throws -> TakeEdit {
        let duration = try await AVURLAsset(url: take).load(.duration).seconds
        var edit = TakeEdit(sourceDuration: duration, aspect: aspect)
        edit.voiceEnhancement = .off
        return edit
    }

    @Test func followFaceOnTheNewestTake() async throws {
        KeepScreenAwake.enable()
        let take = try copyOfNewestTake()
        defer {
            MotionAnalysisStore.remove(forRecording: take)
            try? FileManager.default.removeItem(at: take)
        }
        let started = ContinuousClock.now
        let analysis = try await MotionAnalyzer().analyze(videoAt: take, continuing: nil, shouldStop: { false }, checkpoint: { _ in })
        let analyzed = (ContinuousClock.now - started) / .seconds(1)
        MotionAnalysisStore.save(analysis, forRecording: take)
        for aspect in [AspectRatio.square, .landscape] {
            var edit = try await edit(for: take, aspect: aspect)
            let plain = try await export(take, edit, aspect: aspect)
            try? FileManager.default.removeItem(at: plain.url)
            edit.faceFollow = FaceFollow()
            let followed = try await export(take, edit, aspect: aspect)
            try? FileManager.default.removeItem(at: followed.url)
            // How the crop moves, in pixels of the recording, frame to frame.
            let crop = CropMath.centeredCrop(in: CGSize(width: analysis.width, height: analysis.height), aspect: aspect.widthOverHeight)
            let path = try #require(FaceFollowPath.make(
                analysis, cropWidth: crop.width / analysis.width, cropHeight: crop.height / analysis.height, pace: .natural
            ))
            let centers = stride(from: 0, to: analysis.duration, by: 1.0 / 30).map { path.center(at: $0) }
            let steps = zip(centers, centers.dropFirst()).map { hypot(($1.x - $0.x) * analysis.width, ($1.y - $0.y) * analysis.height) }
            let moving = steps.filter { $0 > 0.05 }.count
            print(
                "EDITOR MOTION FOLLOW \(aspect.rawValue) · \(String(format: "%.1f", analysis.duration)) s · analysis \(String(format: "%.1f", analyzed)) s"
                    + " · export \(String(format: "%.1f", plain.seconds)) s → \(String(format: "%.1f", followed.seconds)) s with Follow face"
                    + " · crop moves in \(moving)/\(steps.count) frames, at most \(String(format: "%.1f", steps.max() ?? 0)) px a frame"
            )
        }
    }

    @Test(arguments: [StabilizationLevel.gentle, .standard, .strong])
    func stabilizeTheNewestTake(level: StabilizationLevel) async throws {
        KeepScreenAwake.enable()
        let take = try copyOfNewestTake()
        defer {
            MotionAnalysisStore.remove(forRecording: take)
            try? FileManager.default.removeItem(at: take)
        }
        var edit = try await edit(for: take, aspect: .portrait)
        let plain = try await export(take, edit, aspect: .portrait)
        defer { try? FileManager.default.removeItem(at: plain.url) }
        let analysis = try await MotionAnalyzer().analyze(videoAt: take, continuing: nil, shouldStop: { false }, checkpoint: { _ in })
        MotionAnalysisStore.save(analysis, forRecording: take)
        var timeline = edit.timeline
        var clip = try #require(timeline.segments.first)
        clip.stabilization = level
        _ = timeline.replaceSegment(clip)
        edit.timeline = timeline
        let steady = try await export(take, edit, aspect: .portrait)
        defer { try? FileManager.default.removeItem(at: steady.url) }
        let zoom = StabilizationPath.make(analysis, level: level)?.zoom ?? 1
        // How the camera moved, frame to frame (pixels of the 512-point copy), and how far the path strays from its smoothing.
        let scale = 512 / max(analysis.width, analysis.height)
        let moves = analysis.shifts.map { hypot($0.dx * analysis.width * scale, $0.dy * analysis.height * scale) }.sorted()
        func percentile(_ values: [Double], _ share: Double) -> Double { values.isEmpty ? 0 : values[min(values.count - 1, Int(Double(values.count) * share))] }
        var x = 0.0, y = 0.0, xs: [Double] = [], ys: [Double] = []
        for shift in analysis.shifts {
            x += shift.dx
            y += shift.dy
            xs.append(x)
            ys.append(y)
        }
        let sigma = level.smoothing * 30
        let smoothX = GaussianSmoothing.smoothed(xs, sigma: sigma), smoothY = GaussianSmoothing.smoothed(ys, sigma: sigma)
        let strays = xs.indices.map { max(abs(smoothX[$0] - xs[$0]), abs(smoothY[$0] - ys[$0])) * 100 }.sorted()
        let turns = analysis.shifts.map { abs($0.angle) }.sorted()
        print(
            "EDITOR MOTION SHAKE \(level.rawValue) · move p50 \(String(format: "%.2f", percentile(moves, 0.5))) p90 \(String(format: "%.2f", percentile(moves, 0.9)))"
                + " p99 \(String(format: "%.2f", percentile(moves, 0.99))) max \(String(format: "%.1f", moves.last ?? 0)) px"
                + " · stray p50 \(String(format: "%.2f", percentile(strays, 0.5))) p90 \(String(format: "%.2f", percentile(strays, 0.9)))"
                + " p98 \(String(format: "%.2f", percentile(strays, 0.98))) % · turn p90 \(String(format: "%.4f", percentile(turns, 0.9))) rad"
        )
        let before = try await RealExports.MotionExportTests.meanShake(of: plain.url)
        let after = try await RealExports.MotionExportTests.meanShake(of: steady.url)
        print(
            "EDITOR MOTION STABILIZE \(level.rawValue) · export \(String(format: "%.1f", plain.seconds)) s → \(String(format: "%.1f", steady.seconds)) s"
                + " · zoom \(String(format: "%.1f", (zoom - 1) * 100))% · shake \(String(format: "%.2f", before)) → \(String(format: "%.2f", after)) px a frame"
        )
    }

    /// Track on the newest take: the creator's face (where the analysis first finds it) followed for 6 seconds, against where
    /// the analysis finds the face at each moment.
    @Test func trackTheFaceOnTheNewestTake() async throws {
        KeepScreenAwake.enable()
        let take = try copyOfNewestTake()
        defer {
            MotionAnalysisStore.remove(forRecording: take)
            try? FileManager.default.removeItem(at: take)
        }
        let analysis = try await MotionAnalyzer().analyze(videoAt: take, continuing: nil, shouldStop: { false }, checkpoint: { _ in })
        let start = try #require(analysis.subjects.first { !$0.faces.isEmpty && $0.time > 1 })
        let face = try #require(start.faces.first)
        let box = NormalizedBox(center: face.center, width: face.width * 0.6, height: face.height * 0.6)
        let started = ContinuousClock.now
        let samples = try await ObjectTracker().track(videoAt: take, box: box, at: start.time, until: start.time + 6) { _ in }
        let took = (ContinuousClock.now - started) / .seconds(1)
        var offs: [Double] = []
        for sample in samples {
            guard let near = analysis.subjects.min(by: { abs($0.time - sample.time) < abs($1.time - sample.time) }),
                  abs(near.time - sample.time) < 0.06, let truth = near.faces.first else { continue }
            offs.append(hypot((sample.box.midX - truth.midX) * analysis.width, (sample.box.midY - truth.midY) * analysis.height))
        }
        offs.sort()
        let lastTime = samples.last?.time ?? start.time
        print(
            "EDITOR MOTION TRACK · \(samples.count) frames in \(String(format: "%.1f", took)) s (\(String(format: "%.1f", took * 1000 / Double(max(1, samples.count)))) ms a frame)"
                + " · followed \(String(format: "%.1f", lastTime - start.time)) of 6 s"
                + " · off the face p50 \(Int(offs.isEmpty ? -1 : offs[offs.count / 2])) px, p90 \(Int(offs.isEmpty ? -1 : offs[offs.count * 9 / 10])) px"
                + " of \(Int(analysis.width))×\(Int(analysis.height))"
        )
        #expect(samples.count > 30)
    }

    /// A speed curve and Reverse on the newest take: the export with Hero on its first 10 s (sound kept in pitch), and the 10 s
    /// written backwards (time, memory, heat).
    @Test func curveAndReverseOnTheNewestTake() async throws {
        KeepScreenAwake.enable()
        let take = try copyOfNewestTake()
        defer { try? FileManager.default.removeItem(at: take) }
        var edit = try await edit(for: take, aspect: .portrait)
        edit.voiceEnhancement = .soft
        _ = edit.timeline.split(atEdited: 10)
        var clip = try #require(edit.timeline.segments.first)
        clip.speedCurve = SpeedCurvePreset.hero.curve
        _ = edit.timeline.replaceSegment(clip)
        let curved = try await export(take, edit, aspect: .portrait)
        try? FileManager.default.removeItem(at: curved.url)
        let plainEdit = try await self.edit(for: take, aspect: .portrait)
        let plain = try await export(take, plainEdit, aspect: .portrait)
        try? FileManager.default.removeItem(at: plain.url)
        let heat = ProcessInfo.processInfo.thermalState
        let base = MotionAnalysisDeviceTests.footprint()
        let started = ContinuousClock.now
        let name = try await ReversedClipWriter.write(take, span: TimeSpan(start: 0, end: 10)) { _ in }
        let reversing = (ContinuousClock.now - started) / .seconds(1)
        let memory = (MotionAnalysisDeviceTests.footprint() - base) / 1_000_000
        let size = (try? FileManager.default.attributesOfItem(atPath: EditMediaFiles.url(for: name).path(percentEncoded: false))[.size] as? Int) ?? 0
        EditMediaFiles.remove([name])
        print(
            "EDITOR MOTION CURVE · export \(String(format: "%.1f", plain.seconds)) s plain → \(String(format: "%.1f", curved.seconds)) s with Hero on 10 s"
                + " · REVERSE 10 s in \(String(format: "%.1f", reversing)) s, memory after +\(memory) MB, \(size / 1_000_000) MB file"
                + " · heat \(MotionAnalysisDeviceTests.name(heat)) → \(MotionAnalysisDeviceTests.name(ProcessInfo.processInfo.thermalState))"
        )
    }

    /// Beats in three minutes of music (a click track at 124 BPM): how long finding them takes on this iPhone.
    @Test func findBeatsInThreeMinutes() throws {
        let samples = BeatTrackerTests.clicks(tempo: 124, seconds: 180, accent: true)
        let started = ContinuousClock.now
        let result = try #require(BeatTracker.beats(in: samples))
        let took = (ContinuousClock.now - started) / .seconds(1)
        print("EDITOR MOTION BEATS · 3 min in \(String(format: "%.2f", took)) s · \(String(format: "%.1f", result.tempo)) BPM · \(result.beats.count) beats")
        #expect(abs(result.tempo - 124) < 2)
    }

    /// Stabilize on a hand-held shake: a frame of the newest take held for 10 s (so the only movement is the shake) and shaken
    /// (`ShakenFootage`), then exported with each level; how well the analysis reads the known shake, and the shake measured
    /// on the shaken copy and on each stabilized export.
    @Test func stabilizeAShakenCopyOfTheNewestTake() async throws {
        KeepScreenAwake.enable()
        let original = try copyOfNewestTake()
        defer { try? FileManager.default.removeItem(at: original) }
        let still = try await StillClipWriter.write(frameOf: original, at: 3, length: 10)
        defer { EditMediaFiles.remove([still]) }
        let take = EditMediaFiles.url(for: still)
        let shaken = try await ShakenFootage.make(from: take, seconds: 10)
        defer {
            MotionAnalysisStore.remove(forRecording: shaken)
            try? FileManager.default.removeItem(at: shaken)
        }
        let steady = try await RealExports.MotionExportTests.meanShake(of: take)
        // The shaken copy through the same export as the stabilized ones (same frame rate), to compare like with like.
        let plainEdit = try await edit(for: shaken, aspect: .portrait)
        let plain = try await export(shaken, plainEdit, aspect: .portrait)
        defer { try? FileManager.default.removeItem(at: plain.url) }
        let shaking = try await RealExports.MotionExportTests.meanShake(of: plain.url)
        // How well the analysis reads the known wobble: its path against the truth (fractions of the frame, radians).
        let analysis = try await MotionAnalyzer().analyze(videoAt: shaken, continuing: nil, shouldStop: { false }, checkpoint: { _ in })
        MotionAnalysisStore.save(analysis, forRecording: shaken)
        var x = 0.0, y = 0.0, turn = 0.0
        var errors: [(Double, Double, Double)] = [], slopes: [(Double, Double)] = []
        let first = ShakenFootage.wobble(at: analysis.shifts.first.map { $0.time - 1.0 / 30 } ?? 0)
        for shift in analysis.shifts {
            x += shift.dx
            y += shift.dy
            turn += shift.angle
            let truth = ShakenFootage.wobble(at: shift.time)
            errors.append((x - (truth.dx - first.dx), y - (truth.dy - first.dy), turn - (truth.angle - first.angle)))
            slopes.append((x, truth.dx - first.dx))
        }
        let rms = { (values: [Double]) in sqrt(values.map { $0 * $0 }.reduce(0, +) / Double(max(1, values.count))) }
        let gain = slopes.map { $0.0 * $0.1 }.reduce(0, +) / max(0.000_001, slopes.map { $0.1 * $0.1 }.reduce(0, +))
        let percent = { (value: Double) in String(format: "%.2f", value * 100) }
        print(
            "EDITOR MOTION SHAKEN PATH · error x \(percent(rms(errors.map(\.0))))% y \(percent(rms(errors.map(\.1))))%"
                + " turn \(String(format: "%.4f", rms(errors.map(\.2)))) rad · wobble x \(percent(rms(slopes.map(\.1))))%"
                + " · gain x \(String(format: "%.2f", gain))"
        )
        var line = "EDITOR MOTION SHAKEN · take \(String(format: "%.2f", steady)) · shaken \(String(format: "%.2f", shaking)) px"
        for level in StabilizationLevel.allCases {
            var edit = try await edit(for: shaken, aspect: .portrait)
            var timeline = edit.timeline
            var clip = try #require(timeline.segments.first)
            clip.stabilization = level
            _ = timeline.replaceSegment(clip)
            edit.timeline = timeline
            let output = try await export(shaken, edit, aspect: .portrait)
            defer { try? FileManager.default.removeItem(at: output.url) }
            let after = try await RealExports.MotionExportTests.meanShake(of: output.url)
            let zoom = MotionAnalysisStore.complete(forRecording: shaken).flatMap { StabilizationPath.make($0, level: level)?.zoom } ?? 1
            line += " · \(level.rawValue) \(String(format: "%.2f", after)) px"
                + " (zoom \(String(format: "%.1f", (zoom - 1) * 100))%, export \(String(format: "%.1f", output.seconds)) s)"
        }
        print(line)
    }
}
