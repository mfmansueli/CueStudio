//
//  FramePipeline.swift
//  Cue Studio
//

import CoreImage
import CoreVideo
import Foundation

/// The one way a frame of a recording becomes the edit's picture, for the video (`CueVideoCompositor`) and the cover
/// (`CoverRenderer`) alike: upright, its Blur areas hidden (`BlurDrawing`, on the frame as recorded, so everything after
/// carries them along), held steady (Stabilize), turned, mirrored and cropped as the clip says, cut to the take's frame where Follow face has it (or fitted on
/// black), scaled to the take's frame, Skin's faces found on the frame as recorded, the background put behind the creator,
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

    /// An upright frame (corner at the origin) steadied, cropped and scaled to the take's frame, with its background effect (or the
    /// photo or video Behind you), Skin, Adjust and Filters, as `framing` says. `mask` finds the person in a frame for a background
    /// (the moment names the frame, for a cache, and the stream it plays in, so its masks are steadied in order).
    static func framed(
        _ upright: CIImage, as framing: Framing, skin: SkinSmoother, mask: (_ image: CIImage, _ moment: PersonMaskMoment) -> CIImage?
    ) -> CIImage {
        let frame = framing.frame, look = framing.look, moment = framing.moment, sourceTime = framing.sourceTime
        var image = BlurDrawing.apply(framing.blurs, to: upright)
        if let steady = frame.steady {
            image = steadied(image, by: steady, at: sourceTime)
        }
        image = oriented(image, by: frame.orientation)
        if let area = framing.area {
            // A split screen's main area: framed from the whole recording, so the area reaches what Format's crop would cut.
            image = inArea(image, size: area.size, framing: area.framing)
        } else if framing.cropFit == .fit {
            image = fitted(image, into: frame.crop.size)
        } else {
            let crop = frame.cropRect(at: sourceTime)
            image = image.cropped(to: crop)
                .transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
        }
        if framing.area == nil, abs(frame.scale - 1) > 0.000_1 {
            image = image.transformed(by: CGAffineTransform(scaleX: frame.scale, y: frame.scale))
        }
        // The faces of the frame as recorded (before a background is put behind the creator), found only when Skin has something on.
        let smoothing = skin.pass(for: image, skin: look.skin, stream: moment.stream, epoch: moment.stretch, time: moment.time)
        // Behind you takes the place of the recording's own background while it shows, with the same cutout and place.
        if let render = framing.backdrop == nil ? frame.background : frame.background ?? frame.cutout {
            image = BackgroundCompositing.apply(image, render: render, backdrop: framing.backdrop) { image in
                let track = render.cacheKey + (moment.stream == .main ? "-main" : "-blend")
                return mask(image, PersonMaskMoment(key: render.cacheKey + framing.key, track: track, epoch: moment.stretch, time: moment.time))
            }
        }
        return FrameLook.apply(look, to: image, skin: smoothing, time: framing.lookTime)
    }

    /// A picture (corner at the origin) in an area of `size` as `framing` says (`SplitPlacement.place`), the area's corner at
    /// the origin, on black where it doesn't reach.
    static func inArea(_ image: CIImage, size: CGSize, framing: AreaFraming) -> CIImage {
        let bounds = CGRect(origin: .zero, size: size)
        let placed = SplitPlacement.place(image.extent.size, in: size, framing: framing)
        // Core Image's y grows upward: the picture's top left corner goes `origin.y` below the area's top.
        let moved = image
            .transformed(by: CGAffineTransform(scaleX: placed.scale, y: placed.scale))
            .transformed(by: CGAffineTransform(translationX: placed.origin.x, y: size.height - placed.origin.y - placed.size.height))
            .cropped(to: bounds)
        return moved.composited(over: CIImage(color: .black).cropped(to: bounds))
    }

    /// `image` scaled around `pivot` (fractions of it, from the top left: its center unless a zoom grows toward a face,
    /// `ZoomAnchor`), cropped back to its frame (a clip's zoom, a phrase zoom). Any point inside keeps the frame filled.
    static func zoomed(_ image: CIImage, by scale: CGFloat, around pivot: OverlayPoint = .center) -> CIImage {
        guard abs(scale - 1) > 0.000_1 else { return image }
        let extent = image.extent
        // Core Image's y grows upward: a pivot down from the top is up from the bottom.
        let x = extent.minX + CGFloat(pivot.x) * extent.width, y = extent.maxY - CGFloat(pivot.y) * extent.height
        return image
            .transformed(by: CGAffineTransform(translationX: -x, y: -y)
                .concatenating(CGAffineTransform(scaleX: scale, y: scale))
                .concatenating(CGAffineTransform(translationX: x, y: y)))
            .cropped(to: extent)
    }

    /// A clip's Animation at a moment (`ClipAnimationWindow.state`): its framed picture blurred, scaled around its middle, moved
    /// (fractions of the frame, +y down) and faded, over black where it doesn't reach.
    static func animated(_ image: CIImage, _ state: ClipAnimationFrame) -> CIImage {
        let extent = image.extent
        var moved = image
        if state.blur > 0.000_1 {
            moved = moved.clampedToExtent().applyingGaussianBlur(sigma: state.blur * extent.width).cropped(to: extent)
        }
        let scale = CGFloat(state.scale)
        // Core Image's y grows upward: down on screen is −y.
        moved = moved
            .transformed(by: CGAffineTransform(translationX: -extent.midX, y: -extent.midY)
                .concatenating(CGAffineTransform(scaleX: scale, y: scale))
                .concatenating(CGAffineTransform(
                    translationX: extent.midX + CGFloat(state.dx) * extent.width, y: extent.midY - CGFloat(state.dy) * extent.height
                )))
            .cropped(to: extent)
        if state.opacity < 0.999 {
            moved = moved.applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(max(0, state.opacity)))])
        }
        return moved.composited(over: CIImage(color: .black).cropped(to: extent))
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

    /// Rotate, Mirror and Crop of a clip: the upright frame (corner at the origin) turned by quarter turns clockwise, flipped left
    /// to right, then cut to the crop (`ClipOrientation`), its corner back at the origin.
    static func oriented(_ image: CIImage, by orientation: ClipOrientation) -> CIImage {
        guard !orientation.isIdentity else { return image }
        var image = image
        let width = image.extent.width, height = image.extent.height
        // Core Image's y grows upward: a quarter turn clockwise is (x, y) → (y, width − x).
        switch orientation.quarterTurns {
        case 1: image = image.transformed(by: CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: width))
        case 2: image = image.transformed(by: CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: width, ty: height))
        case 3: image = image.transformed(by: CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: height, ty: 0))
        default: break
        }
        image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
        if orientation.isMirrored {
            image = image.transformed(by: CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: image.extent.width, ty: 0))
        }
        if let crop = orientation.crop {
            let size = image.extent.size
            let kept = orientation.size(of: CGSize(width: width, height: height))
            let left = min((crop.minX * size.width).rounded(), size.width - kept.width)
            let top = min((crop.minY * size.height).rounded(), size.height - kept.height)
            let rect = CGRect(x: max(0, left), y: max(0, size.height - top - kept.height), width: kept.width, height: kept.height)
            image = image.cropped(to: rect).transformed(by: CGAffineTransform(translationX: -rect.minX, y: -rect.minY))
        }
        return image
    }

    /// A still picture (a frame read upright) reshaped as a clip says, for a copy shown on screen; nil when it can't be drawn.
    static func oriented(_ picture: CGImage, by orientation: ClipOrientation) -> CGImage? {
        guard !orientation.isIdentity else { return picture }
        let image = oriented(CIImage(cgImage: picture), by: orientation)
        return stillContext.createCGImage(image, from: image.extent)
    }

    private static let stillContext = CIContext(options: [.cacheIntermediates: false, .name: "studio.cue.clipShape"])

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
