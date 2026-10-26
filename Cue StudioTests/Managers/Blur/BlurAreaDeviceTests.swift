//
//  BlurAreaDeviceTests.swift
//  Cue StudioTests
//

import AVFoundation
import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// Blur area and Mask on this iPhone, on links to its newest takes (read only, never changed; the links go after): how many
/// frames a second the editor's preview composition draws with three areas (Blur, Pixelate, Solid, moving) and with a circle
/// mask on a video in a window, against the take alone; how long Vision takes to track a face for five seconds, and the
/// motion analysis's face follow; and how long a 1080p export takes with the areas. Printed as `BLUR …`.
///
/// Opt-in and on a device: `CUE_DEVICE="<iPhone>" scripts/test.sh device BlurAreaDeviceTests`.
@MainActor
@Suite("Blur area on this device", .serialized, .enabled(if: ProcessInfo.processInfo.environment["CUE_BLUR_E2E"] != nil), .timeLimit(.minutes(5)))
struct BlurAreaDeviceTests {
    private func link(_ original: URL) throws -> URL {
        let link = URL.temporaryDirectory.appending(path: "blur-\(UUID().uuidString).\(original.pathExtension)")
        do {
            try FileManager.default.linkItem(at: original, to: link)
        } catch {
            try FileManager.default.copyItem(at: original, to: link)
        }
        return link
    }

    private func edit(for take: URL) async throws -> TakeEdit {
        let duration = try await AVURLAsset(url: take).load(.duration).seconds
        var edit = TakeEdit(sourceDuration: duration, aspect: .portrait)
        edit.voiceEnhancement = .off
        return edit
    }

    /// Three areas moving across the frame over the whole take: Blur, Pixelate and Solid.
    private func threeAreas(seconds: TimeInterval) -> [BlurRegion] {
        [BlurStyle.blur, .pixelate, .solid].enumerated().map { index, style in
            var region = BlurRegion(
                target: .recording(nil), span: TimeSpan(start: 0, end: seconds),
                box: NormalizedBox(x: 0.1, y: 0.15 + Double(index) * 0.25, width: 0.3, height: 0.18)
            )
            region.style = style
            region.keyframes = [
                BlurKeyframe(time: 0, box: NormalizedBox(x: 0.05, y: 0.15 + Double(index) * 0.25, width: 0.3, height: 0.18)),
                BlurKeyframe(time: seconds, box: NormalizedBox(x: 0.6, y: 0.15 + Double(index) * 0.25, width: 0.3, height: 0.18)),
            ]
            return region
        }
    }

    /// Frames a second the editor's preview composition is drawn at, reading `seconds` of it as fast as it comes.
    private func drawingRate(of take: URL, edit: TakeEdit, seconds: TimeInterval) async throws -> Double {
        let composition = try await EditRenderRequest.prepare(
            source: take, edit: edit, purpose: .editorPreview(rendersCurveSound: false), sounds: RecordingSoundCache()
        ).build()
        let reader = try AVAssetReader(asset: composition.asset)
        reader.timeRange = CMTimeRange(start: CMTime(seconds: 1, preferredTimescale: 600), duration: CMTime(seconds: seconds, preferredTimescale: 600))
        let tracks = try await composition.asset.loadTracks(withMediaType: .video)
        let output = AVAssetReaderVideoCompositionOutput(videoTracks: tracks, videoSettings: nil)
        output.videoComposition = composition.videoComposition
        let provider = reader.outputProvider(for: output)
        try reader.start()
        let started = ContinuousClock.now
        var frames = 0
        while try await provider.next() != nil { frames += 1 }
        return Double(frames) / max(0.001, (ContinuousClock.now - started) / .seconds(1))
    }

    @Test func thePreviewDrawsAreasAndAMaskFastEnough() async throws {
        KeepScreenAwake.enable()
        let originals = MotionAnalysisDeviceTests.newestTakes(2)
        try #require(!originals.isEmpty, "No takes on this iPhone")
        let take = try link(originals[0])
        let other = try link(originals[originals.count > 1 ? 1 : 0])
        let name = try EditMediaFiles.link(other)
        defer {
            try? FileManager.default.removeItem(at: take)
            try? FileManager.default.removeItem(at: other)
            EditMediaFiles.remove([name])
        }
        let plain = try await edit(for: take)
        let seconds = min(4, max(1, plain.sourceDuration - 1.5))
        var areas = plain
        areas.blurRegions = threeAreas(seconds: plain.sourceDuration)
        var masked = plain
        var window = MediaOverlay(kind: .video, fileName: name, aspect: 9.0 / 16, mediaDuration: 4, span: TimeSpan(start: 0, end: plain.sourceDuration))
        window.layout = .window
        window.width = 0.6
        window.followsCuts = true
        window.mask = MediaMask(shape: .circle, placement: MaskPlacement(width: 0.8, height: 0.45, feather: 0.4))
        masked.media = [window]
        var both = masked
        both.blurRegions = areas.blurRegions
        let alone = try await drawingRate(of: take, edit: plain, seconds: seconds)
        let three = try await drawingRate(of: take, edit: areas, seconds: seconds)
        let mask = try await drawingRate(of: take, edit: masked, seconds: seconds)
        let all = try await drawingRate(of: take, edit: both, seconds: seconds)
        print(String(format: "BLUR preview fps · take alone %.0f · three areas %.0f · masked window %.0f · areas and mask %.0f", alone, three, mask, all))
        // The preview plays at 30 frames a second without dropping any.
        #expect(three >= 30)
        #expect(all >= 30)
    }

    @Test func trackingAFaceTakesSoLittle() async throws {
        KeepScreenAwake.enable()
        let originals = MotionAnalysisDeviceTests.newestTakes(1)
        let original = try #require(originals.first, "No takes on this iPhone")
        let take = try link(original)
        defer { try? FileManager.default.removeItem(at: take) }
        let duration = try await AVURLAsset(url: take).load(.duration).seconds
        let at = min(1, duration / 3), until = min(duration, at + 5)
        let faces = await FaceFinder().faces(in: take, isVideo: true, at: at) ?? []
        let face = faces.first.map { NormalizedBox(x: $0.minX, y: $0.minY, width: $0.width, height: $0.height) }
            ?? NormalizedBox(center: CGPoint(x: 0.5, y: 0.35), width: 0.2, height: 0.12)
        let area = BlurRegion.area(aroundFace: face)
        let started = ContinuousClock.now
        let samples = try await ObjectTracker().track(videoAt: take, box: area, at: at, until: until) { _ in }
        let elapsed = (ContinuousClock.now - started) / .seconds(1)
        let followed = (samples.last?.time ?? at) - at
        print(String(format: "BLUR tracking · %@ · %.1f s of video followed in %.1f s (%.0f frames a second) · %d samples",
                     faces.isEmpty ? "no face found, a box" : "a face", followed, elapsed, Double(samples.count) / max(0.001, elapsed), samples.count))
        if let analysis = MotionAnalysisStore.complete(forRecording: original) {
            let span = TimeSpan(start: 0, end: analysis.duration)
            let started = ContinuousClock.now
            let result = BlurFollowing.followFace(analysis.subjects, area: area, face: face, at: at, through: span)
            let took = (ContinuousClock.now - started) / .seconds(1)
            print(String(format: "BLUR face follow from the analysis · %.0f s of video in %.3f s · %d keyframes · %.1f s unchecked",
                         analysis.duration, took, result.keyframes.count, result.unchecked.reduce(0) { $0 + $1.duration }))
        } else {
            print("BLUR face follow from the analysis · this take isn't analyzed yet")
        }
        #expect(followed <= 0 || elapsed < followed * 2, "Tracking should run faster than half real time")
    }

    @Test func exportingWithAreasTakesAboutAsLong() async throws {
        KeepScreenAwake.enable()
        let originals = MotionAnalysisDeviceTests.newestTakes(1)
        let original = try #require(originals.first, "No takes on this iPhone")
        let take = try link(original)
        defer { try? FileManager.default.removeItem(at: take) }
        var edit = try await edit(for: take)
        edit.timeline.trimEnd(to: min(edit.sourceDuration, 10))
        func export(_ edit: TakeEdit) async throws -> Double {
            let started = ContinuousClock.now
            let output = try await VideoExportService(sounds: RecordingSoundCache()).export(
                videoAt: take, options: ExportOptions(aspect: .portrait, edit: edit, shortSide: 1080, frameRate: 30)
            )
            try? FileManager.default.removeItem(at: output)
            return (ContinuousClock.now - started) / .seconds(1)
        }
        let plain = try await export(edit)
        edit.blurRegions = threeAreas(seconds: edit.sourceDuration)
        let areas = try await export(edit)
        print(String(format: "BLUR export 1080p of %.1f s · plain %.1f s · three areas %.1f s", edit.editedDuration, plain, areas))
        #expect(areas < plain * 1.6 + 1)
    }
}
