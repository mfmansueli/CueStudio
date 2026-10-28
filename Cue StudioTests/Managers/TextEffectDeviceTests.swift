//
//  TextEffectDeviceTests.swift
//  Cue StudioTests
//

import AVFoundation
import CoreImage
import Foundation
import Testing
@testable import Cue_Studio

/// What the six text effects cost on this iPhone, on a creator's sentence at 1080 wide:
/// - paint: the first frame of a text with the effect, its layers painted (then kept in `TextEffectCache`);
/// - frame: each frame of its way in after that, composed and drawn by Core Image on the GPU (p50 and max);
/// - pick-up: the picture that follows the fingers when a gesture starts on the text, on the main thread
///   (`TextOverlayRenderer.drawing` at the video's width, its effect where it is in its motion, its painting found in the
///   cache the preview filled);
/// - side tab: the text painted anew with longer lines, away from the main thread (`TextPictureDrawer`);
/// - and a video with three effects coming in, staying and going at once: frames a second the compositor gives the preview and
///   the export, as fast as it can (the preview plays 30), beside the take alone and the same three as plain titles.
///
/// Opt-in and on a device: `CUE_DEVICE=<iPhone> scripts/test.sh device TextEffectDeviceTests`
/// (`TEST_RUNNER_CUE_TEXT_EFFECTS_E2E=1`).
@MainActor
@Suite(
    "Text effects on this device",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["CUE_TEXT_EFFECTS_E2E"] != nil)
)
struct TextEffectDeviceTests {
    private static let words = "Três dicas para gravar melhor"
    private static let frameRate = 30.0

    private var uptime: TimeInterval { ProcessInfo.processInfo.systemUptime }

    /// Seconds the GPU programs took to be ready, the first time anything asked for them in this run.
    private static let readiness: TimeInterval = {
        let started = ProcessInfo.processInfo.systemUptime
        _ = TextEffectRenderer.shared
        return ProcessInfo.processInfo.systemUptime - started
    }()

    private func text(_ preset: TypePreset, center: OverlayPoint = OverlayPoint(x: 0.5, y: 0.5)) -> TextOverlay {
        var text = TextOverlay(role: .title, look: preset.look(for: .title), preset: preset, span: TimeSpan(start: 0.2, end: 3.8))
        text.text = Self.words
        text.center = center
        return text
    }

    @Test(arguments: TypePreset.effectPresets)
    func anEffectsFramesFitInAFrame(_ preset: TypePreset) throws {
        KeepScreenAwake.enable()
        let ready = Self.readiness
        TextEffectCache.shared.removeAll()
        let text = text(preset)
        let effect = try #require(text.effect)
        let request = try #require(TextOverlayRenderer.effectRequest(
            for: text, frameWidth: 1080, widthFraction: TextOverlayRenderer.maxWidthFraction
        ))
        let context = CIContext(options: [.cacheIntermediates: false])
        let painting = uptime
        let sprites = try #require(TextEffectCache.shared.sprites(for: request))
        let paint = uptime - painting
        let length = text.span.duration
        let entrance = TextEffectChoreography.timing(effect, length: length).entrance
        var frames: [TimeInterval] = []
        // The drawing's room at rest holds every frame of its way in (what moves stays inside its bleed).
        let room = sprites.rest().extent.integral.insetBy(dx: -64, dy: -64)
        let target = try Self.pixelBuffer(width: Int(room.width), height: Int(room.height))
        for index in 1..<Int((entrance * Self.frameRate).rounded(.up)) {
            let started = uptime
            let image = TextEffectComposer.image(sprites, effect: effect, time: Double(index) / Self.frameRate, length: length)
                .transformed(by: CGAffineTransform(translationX: -room.minX, y: -room.minY))
            if !image.extent.isEmpty {
                try context.startTask(toRender: image, to: CIRenderDestination(pixelBuffer: target)).waitUntilCompleted()
            }
            frames.append(uptime - started)
        }
        let picking = uptime
        _ = TextOverlayRenderer.drawing(for: text, frameWidth: 1080, time: entrance / 2, length: length)
        let pickUp = uptime - picking
        var wider = text
        wider.block = TextBlock(width: TextOverlayRenderer.currentLineWidth(of: text) * 1.2, size: text.size)
        let widening = uptime
        _ = TextOverlayRenderer.drawing(for: wider, frameWidth: 1080, time: entrance / 2, length: length)
        let sideTab = uptime - widening
        let line = "TEXT EFFECT \(preset.rawValue) · paint \(Self.ms(paint)) · frame \(Self.stats(frames)) · pick-up \(Self.ms(pickUp))"
            + " · side tab \(Self.ms(sideTab)) · GPU programs ready in \(Self.ms(ready))"
        print(line)
        Attachment.record(line, named: "text-effect-\(preset.rawValue).txt")
        let sorted = frames.sorted()
        #expect(sorted[sorted.count / 2] < 1 / Self.frameRate, "A frame of its way in should take less than a frame")
        // The fingers never wait a frame for the picture to be picked up.
        #expect(pickUp < 1 / 60)
    }

    @Test func threeEffectsComingInAtOncePlayInRealTime() async throws {
        KeepScreenAwake.enable()
        let take = try await TestFootage.make(seconds: 4, width: 1080, height: 1920)
        defer { try? FileManager.default.removeItem(at: take) }
        var plain = TakeEdit(sourceDuration: 4, aspect: .portrait)
        plain.voiceEnhancement = .off
        let places = [OverlayPoint(x: 0.5, y: 0.22), OverlayPoint(x: 0.5, y: 0.5), OverlayPoint(x: 0.5, y: 0.78)]
        var titles = plain
        titles.texts = places.map { text(.cue, center: $0) }
        var effects = plain
        effects.texts = zip([TypePreset.gold, .wave, .neon], places).map { text($0, center: $1) }
        let preview = EditRenderPurpose.editorPreview(rendersCurveSound: true)
        let alone = try await drawingRate(take, plain, preview)
        let typed = try await drawingRate(take, titles, preview)
        let moving = try await drawingRate(take, effects, preview)
        let exported = try await drawingRate(take, effects, .export(burnsInCaptions: true, shortSide: 1080, frameRate: 30))
        let line = String(
            format: "TEXT EFFECTS preview fps · take alone %.0f · three titles %.0f · three effects %.0f · export with three effects %.0f",
            alone, typed, moving, exported
        )
        print(line)
        Attachment.record(line, named: "text-effects-three.txt")
        // The preview plays 30 frames a second without dropping any.
        #expect(moving >= Self.frameRate)
    }

    /// Frames a second `edit`'s composition draws for `purpose`, as fast as it can, over the texts' time (painting included).
    private func drawingRate(_ take: URL, _ edit: TakeEdit, _ purpose: EditRenderPurpose) async throws -> Double {
        TextEffectCache.shared.removeAll()
        let built = try await EditRenderRequest.prepare(source: take, edit: edit, purpose: purpose, sounds: RecordingSoundCache()).build()
        let reader = try AVAssetReader(asset: built.asset)
        reader.timeRange = CMTimeRange(start: CMTime(seconds: 0.2, preferredTimescale: 600), end: CMTime(seconds: 3.8, preferredTimescale: 600))
        let tracks = try await built.asset.loadTracks(withMediaType: .video)
        let output = AVAssetReaderVideoCompositionOutput(videoTracks: tracks, videoSettings: nil)
        output.videoComposition = built.videoComposition
        let provider = reader.outputProvider(for: output)
        try reader.start()
        let started = ContinuousClock.now
        var frames = 0
        while try await provider.next() != nil { frames += 1 }
        return Double(frames) / max(0.001, (ContinuousClock.now - started) / .seconds(1))
    }

    // MARK: - Reading

    private static func pixelBuffer(width: Int, height: Int) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let attributes: [String: Any] = [kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](), kCVPixelBufferMetalCompatibilityKey as String: true]
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &buffer)
        return try #require(buffer)
    }

    private static func stats(_ values: [TimeInterval]) -> String {
        let sorted = values.sorted()
        guard let max = sorted.last else { return "–" }
        return "p50 \(ms(sorted[sorted.count / 2])) max \(ms(max))"
    }

    private static func ms(_ seconds: TimeInterval) -> String {
        String(format: "%.1f ms", seconds * 1000)
    }
}
