//
//  VideoExportService.swift
//  Cue Studio
//

import AVFoundation
import UIKit

/// Crops takes to their frame and, when needed, burns in the "Made with Cue" badge.
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
        guard needsCrop || options.watermark else {
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
        var configuration = AVVideoComposition.Configuration(
            frameDuration: CMTime(value: 1, timescale: CMTimeScale(max(24, frameRate.rounded()))),
            instructions: [instruction],
            renderSize: crop.size
        )
        if options.watermark {
            configuration.animationTool = watermarkTool(renderSize: crop.size)
        }

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
        if edit.volume != 1 || edit.enhancesVoice || edit.reducesNoise, options.edit != nil {
            let audio = try await AudioTrackExtractor.extract(from: source)
            let volume = edit.volume, enhances = edit.enhancesVoice, reduces = edit.reducesNoise
            processedAudio = try await Task.detached {
                try AudioEnhancer.process(audio, volume: volume, enhancesVoice: enhances, reducesNoise: reduces)
            }.value
        }
        let composition = try await EditedComposition.build(
            source: source, edit: edit, processedAudio: processedAudio,
            options: .init(burnsInCaptions: options.burnsInCaptions, watermark: options.watermark, shortSide: options.shortSide)
        )
        guard let session = AVAssetExportSession(asset: composition.asset, presetName: AVAssetExportPresetHEVCHighestQuality) else {
            throw VideoExportError.exportUnavailable
        }
        session.videoComposition = composition.videoComposition
        let output = URL.temporaryDirectory.appending(path: "Cue-\(UUID().uuidString.prefix(8)).mov")
        try await session.export(to: output, as: .mov)
        return output
    }

    // MARK: - Watermark

    /// Bottom-right badge: a yellow line and "Made with Cue", sized relative to the frame width.
    private func watermarkTool(renderSize: CGSize) -> AVVideoCompositionCoreAnimationTool {
        let parent = CALayer()
        parent.frame = CGRect(origin: .zero, size: renderSize)
        let video = CALayer()
        video.frame = parent.frame
        parent.addSublayer(video)

        let unit = renderSize.width / 402
        let fontSize = 12 * unit
        let text = String(localized: "Made with Cue")
        let font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
        let badgeSize = CGSize(width: textWidth + 34 * unit, height: 26 * unit)
        let margin = 18 * unit

        let badge = CALayer()
        // Core Animation's origin is bottom-left inside the video composition.
        badge.frame = CGRect(
            x: renderSize.width - badgeSize.width - margin, y: margin * 2,
            width: badgeSize.width, height: badgeSize.height
        )
        badge.backgroundColor = UIColor.black.withAlphaComponent(0.45).cgColor
        badge.cornerRadius = 8 * unit

        let line = CALayer()
        line.frame = CGRect(x: 10 * unit, y: (badgeSize.height - 3 * unit) / 2, width: 12 * unit, height: 3 * unit)
        line.backgroundColor = UIColor(red: 1, green: 0.84, blue: 0.04, alpha: 1).cgColor
        line.cornerRadius = 1.5 * unit
        badge.addSublayer(line)

        let label = CATextLayer()
        label.string = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: UIColor.white.withAlphaComponent(0.85),
        ])
        label.contentsScale = 2
        label.frame = CGRect(x: 28 * unit, y: (badgeSize.height - fontSize * 1.25) / 2, width: textWidth + 2, height: fontSize * 1.3)
        badge.addSublayer(label)
        parent.addSublayer(badge)

        return AVVideoCompositionCoreAnimationTool(configuration: .init(postProcessingAsVideoLayer: video, containingLayer: parent))
    }
}
