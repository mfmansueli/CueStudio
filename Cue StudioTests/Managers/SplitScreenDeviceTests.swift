//
//  SplitScreenDeviceTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

/// The split screen on this iPhone, on links to its newest takes (read only, never changed; the links go after): how many frames a second the
/// editor's preview composition draws (the take alone, with a support in the split screen, and the worst case the editor
/// allows: a support and two windows, three videos over the take) and how long a 1080p export takes with and without the
/// split screen. Above the take's own frame rate, the preview plays without dropping frames. Printed as `SPLIT …`.
///
/// Opt-in and on a device: `CUE_DEVICE="<iPhone>" scripts/test.sh device SplitScreenDeviceTests`.
@MainActor
@Suite(
    "Split screen on this device",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["CUE_SPLIT_E2E"] != nil),
    .timeLimit(.minutes(5))
)
struct SplitScreenDeviceTests {
    /// Links to the newest takes (hard links: no bytes copied, and only read): the first is the main video, the others are laid
    /// over it (a take is reused when there are fewer). Deleting a link leaves the take whole.
    private func copiesOfNewestTakes(_ count: Int) throws -> [URL] {
        let takes = MotionAnalysisDeviceTests.newestTakes(count)
        try #require(!takes.isEmpty, "No takes on this iPhone")
        return try (0..<count).map { index in
            let original = takes[index % takes.count]
            let link = URL.temporaryDirectory.appending(path: "split-\(UUID().uuidString).\(original.pathExtension)")
            do {
                try FileManager.default.linkItem(at: original, to: link)
            } catch {
                try FileManager.default.copyItem(at: original, to: link)
            }
            return link
        }
    }

    /// A video laid over the take from 1 s, for `seconds`.
    private func media(_ url: URL, layout: MediaLayout, seconds: TimeInterval) async throws -> MediaOverlay {
        let name = try EditMediaFiles.link(url)
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        var media = MediaOverlay(kind: .video, fileName: name, aspect: 9.0 / 16, mediaDuration: duration, span: TimeSpan(start: 1, end: 1 + seconds))
        media.layout = layout
        media.followsCuts = true
        media.width = 0.35
        return media
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
        let elapsed = (ContinuousClock.now - started) / .seconds(1)
        return Double(frames) / max(0.001, elapsed)
    }

    @Test func thePreviewDrawsTheSplitScreenFastEnough() async throws {
        KeepScreenAwake.enable()
        let files = try copiesOfNewestTakes(4)
        var names: [String] = []
        defer {
            for file in files { try? FileManager.default.removeItem(at: file) }
            EditMediaFiles.remove(Set(names))
        }
        let take = files[0]
        let track = try #require(try await AVURLAsset(url: take).loadTracks(withMediaType: .video).first)
        let (size, rate) = try await track.load(.naturalSize, .nominalFrameRate)
        let duration = try await AVURLAsset(url: take).load(.duration).seconds
        let seconds = min(5, max(2, duration - 2))
        var edit = TakeEdit(sourceDuration: duration, aspect: .portrait)
        edit.voiceEnhancement = .off
        let alone = try await drawingRate(of: take, edit: edit, seconds: seconds)
        print("SPLIT PREVIEW take alone \(String(format: "%.0f", alone)) fps")

        // The first split screen's own seam: Blur, the costliest.
        edit.splitScreen.setLayout(SplitLayout(seam: .blur))
        let support = try await media(files[1], layout: .split, seconds: seconds)
        names.append(support.fileName)
        edit.media = [support]
        let split = try await drawingRate(of: take, edit: edit, seconds: seconds)
        print("SPLIT PREVIEW with a support \(String(format: "%.0f", split)) fps")

        var windows: [MediaOverlay] = []
        for (index, file) in files.dropFirst(2).enumerated() {
            var window = try await media(file, layout: .window, seconds: seconds)
            window.center = OverlayPoint(x: index == 0 ? 0.3 : 0.7, y: 0.75)
            window.layer = index + 1
            names.append(window.fileName)
            windows.append(window)
        }
        edit.media = [support] + windows
        let worst = try await drawingRate(of: take, edit: edit, seconds: seconds)

        print(
            "SPLIT PREVIEW \(Int(size.width))×\(Int(size.height)) at \(String(format: "%.0f", rate)) fps · \(String(format: "%.1f", seconds)) s"
                + " · take alone \(String(format: "%.0f", alone)) fps · with a support \(String(format: "%.0f", split)) fps"
                + " · a support and two windows \(String(format: "%.0f", worst)) fps"
        )
        #expect(split >= Double(rate) * 0.9, "The split screen draws slower than the take plays")
    }

    @Test func aSplitScreenExportTakes() async throws {
        KeepScreenAwake.enable()
        let files = try copiesOfNewestTakes(2)
        var names: [String] = []
        defer {
            for file in files { try? FileManager.default.removeItem(at: file) }
            EditMediaFiles.remove(Set(names))
        }
        let take = files[0]
        let duration = try await AVURLAsset(url: take).load(.duration).seconds
        let seconds = min(30, max(2, duration - 2))
        var edit = TakeEdit(sourceDuration: duration, aspect: .portrait)
        edit.voiceEnhancement = .off
        edit.timeline = EditTimeline(sourceDuration: duration, keeping: [TimeSpan(start: 0, end: min(duration, seconds + 2))])
        func export() async throws -> Double {
            let started = ContinuousClock.now
            let output = try await VideoExportService(sounds: RecordingSoundCache()).export(
                videoAt: take, options: ExportOptions(aspect: .portrait, edit: edit, shortSide: 1080, frameRate: 30)
            )
            try? FileManager.default.removeItem(at: output)
            return (ContinuousClock.now - started) / .seconds(1)
        }
        let plain = try await export()
        edit.splitScreen.setLayout(SplitLayout())
        let support = try await media(files[1], layout: .split, seconds: seconds)
        names.append(support.fileName)
        edit.media = [support]
        let split = try await export()
        print(
            "SPLIT EXPORT \(String(format: "%.1f", seconds + 2)) s at 1080p · take alone \(String(format: "%.1f", plain)) s"
                + " · with a support over \(String(format: "%.1f", seconds)) s \(String(format: "%.1f", split)) s"
        )
    }
}
