//
//  EditedComposition.swift
//  Cue Studio
//

import AVFoundation

/// A take with its Quick edit applied, ready to play or export: the kept sections joined, the
/// processed sound, and a video composition that crops, adjusts and overlays every frame.
nonisolated struct EditedComposition: @unchecked Sendable {
    let asset: AVMutableComposition
    let videoComposition: AVVideoComposition

    struct Options: Sendable {
        var burnsInCaptions: Bool
        var watermark: Bool
        /// Height of the output's short side in pixels (1080 or 2160); nil keeps the recording's.
        var shortSide: CGFloat?
    }

    enum BuildError: Error {
        case noVideoTrack
    }

    /// `processedAudio` replaces the recording's sound when the Audio tool changed it.
    static func build(source: URL, edit: TakeEdit, processedAudio: URL?, options: Options) async throws -> EditedComposition {
        let asset = AVURLAsset(url: source)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else { throw BuildError.noVideoTrack }
        let (naturalSize, transform, frameRate) = try await videoTrack.load(.naturalSize, .preferredTransform, .nominalFrameRate)
        let audioAsset = processedAudio.map { AVURLAsset(url: $0) } ?? asset
        let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first

        let composition = AVMutableComposition()
        guard let video = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw BuildError.noVideoTrack
        }
        let audio = audioTrack == nil ? nil : composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        var cursor = CMTime.zero
        for span in edit.keptSpans {
            let range = CMTimeRange(
                start: CMTime(seconds: span.start, preferredTimescale: 600),
                duration: CMTime(seconds: span.duration, preferredTimescale: 600)
            )
            try video.insertTimeRange(range, of: videoTrack, at: cursor)
            if let audio, let audioTrack {
                try? audio.insertTimeRange(range, of: audioTrack, at: cursor)
            }
            cursor = cursor + range.duration
        }

        // The upright frame, the crop inside it, and the output size.
        let upright = CGRect(origin: .zero, size: naturalSize).applying(transform)
        let uprightSize = CGSize(width: abs(upright.width), height: abs(upright.height))
        let cropTopLeft = CropMath.crop(in: uprightSize, aspect: edit.aspect.widthOverHeight, offset: edit.cropOffset)
        // Core Image measures y from the bottom.
        let crop = CGRect(x: cropTopLeft.minX, y: uprightSize.height - cropTopLeft.maxY, width: cropTopLeft.width, height: cropTopLeft.height)
        let renderSize = outputSize(for: crop.size, shortSide: options.shortSide)

        var overlays: [FrameOverlay] = []
        if options.burnsInCaptions, edit.showsCaptions {
            overlays += OverlayRenderer.captions(edit.editedCaptions, style: edit.captionStyle, position: edit.captionPosition, frame: crop.size)
        }
        if options.watermark, let badge = OverlayRenderer.watermark(frame: crop.size) {
            overlays.append(badge)
        }
        let instruction = CompositionInstruction(
            timeRange: CMTimeRange(start: .zero, duration: cursor),
            trackID: video.trackID,
            transform: transform,
            crop: crop,
            edit: edit,
            overlays: overlays,
            outputScale: crop.width > 0 ? renderSize.width / crop.width : 1
        )
        let configuration = AVVideoComposition.Configuration(
            customVideoCompositorClass: CueVideoCompositor.self,
            frameDuration: CMTime(value: 1, timescale: CMTimeScale(max(24, frameRate.rounded()))),
            instructions: [instruction],
            renderScale: 1,
            renderSize: renderSize
        )
        return EditedComposition(asset: composition, videoComposition: AVVideoComposition(configuration: configuration))
    }

    /// The crop at the requested quality, with even dimensions. Never upscaled.
    static func outputSize(for crop: CGSize, shortSide: CGFloat?) -> CGSize {
        guard let shortSide, crop.width > 0, crop.height > 0 else {
            return CGSize(width: CropMath.even(crop.width), height: CropMath.even(crop.height))
        }
        let scale = min(1, shortSide / min(crop.width, crop.height))
        return CGSize(width: CropMath.even(crop.width * scale), height: CropMath.even(crop.height * scale))
    }
}
