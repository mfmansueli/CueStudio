//
//  FramePipeline.swift
//  Cue Studio
//

import CoreImage
import CoreVideo
import Foundation

/// The one way a frame of a recording becomes the edit's picture, for the video (`CueVideoCompositor`) and the cover
/// (`CoverRenderer`) alike: upright, held steady (Stabilize), cut to the take's frame where Follow face has it (or fitted on
/// black), scaled to the take's frame, Skin Smoothing found on the frame as recorded, the background put behind the creator,
/// then Adjust and Filters (`FrameLook`). A clip's zoom goes on after (`zoomed`). Whatever frames the video next frames the
/// cover too.
nonisolated enum FramePipeline {
    /// A frame of a track turned upright, its corner at the origin.
    static func upright(_ source: CVPixelBuffer, transform: CGAffineTransform) -> CIImage {
        let image = CIImage(cvPixelBuffer: source)
            .transformed(by: uprightTransform(transform, sourceHeight: CGFloat(CVPixelBufferGetHeight(source))))
        return image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
    }

    /// The track transform is in UIKit coordinates (origin top left); Core Image's origin is at the bottom left, so the
    /// rotation is flipped around the frame.
    static func uprightTransform(_ transform: CGAffineTransform, sourceHeight: CGFloat) -> CGAffineTransform {
        let flip = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -sourceHeight)
        return flip.concatenating(transform).concatenating(CGAffineTransform(scaleX: 1, y: -1))
    }

    /// An upright frame (corner at the origin) steadied, cropped and scaled to the take's frame, with its background effect,
    /// Skin Smoothing, Adjust and Filters, as `framing` says. `mask` finds the person in a frame for a background (the key
    /// names the moment, for a cache).
    static func framed(
        _ upright: CIImage, as framing: Framing, skin: SkinSmoother, mask: (_ image: CIImage, _ key: String) -> CIImage?
    ) -> CIImage {
        let frame = framing.frame, look = framing.look, moment = framing.moment, sourceTime = framing.sourceTime
        var image = upright
        if let steady = frame.steady {
            image = steadied(image, by: steady, at: sourceTime)
        }
        if framing.cropFit == .fit {
            image = fitted(image, into: frame.crop.size)
        } else {
            let crop = frame.cropRect(at: sourceTime)
            image = image.cropped(to: crop)
                .transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
        }
        if abs(frame.scale - 1) > 0.000_1 {
            image = image.transformed(by: CGAffineTransform(scaleX: frame.scale, y: frame.scale))
        }
        // The faces of the frame as recorded (before a background is put behind the creator), found only when the dial is above 0.
        let smoothing = skin.pass(for: image, value: look.skinSmoothing, stream: moment.stream, epoch: moment.stretch, time: moment.time)
        if let background = frame.background {
            image = BackgroundCompositing.apply(image, render: background) { image in
                mask(image, background.cacheKey + framing.key)
            }
        }
        return FrameLook.apply(look, to: image, skin: smoothing, time: framing.lookTime)
    }

    /// `image` scaled around its center, cropped back to its frame (a section's slow zoom).
    static func zoomed(_ image: CIImage, by scale: CGFloat) -> CIImage {
        guard abs(scale - 1) > 0.000_1 else { return image }
        let extent = image.extent
        return image
            .transformed(by: CGAffineTransform(translationX: -extent.midX, y: -extent.midY)
                .concatenating(CGAffineTransform(scaleX: scale, y: scale))
                .concatenating(CGAffineTransform(translationX: extent.midX, y: extent.midY)))
            .cropped(to: extent)
    }

    /// Stabilize: the upright frame moved and turned onto the smooth path, zoomed in to hide its edges, cut back to its size.
    static func steadied(_ image: CIImage, by path: StabilizationPath, at time: TimeInterval) -> CIImage {
        let extent = image.extent
        let correction = path.correction(at: time)
        let center = CGPoint(x: extent.midX, y: extent.midY)
        let zoom = CGFloat(path.zoom)
        // Down on screen is −y in Core Image, clockwise is a negative angle.
        let transform = CGAffineTransform(translationX: -center.x, y: -center.y)
            .concatenating(CGAffineTransform(rotationAngle: -CGFloat(correction.angle)))
            .concatenating(CGAffineTransform(scaleX: zoom, y: zoom))
            .concatenating(CGAffineTransform(
                translationX: center.x + CGFloat(correction.dx) * extent.width, y: center.y - CGFloat(correction.dy) * extent.height
            ))
        return image.clampedToExtent().transformed(by: transform).cropped(to: extent)
    }

    /// Crop › Fit: the whole upright frame scaled to fit in `size`, centered on black.
    static func fitted(_ image: CIImage, into size: CGSize) -> CIImage {
        let extent = image.extent
        guard extent.width > 0, extent.height > 0, size.width > 0, size.height > 0 else { return image }
        let scale = min(size.width / extent.width, size.height / extent.height)
        let width = extent.width * scale
        let height = extent.height * scale
        let placed = image
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: (size.width - width) / 2, y: (size.height - height) / 2))
        let black = CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: size))
        return placed.composited(over: black)
    }
}
