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
    func export(videoAt source: URL, options: ExportOptions) async throws -> URL {
        if options.needsEditRenderer {
            return try await exportEdited(videoAt: source, options: options)
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
            try FileManager.default.copyItem(at: source, to: output)
            return output
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
        try await session.export(to: output, as: .mov)
        return output
    }

    // MARK: - Edited

    /// Quick edit, captions and quality: the same composition the preview plays, exported.
    private func exportEdited(videoAt source: URL, options: ExportOptions) async throws -> URL {
        let asset = AVURLAsset(url: source)
        let duration = try await asset.load(.duration).seconds
        var edit = options.edit ?? TakeEdit(sourceDuration: duration, aspect: options.aspect)
        edit.aspect = options.aspect
        var processedAudio: URL?
        if edit.voiceProcessing.isNeeded, options.edit != nil {
            processedAudio = try await Self.processedAudio(for: source, edit: edit)
        }
        let composition = try await EditedComposition.build(
            source: source, edit: edit, processedAudio: processedAudio, speech: await Self.voiceActivity(for: source, edit: edit),
            options: .init(burnsInCaptions: options.burnsInCaptions, shortSide: options.shortSide)
        )
        // More than the take's sound: mixed once through a limiter so nothing clips.
        let mixedDown = try await MasterMix.apply(to: composition)
        guard let session = AVAssetExportSession(asset: composition.asset, presetName: AVAssetExportPresetHEVCHighestQuality) else {
            throw VideoExportError.exportUnavailable
        }
        session.videoComposition = composition.videoComposition
        // A mixed-down sound already has its volumes in it.
        session.audioMix = mixedDown ? nil : composition.audioMix
        // Like the preview: speed changes keep the voice's pitch.
        session.audioTimePitchAlgorithm = .spectral
        let output = URL.temporaryDirectory.appending(path: "Cue-\(UUID().uuidString.prefix(8)).mov")
        try await session.export(to: output, as: .mov)
        return output
    }

    /// Where someone speaks in the recordings the edit plays; nothing when no music ducks.
    private static func voiceActivity(for source: URL, edit: TakeEdit) async -> VoiceActivity {
        guard edit.ducksMusic else { return .none }
        var activity = VoiceActivity()
        activity.take = await speechSpans(in: source)
        for clip in edit.playedSources {
            activity.sources[clip.id] = await speechSpans(in: EditMediaFiles.url(for: clip.fileName))
        }
        return activity
    }

    private static func speechSpans(in video: URL) async -> [TimeSpan] {
        guard let audio = try? await AudioTrackExtractor.extract(from: video) else { return [] }
        defer { try? FileManager.default.removeItem(at: audio) }
        return await Task.detached { (try? VoiceActivity.spans(inAudio: audio)) ?? [] }.value
    }

    /// The Voice tool's sound for the whole recording; nil when the take has no sound.
    private static func processedAudio(for source: URL, edit: TakeEdit) async throws -> URL? {
        let audio: URL
        do {
            audio = try await AudioTrackExtractor.extract(from: source)
        } catch AudioTrackExtractor.ExtractError.noAudio {
            return nil
        }
        let processing = edit.voiceProcessing
        return try await Task.detached {
            try AudioEnhancer.process(audio, processing: processing)
        }.value
    }
}
