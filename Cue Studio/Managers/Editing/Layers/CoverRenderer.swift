//
//  CoverRenderer.swift
//  Cue Studio
//

import AVFoundation
import CoreImage
import UIKit

/// Draws a take's cover: a frame of the recording (cropped to the take's frame, with its look) or
/// a photo filling that frame, then the title set like the edit's texts. All on the device.
nonisolated enum CoverRenderer {
    /// Width of the cover image in pixels.
    static let width: CGFloat = 1080

    static func image(for cover: VideoCover, videoURL: URL, edit: TakeEdit, width: CGFloat = CoverRenderer.width) async -> UIImage? {
        let aspect = CGFloat(edit.aspect.widthOverHeight)
        let size = CGSize(width: width.rounded(), height: (width / aspect).rounded())
        let picture: UIImage?
        switch cover.source {
        case .frame(let time):
            picture = await frame(of: videoURL, at: time, edit: edit).map { UIImage(cgImage: $0) }
        case .photo(let fileName):
            // Drawing a UIImage honors its orientation.
            picture = UIImage(contentsOfFile: EditMediaFiles.url(for: fileName).path(percentEncoded: false))
        }
        guard let picture else { return nil }
        let title = cover.titleOverlay.flatMap { TextOverlayRenderer.image(for: $0, frameWidth: size.width) }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let content = picture.size
            let fill = MediaPlacement.fill(content, into: size)
            picture.draw(in: CGRect(
                x: fill.offset.x, y: fill.offset.y,
                width: content.width * fill.scale, height: content.height * fill.scale
            ))
            if let title, let overlay = cover.titleOverlay {
                let center = overlay.center
                title.draw(at: CGPoint(
                    x: (CGFloat(center.x) * size.width - title.size.width / 2).rounded(),
                    y: (CGFloat(center.y) * size.height - title.size.height / 2).rounded()
                ))
            }
        }
    }

    /// The frame at `time` of the recording, upright, cropped like the edit and with its look.
    private static func frame(of url: URL, at time: TimeInterval, edit: TakeEdit) async -> CGImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        guard let result = try? await generator.image(at: CMTime(seconds: max(0, time), preferredTimescale: 600)) else { return nil }
        let full = result.image
        let crop = CropMath.crop(
            in: CGSize(width: full.width, height: full.height),
            aspect: edit.aspect.widthOverHeight, offset: edit.cropOffset
        )
        guard let cropped = full.cropping(to: crop) else { return full }
        var image = CIImage(cgImage: cropped)
        if edit.cropFit == .fit {
            // Fit: the whole frame on black, like the video.
            image = CueVideoCompositor.fitted(CIImage(cgImage: full), into: crop.size)
        }
        // The take's background, like the video.
        if let effect = edit.background(for: nil), let render = BackgroundRender.prepare(effect, cacheKey: "cover") {
            image = BackgroundCompositing.apply(image, render: render) { PersonMasker.mask(for: $0) }
        }
        let looked = FrameLook.apply(edit, to: image)
        return CIContext(options: [.cacheIntermediates: false]).createCGImage(looked, from: looked.extent) ?? cropped
    }
}
