//
//  VideoExportService.swift
//  Cue Studio
//

import AVFoundation
import UIKit

/// Crops takes to their frame, or renders their Quick edit. Exports carry no watermark: the free
/// plan limits how many videos are exported, never how they look.
@MainActor
@Observable
final class VideoExportService: VideoExporting {
    /// Studio Voice's sounds, shared with the preview: what it already treated isn't treated again.
    private let sounds: RecordingSoundCache
    /// The script libraries: an export lets the families its words need arrive first (`fontWait`).
    private let fontPacks: FontPackStore?

    init(sounds: RecordingSoundCache = .shared, fontPacks: FontPackStore? = nil) {
        self.sounds = sounds
        self.fontPacks = fontPacks
    }

    /// The longest an export waits for a script's face to download before it draws those words in the system's face (and says so:
    /// `ExportResult.unavailableFonts`).
    static let fontWait = Duration.seconds(15)

    func export(videoAt source: URL, options: ExportOptions, progress: (@MainActor (ExportProgress) -> Void)?) async throws -> ExportResult {
        // A cancel stops every stage (the fonts' wait, Studio Voice, the motion analysis, the mix, the frames) and leaves only what
        // others use: Studio Voice's sounds and the motion analyses, which a retry and the preview read again.
        try Task.checkCancellation()
        progress?(.preparing)
        if options.needsEditRenderer {
            return try await exportEdited(videoAt: source, options: options, progress: progress)
        }
        let asset = AVURLAsset(url: source)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoExportError.noVideoTrack
        }
        let (naturalSize, transform, frameRate) = try await track.load(.naturalSize, .preferredTransform, .nominalFrameRate)
        let duration = try await asset.load(.duration)

        // The recorder stores portrait video as landscape pixels plus a rotation transform.
        let orientedRect = CGRect(origin: .zero, size: naturalSize).applying(transform)
        let oriented = CGSize(width: abs(orientedRect.width), height: abs(orientedRect.height))
        let crop = CropMath.centeredCrop(in: oriented, aspect: options.aspect.widthOverHeight)
        let output = URL.temporaryDirectory.appending(path: "Cue-\(UUID().uuidString.prefix(8)).mov")

        let needsCrop = abs(crop.width - oriented.width) > 2 || abs(crop.height - oriented.height) > 2
        guard needsCrop else {
            try await Self.writing(output) { try FileManager.default.copyItem(at: source, to: output) }
            return ExportResult(url: output)
        }

        var layer = AVVideoCompositionLayerInstruction.Configuration(assetTrack: track)
        let toOrigin = CGAffineTransform(translationX: -orientedRect.minX - crop.minX, y: -orientedRect.minY - crop.minY)
        layer.setTransform(transform.concatenating(toOrigin), at: .zero)
        let instruction = AVVideoCompositionInstruction(configuration: .init(
            layerInstructions: [AVVideoCompositionLayerInstruction(configuration: layer)],
            timeRange: CMTimeRange(start: .zero, duration: duration)
        ))
        let configuration = AVVideoComposition.Configuration(
            frameDuration: CMTime(value: 1, timescale: CMTimeScale(max(24, frameRate.rounded()))),
            instructions: [instruction],
            renderSize: crop.size
        )

        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoExportError.exportUnavailable
        }
        session.videoComposition = AVVideoComposition(configuration: configuration)
        try await Self.run(session, to: output, progress: progress)
        return ExportResult(url: output)
    }

    /// Writes the frames, telling `progress` how far it is (`.rendering`, 0 to 1, as the session measures it).
    private static func run(
        _ session: AVAssetExportSession, to output: URL, progress: (@MainActor (ExportProgress) -> Void)?
    ) async throws {
        progress?(ExportProgress(.rendering, fraction: 0))
        let watcher = progress.map { progress in
            Task { @MainActor in
                for await state in session.states(updateInterval: 0.1) {
                    if case .exporting(let done) = state { progress(ExportProgress(.rendering, fraction: done.fractionCompleted)) }
                }
            }
        }
        defer { watcher?.cancel() }
        try await writing(output) { try await session.export(to: output, as: .mov) }
        progress?(ExportProgress(.rendering, fraction: 1))
    }

    /// Runs `write`, which makes `output`. A stopped or failed one leaves no half-written file behind, and iOS stopping it
    /// while Cue is in the background (`AVError.operationInterrupted`) comes out as `VideoExportError.interrupted`.
    static func writing(_ output: URL, _ write: () async throws -> Void) async throws {
        do {
            try await write()
        } catch {
            try? FileManager.default.removeItem(at: output)
            if let error = error as? AVError, error.code == .operationInterrupted { throw VideoExportError.interrupted }
            throw error
        }
    }

    // MARK: - Edited

    /// Quick edit, captions and quality: the same composition the preview plays, exported. Its stages are told as they come
    /// (`ExportProgress`): the fonts while they download, the motion analysis with how far it is, the sound, then the frames.
    private func exportEdited(
        videoAt source: URL, options: ExportOptions, progress: (@MainActor (ExportProgress) -> Void)?
    ) async throws -> ExportResult {
        let asset = AVURLAsset(url: source)
        let duration = try await asset.load(.duration).seconds
        var edit = options.edit ?? TakeEdit(sourceDuration: duration, aspect: options.aspect)
        edit.aspect = options.aspect
        // The faces its words need, if they aren't here yet: asked for and waited for, at most `fontWait`. From here to the
        // end, a face that arrives waits for the export to finish, so the video never changes face halfway through.
        let needs = FontPackNeeds.needs(in: edit, han: FontPackRegistry.shared.hanReading)
        if let fontPacks {
            if !fontPacks.unavailable(needs).isEmpty { progress?(ExportProgress(.fonts)) }
            fontPacks.request(needs)
            await fontPacks.awaitDownloads(needs, timeout: Self.fontWait)
            try Task.checkCancellation()
        }
        FontPackRegistry.shared.beginExport()
        defer { if FontPackRegistry.shared.endExport() { fontPacks?.heldFacesArrived() } }
        // From here the faces are fixed for this export: what isn't drawn now comes out in the system's face, and the result says so.
        let unavailable = fontPacks?.unavailable(needs) ?? []
        let missingCustom = Set(edit.customFontUses.map(\.family).filter { !CustomFontRegistry.shared.has($0) })
        let purpose = EditRenderPurpose.export(burnsInCaptions: options.burnsInCaptions, shortSide: options.shortSide, frameRate: options.frameRate)
        try await Self.analyzeMotion(of: source, drawing: RenderPlan(edit, purpose: purpose).drawn, progress: progress)
        // The preview's preparation (`EditRenderRequest`): a take never edited plays its own sound.
        let treatsSound = options.edit != nil
        if treatsSound { progress?(ExportProgress(.sound)) }
        let request = try await EditRenderRequest.prepare(source: source, edit: edit, purpose: purpose, treatsSound: treatsSound, sounds: sounds)
        try Task.checkCancellation()
        let composition: EditedComposition
        do {
            composition = try await request.build()
        } catch EditedComposition.BuildError.tooWarm {
            throw VideoExportError.tooWarm
        }
        try Task.checkCancellation()
        if Mixdown.isNeeded(for: composition) { progress?(ExportProgress(.sound)) }
        // More than the take's sound: mixed once through a limiter so nothing clips. The mix is this export's alone: it goes once the
        // video is written, done, failed or cancelled (never Studio Voice's sounds, which the preview shares: `RecordingSoundCache`).
        let mixed = try await Mixdown.apply(to: composition)
        defer { if let mixed { try? FileManager.default.removeItem(at: mixed) } }
        try Task.checkCancellation()
        guard let session = AVAssetExportSession(asset: composition.asset, presetName: AVAssetExportPresetHEVCHighestQuality) else {
            throw VideoExportError.exportUnavailable
        }
        session.videoComposition = composition.videoComposition
        // A mixed-down sound already has its volumes in it.
        session.audioMix = mixed == nil ? composition.audioMix : nil
        // Like the preview: speed changes keep the voice's pitch.
        session.audioTimePitchAlgorithm = .spectral
        let output = URL.temporaryDirectory.appending(path: "Cue-\(UUID().uuidString.prefix(8)).mov")
        try await Self.run(session, to: output, progress: progress)
        return ExportResult(url: output, unavailableFonts: unavailable, missingCustomFamilies: missingCustom)
    }

    /// Follow face and Stabilize's analyses the edit still needs, made before anything else with how far they are (`.motion`); the
    /// build then finds them ready. Nothing is told when none is missing.
    private static func analyzeMotion(
        of source: URL, drawing edit: TakeEdit, progress: (@MainActor (ExportProgress) -> Void)?
    ) async throws {
        guard EditedComposition.usesMotion(edit) else { return }
        var told: (@Sendable (Double) -> Void)?
        if let progress {
            told = { fraction in
                Task { @MainActor in progress(ExportProgress(.motion, fraction: fraction)) }
            }
        }
        do {
            _ = try await EditedComposition.motionAnalyses(take: source, edit: edit, analyzesMissing: true, progress: told)
        } catch EditedComposition.BuildError.tooWarm {
            throw VideoExportError.tooWarm
        }
        try Task.checkCancellation()
    }
}
