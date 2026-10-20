//
//  EyeContactDeviceTests.swift
//  Cue StudioTests
//

import AVFoundation
import CoreImage
import CoreVideo
import Foundation
import os
import Testing
@testable import Cue_Studio

/// Eye Contact on this iPhone, on a COPY of a take in its library (never the take itself): the model's load and run times, the
/// analysis's time per frame against the video's length, memory and heat, what share of frames get corrected and why the others
/// don't, and the correction's time per frame. The corrected video goes to the app's Documents (`eyecontact-<take>.mov`) to be
/// looked at frame by frame. Printed as `EYES …`.
///
/// Opt-in and on a device: `CUE_DEVICE="<iPhone>" scripts/test.sh device EyeContactDeviceTests`. `TEST_RUNNER_CUE_EYES_TAKE=<file
/// name>` picks the take (the newest by default), `TEST_RUNNER_CUE_EYES_SECONDS` how much of it is corrected (12), and
/// `TEST_RUNNER_CUE_EYES_STRENGTH` the strength (the default). `TEST_RUNNER_CUE_EYES_LONG=analysis`, then `=export` and `=export-plain`,
/// measure five minutes (the take repeated, kept in Documents as `eyecontact-long.mov` between the runs); `TEST_RUNNER_CUE_EYES_CLEANUP=1`
/// with `removesWhatTheseRunsLeft()` removes what the runs left there.
@Suite(
    "Eye Contact on this device",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["CUE_EYES_E2E"] != nil),
    .timeLimit(.minutes(5))
)
struct EyeContactDeviceTests {
    private var environment: [String: String] { ProcessInfo.processInfo.environment }

    @Test func faceMeshLoadsAndRunsQuickly() throws {
        let model = FaceMeshModel()
        let loadStart = ContinuousClock.now
        #expect(model.isAvailable)
        let load = (ContinuousClock.now - loadStart) / .milliseconds(1)
        let crop = try #require(Self.grayCrop())
        var times: [Double] = []
        for run in 0..<201 {
            let start = ContinuousClock.now
            let mesh = model.mesh(in: crop)
            if run > 0 { times.append((ContinuousClock.now - start) / .milliseconds(1)) }
            #expect(mesh?.points.count == FaceMesh.count)
        }
        times.sort()
        print(
            "EYES face mesh · load \(Self.ms(load)) ms · run p50 \(Self.ms(times[times.count / 2])) ms, "
                + "p95 \(Self.ms(times[times.count * 95 / 100])) ms (one 256-px face crop)"
        )
    }

    @Test func analyzesCorrectsAndMeasures() async throws {
        await KeepScreenAwake.enable()
        let original = try #require(pickTake(), "No takes on this iPhone")
        let copy = URL.temporaryDirectory.appending(path: "eyes-\(UUID().uuidString).\(original.pathExtension)")
        try FileManager.default.copyItem(at: original, to: copy)
        defer {
            try? FileManager.default.removeItem(at: copy)
            EyeContactAnalysisStore.remove(forRecording: copy)
        }
        let asset = AVURLAsset(url: copy)
        let duration = try await asset.load(.duration).seconds
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let (size, rate, transform) = try await track.load(.naturalSize, .nominalFrameRate, .preferredTransform)

        // Analysis, at the priority the app runs it.
        let base = MotionAnalysisDeviceTests.footprint()
        let peak = OSAllocatedUnfairLock(initialState: base)
        let watching = Task.detached {
            while !Task.isCancelled {
                let now = MotionAnalysisDeviceTests.footprint()
                peak.withLock { $0 = max($0, now) }
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
        let heatBefore = ProcessInfo.processInfo.thermalState
        let started = ContinuousClock.now
        let analysis = try await Task.detached(priority: .utility) {
            try await EyeContactAnalyzer().analyze(videoAt: copy, continuing: nil, focus: 0, shouldStop: { false }, checkpoint: { _ in })
        }.value
        let took = (ContinuousClock.now - started) / .seconds(1)
        watching.cancel()
        EyeContactAnalysisStore.save(analysis, forRecording: copy)
        let file = (try? Data(contentsOf: EyeContactAnalysisStore.url(forRecording: copy)))?.count ?? 0
        // Kept next to the corrected video, to compare with what Vision finds elsewhere.
        let kept = URL.documentsDirectory.appending(path: "eyecontact-\(original.deletingPathExtension().lastPathComponent).cueeyes")
        try? FileManager.default.removeItem(at: kept)
        try? FileManager.default.copyItem(at: EyeContactAnalysisStore.url(forRecording: copy), to: kept)
        print("EYES transform \(transform) · orientation \(EyeContactAnalyzer.orientation(of: transform).rawValue)")
        let faces = analysis.samples.filter { $0.face != nil }.count
        print(
            "EYES \(original.lastPathComponent) · \(Int(size.width))×\(Int(size.height)) \(Int(rate)) fps · \(String(format: "%.1f", duration)) s"
                + " · analysis \(String(format: "%.1f", took)) s (\(String(format: "%.2f", took / duration))× its length,"
                + " \(Self.ms(took * 1000 / Double(max(1, analysis.samples.count)))) ms a frame) · \(analysis.samples.count) frames, face in \(faces)"
                + " · memory +\((peak.withLock { $0 } - base) / 1_000_000) MB · heat \(MotionAnalysisDeviceTests.name(heatBefore)) → "
                + "\(MotionAnalysisDeviceTests.name(ProcessInfo.processInfo.thermalState)) · file \(file / 1000) KB"
        )
        #expect(analysis.isComplete)

        // Decisions.
        let planStart = ContinuousClock.now
        let plan = EyeGazePlan.make(analysis)
        let planTook = (ContinuousClock.now - planStart) / .milliseconds(1)
        var reasons: [EyeContactHold: Int] = [:]
        for hold in plan.holds.compactMap({ $0 }) { reasons[hold, default: 0] += 1 }
        let corrected = plan.frames.filter { $0 != nil }.count
        let most = plan.frames.compactMap { $0?.degrees }.max() ?? 0
        let full = plan.frames.compactMap { $0 }.filter { $0.degrees >= most * 0.99 }.count
        print(
            "EYES plan · \(Self.ms(planTook)) ms · corrected \(corrected)/\(plan.frames.count) (\(full) fully) · held: "
                + reasons.sorted { $0.value > $1.value }.map { "\($0.key.rawValue) \($0.value)" }.joined(separator: ", ")
        )
        let confidences = analysis.samples.compactMap { $0.face?.confidence }.sorted()
        if !confidences.isEmpty {
            let median = confidences[confidences.count / 2]
            print("EYES landmarks confidence · min \(String(format: "%.2f", confidences[0])) · median \(String(format: "%.2f", median))")
        }

        // Correction, frame by frame, written to Documents.
        let seconds = Double(environment["CUE_EYES_SECONDS"] ?? "") ?? 12
        let strength = EyeContactSettings.clamped(Double(environment["CUE_EYES_STRENGTH"] ?? "") ?? EyeContactSettings.defaultStrength)
        let renderer = EyeContactRenderer()
        let output = URL.documentsDirectory.appending(path: "eyecontact-\(original.deletingPathExtension().lastPathComponent).mov")
        try? FileManager.default.removeItem(at: output)
        let render = try await Self.correct(Run(
            asset: asset, track: track, transform: transform, seconds: seconds, plan: plan, strength: strength, renderer: renderer, output: output
        ))
        let patches = render.patchTimes.sorted()
        print(
            "EYES correction · strength \(strength) · \(render.frames) frames, \(patches.count) corrected"
                + " · patch p50 \(Self.ms(Self.percentile(patches, 50))) ms, p95 \(Self.ms(Self.percentile(patches, 95))) ms"
                + " · frame with the patch drawn p50 \(Self.ms(Self.percentile(render.frameTimes.sorted(), 50))) ms"
                + " · mean change inside the patch \(String(format: "%.2f", render.meanChange)) levels · written \(output.lastPathComponent)"
        )
        #expect(render.frames > 0)
    }

    // MARK: - Five minutes

    /// The long take used by the five-minute runs: the take repeated to five minutes (a passthrough copy, no re-encoding), kept in
    /// Documents between runs so the export run finds the analysis the analysis run made. Made once.
    private func longTake() async throws -> URL {
        let url = URL.documentsDirectory.appending(path: "eyecontact-long.mov")
        if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) { return url }
        let original = try #require(pickTake(), "No takes on this iPhone")
        let asset = AVURLAsset(url: original)
        let length = try await asset.load(.duration)
        let composition = AVMutableComposition()
        var cursor = CMTime.zero
        let target = CMTime(seconds: 300, preferredTimescale: 600)
        while CMTimeCompare(cursor, target) < 0 {
            let piece = CMTimeMinimum(length, CMTimeSubtract(target, cursor))
            try await composition.insertTimeRange(CMTimeRange(start: .zero, duration: piece), of: asset, at: cursor)
            cursor = CMTimeAdd(cursor, piece)
        }
        if let track = try await asset.loadTracks(withMediaType: .video).first, let copy = composition.tracks(withMediaType: .video).first {
            copy.preferredTransform = try await track.load(.preferredTransform)
        }
        let session = try #require(AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough))
        try await session.export(to: url, as: .mov)
        return url
    }

    /// Removes what these runs leave in Documents (the corrected videos, their analyses, the five-minute take) and a take copied there
    /// with `devicectl` for `TEST_RUNNER_CUE_EYES_TAKE=Documents/take.mov`. Never the app's own recordings. Opt in with
    /// `TEST_RUNNER_CUE_EYES_CLEANUP=1 … device "EyeContactDeviceTests/removesWhatTheseRunsLeft()"`.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["CUE_EYES_CLEANUP"] != nil))
    func removesWhatTheseRunsLeft() throws {
        let documents = URL.documentsDirectory
        let names = try FileManager.default.contentsOfDirectory(atPath: documents.path(percentEncoded: false))
        let left = names.filter { $0.hasPrefix("eyecontact-") || ["take.mov", "take.cueeyes"].contains($0) }
        for name in left {
            try FileManager.default.removeItem(at: documents.appending(path: name))
        }
        print("EYES removed \(left.count): \(left.sorted().joined(separator: ", "))")
    }

    /// Five minutes analyzed at the app's priority: time, memory and heat. Opt in with `TEST_RUNNER_CUE_EYES_LONG=analysis`.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["CUE_EYES_LONG"] == "analysis"))
    func analyzesFiveMinutes() async throws {
        await KeepScreenAwake.enable()
        let url = try await longTake()
        EyeContactAnalysisStore.remove(forRecording: url)
        let base = MotionAnalysisDeviceTests.footprint()
        let peak = OSAllocatedUnfairLock(initialState: base)
        let watching = Task.detached {
            while !Task.isCancelled {
                let now = MotionAnalysisDeviceTests.footprint()
                peak.withLock { $0 = max($0, now) }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
        let heat = OSAllocatedUnfairLock(initialState: [ProcessInfo.processInfo.thermalState])
        let started = ContinuousClock.now
        let analysis = try await Task.detached(priority: .utility) {
            try await EyeContactAnalyzer().analyze(
                videoAt: url, continuing: nil, focus: nil, shouldStop: { false },
                checkpoint: { analysis in
                    EyeContactAnalysisStore.save(analysis, forRecording: url)
                    heat.withLock { $0.append(ProcessInfo.processInfo.thermalState) }
                }
            )
        }.value
        let took = (ContinuousClock.now - started) / .seconds(1)
        watching.cancel()
        EyeContactAnalysisStore.save(analysis, forRecording: url)
        let planStart = ContinuousClock.now
        let plan = try #require(EyeContactAnalysisStore.plan(forRecording: url))
        let planTook = (ContinuousClock.now - planStart) / .milliseconds(1)
        let file = (try? Data(contentsOf: EyeContactAnalysisStore.url(forRecording: url)))?.count ?? 0
        let states = heat.withLock { $0 }.map(MotionAnalysisDeviceTests.name)
        print(
            "EYES five minutes · analysis \(String(format: "%.0f", took)) s (\(String(format: "%.2f", took / analysis.duration))× its length,"
                + " \(Self.ms(took * 1000 / Double(max(1, analysis.samples.count)))) ms a frame, \(analysis.samples.count) frames)"
                + " · memory +\((peak.withLock { $0 } - base) / 1_000_000) MB · heat \(states.first ?? "?") → \(states.last ?? "?")"
                + " (worst \(states.max() ?? "?")) · decisions \(Self.ms(planTook)) ms · file \(file / 1000) KB"
                + " · corrected \(plan.frames.filter { $0 != nil }.count)/\(plan.frames.count)"
        )
        #expect(analysis.isComplete)
    }

    /// Five minutes exported with Eye Contact (the analysis made by `analyzesFiveMinutes`), or without it for comparison
    /// (`export-plain`): time, memory and heat. Opt in with `TEST_RUNNER_CUE_EYES_LONG=export` or `=export-plain`.
    @Test(.enabled(if: ["export", "export-plain"].contains(ProcessInfo.processInfo.environment["CUE_EYES_LONG"] ?? "")))
    func exportsFiveMinutes() async throws {
        await KeepScreenAwake.enable()
        let url = try await longTake()
        let analysis = try #require(EyeContactAnalysisStore.load(forRecording: url), "Run TEST_RUNNER_CUE_EYES_LONG=analysis first")
        #expect(analysis.isComplete)
        var edit = TakeEdit(sourceDuration: analysis.duration, aspect: .portrait)
        let plain = ProcessInfo.processInfo.environment["CUE_EYES_LONG"] == "export-plain"
        edit.eyeContact = plain ? nil : EyeContactSettings()
        let base = MotionAnalysisDeviceTests.footprint()
        let peak = OSAllocatedUnfairLock(initialState: base)
        // Every 15 s too: a cost that's paid once stays flat, a leak climbs.
        let timeline = OSAllocatedUnfairLock(initialState: [Int]())
        let watching = Task.detached {
            var ticks = 0
            while !Task.isCancelled {
                let now = MotionAnalysisDeviceTests.footprint()
                peak.withLock { $0 = max($0, now) }
                if ticks % 60 == 0 { timeline.withLock { $0.append((now - base) / 1_000_000) } }
                ticks += 1
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
        let heatBefore = ProcessInfo.processInfo.thermalState
        let started = ContinuousClock.now
        let output = try await VideoExportService().export(
            videoAt: url, options: ExportOptions(aspect: .portrait, edit: edit, burnsInCaptions: false, shortSide: 1080, frameRate: 30)
        )
        let took = (ContinuousClock.now - started) / .seconds(1)
        watching.cancel()
        defer { try? FileManager.default.removeItem(at: output) }
        let size = (try? FileManager.default.attributesOfItem(atPath: output.path(percentEncoded: false))[.size] as? Int) ?? 0
        print(
            "EYES five minutes export\(plain ? " without Eye Contact" : "") · \(String(format: "%.0f", took)) s"
                + " (\(String(format: "%.2f", took / analysis.duration))× its length)"
                + " · memory +\((peak.withLock { $0 } - base) / 1_000_000) MB · heat \(MotionAnalysisDeviceTests.name(heatBefore)) → "
                + "\(MotionAnalysisDeviceTests.name(ProcessInfo.processInfo.thermalState)) · \(size / 1_000_000) MB"
                + " · memory every 15 s: \(timeline.withLock { $0 }.map { "+\($0)" }.joined(separator: " "))"
        )
    }

    // MARK: - Correcting

    private struct Rendered {
        var frames = 0
        var patchTimes: [Double] = []
        var frameTimes: [Double] = []
        var meanChange = 0.0
    }

    /// One frame drawn: its time, the buffer written, how long the patch and the whole frame took, how much the patch changed.
    /// `@unchecked Sendable`: the buffer is our own, written once before it's handed to the writer and never touched again.
    private struct Drawn: @unchecked Sendable {
        let time: CMTime
        let buffer: CVPixelBuffer
        let patchTime: Double?
        let change: Double?
        let frameTime: Double
    }

    /// What one correction run needs.
    private struct Run {
        let asset: AVURLAsset
        let track: AVAssetTrack
        let transform: CGAffineTransform
        let seconds: Double
        let plan: EyeGazePlan
        let strength: Double
        let renderer: EyeContactRenderer
        let output: URL
    }

    /// The first `seconds` of the take corrected and written to `output` (HEVC, the track's own orientation).
    private static func correct(_ run: Run) async throws -> Rendered {
        let reader = try AVAssetReader(asset: run.asset)
        reader.timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: run.seconds, preferredTimescale: 600))
        let readerOutput = AVAssetReaderTrackOutput(track: run.track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        let provider = reader.outputProvider(for: readerOutput)
        let size = try await run.track.load(.naturalSize)
        let width = Int(size.width) & ~1, height = Int(size.height) & ~1
        let writer = try AVAssetWriter(outputURL: run.output, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.hevc, AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 40_000_000],
        ])
        input.transform = run.transform
        let attributes = CVPixelBufferCreationAttributes(
            pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_32BGRA), size: CVImageSize(width: width, height: height)
        )
        let pixels = writer.inputPixelBufferReceiver(for: input, pixelBufferAttributes: attributes)
        try reader.start()
        try writer.start()
        writer.startSession(atSourceTime: .zero)
        let context = CIContext(options: [.cacheIntermediates: false])
        var result = Rendered()
        var changes: [Double] = []
        while let ready = try await provider.next() {
            // Everything that reads the reader's buffer happens inside: the frame written is a copy of our own. In its own autorelease
            // pool, so Core Image lets go of each frame (this loop never returns to one: memory grew a frame each frame without it).
            let drawn = ready.withUnsafeSampleBuffer { sample -> Drawn? in autoreleasepool {
                guard let source = sample.imageBuffer, let out = Self.makeBuffer(width: width, height: height) else { return nil }
                let frameStart = ContinuousClock.now
                var image = CIImage(cvPixelBuffer: source)
                var patchTime: Double?
                var change: Double?
                if let frame = run.plan.frame(at: sample.presentationTimeStamp.seconds, strength: run.strength) {
                    let start = ContinuousClock.now
                    let patches = run.renderer.patches(source: source, transform: run.transform, frame: frame, colorSpace: image.colorSpace)
                    patchTime = (ContinuousClock.now - start) / .milliseconds(1)
                    for patch in patches {
                        change = Self.meanChange(patch, over: image, context: context)
                        image = patch.composited(over: image)
                    }
                }
                context.render(image, to: out)
                return Drawn(
                    time: sample.presentationTimeStamp, buffer: out, patchTime: patchTime, change: change,
                    frameTime: (ContinuousClock.now - frameStart) / .milliseconds(1)
                )
            } }
            guard let drawn else { continue }
            if let patchTime = drawn.patchTime { result.patchTimes.append(patchTime) }
            if let change = drawn.change { changes.append(change) }
            result.frameTimes.append(drawn.frameTime)
            try await pixels.append(CVReadOnlyPixelBuffer(unsafeBuffer: drawn.buffer), with: drawn.time)
            result.frames += 1
        }
        pixels.finish()
        await writer.finishWriting()
        result.meanChange = changes.isEmpty ? 0 : changes.reduce(0, +) / Double(changes.count)
        return result
    }

    private static func makeBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(
            nil, width, height, kCVPixelFormatType_32BGRA, [kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()] as CFDictionary, &buffer
        )
        return buffer
    }

    /// How much the patch changes the frame under it, mean of |difference| in 0…255 levels over the patch.
    private static func meanChange(_ patch: CIImage, over frame: CIImage, context: CIContext) -> Double {
        let difference = patch.applyingFilter("CIDifferenceBlendMode", parameters: [kCIInputBackgroundImageKey: frame.cropped(to: patch.extent)])
        let average = difference.applyingFilter("CIAreaAverage", parameters: [kCIInputExtentKey: CIVector(cgRect: patch.extent)])
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(average, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        return Double(Int(pixel[0]) + Int(pixel[1]) + Int(pixel[2])) / 3
    }

    // MARK: - Helpers

    private func pickTake() -> URL? {
        if let name = environment["CUE_EYES_TAKE"] {
            // A take's file name, or a path in the app's container ("Documents/take.mov", copied there with devicectl).
            let url = name.contains("/")
                ? URL.documentsDirectory.deletingLastPathComponent().appending(path: name)
                : URL.applicationSupportDirectory.appending(path: "Takes/\(name)")
            return FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
        }
        return MotionAnalysisDeviceTests.newestTakes(1).first
    }

    private static func grayCrop() -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()] as CFDictionary
        CVPixelBufferCreate(nil, FaceRegion.cropSide, FaceRegion.cropSide, kCVPixelFormatType_32BGRA, attributes, &buffer)
        guard let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer) { memset(base, 128, CVPixelBufferGetBytesPerRow(buffer) * FaceRegion.cropSide) }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }

    private static func percentile(_ sorted: [Double], _ percent: Int) -> Double {
        sorted.isEmpty ? 0 : sorted[min(sorted.count - 1, sorted.count * percent / 100)]
    }

    private static func ms(_ value: Double) -> String { String(format: "%.1f", value) }
}
