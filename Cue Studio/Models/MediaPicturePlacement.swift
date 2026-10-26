//
//  MediaPicturePlacement.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// How a photo's or video's upright picture lands on the frame at a moment, as the compositor draws it: in its place (a window,
/// the whole frame, or a support's area of the split screen), filling it as its framing says (always Fill outside the split
/// screen), then moved and scaled by its keyframes and preset. Turns points of the picture or of its place into points of the
/// frame and back (fractions, from the top left), for the handles of a mask and of a Blur area on it. Pure.
nonisolated struct MediaPicturePlacement: Sendable {
    let frameSize: CGSize
    /// Its place on the frame, in pixels from the top left.
    let rect: CGRect
    /// How the picture fills the place (place coordinates).
    let placed: SplitPlacement.Placement
    /// Where its keyframes have its place's middle (fractions of the frame) and how big, at the moment; nil: as placed.
    var motion: (center: OverlayPoint, scale: Double)?

    init(media: MediaOverlay, pictureSize: CGSize, frameSize: CGSize, splitLayout: SplitLayout? = nil, motion: OverlayMotion.State? = nil) {
        self.frameSize = frameSize
        var framing = media.areaFraming ?? AreaFraming()
        if media.layout == .split, let splitLayout {
            rect = SplitPlacement.areas(splitLayout, in: frameSize).support
        } else {
            rect = MediaPlacement.rect(for: media, in: frameSize)
            framing.fit = .fill
        }
        placed = SplitPlacement.place(pictureSize, in: rect.size, framing: framing)
        if media.layout != .split, let motion {
            self.motion = (motion.center.clamped, motion.scale)
        }
    }

    // MARK: - The place

    /// The frame's point (fractions) showing `point` of the place (fractions of its rect).
    func framePoint(forPlace point: OverlayPoint) -> OverlayPoint {
        frame(CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height))
    }

    /// The place's point (fractions of its rect) under `point` of the frame.
    func placePoint(forFrame point: OverlayPoint) -> OverlayPoint {
        let pixels = unmoved(point)
        return OverlayPoint(x: (pixels.x - rect.minX) / max(1, rect.width), y: (pixels.y - rect.minY) / max(1, rect.height))
    }

    /// The place on the frame (fractions), as its keyframes have it.
    var placeOnFrame: CGRect {
        let topLeft = framePoint(forPlace: OverlayPoint(x: 0, y: 0)), bottomRight = framePoint(forPlace: OverlayPoint(x: 1, y: 1))
        return CGRect(x: topLeft.x, y: topLeft.y, width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y)
    }

    /// Times its keyframes scale it at the moment.
    var scale: Double { motion?.scale ?? 1 }

    // MARK: - The picture

    /// The frame's point (fractions) showing `point` of the picture (fractions of it).
    func framePoint(forPicture point: CGPoint) -> OverlayPoint {
        frame(CGPoint(x: rect.minX + placed.origin.x + point.x * placed.size.width, y: rect.minY + placed.origin.y + point.y * placed.size.height))
    }

    /// The picture's point (fractions of it) under `point` of the frame.
    func picturePoint(forFrame point: OverlayPoint) -> CGPoint {
        let pixels = unmoved(point)
        return CGPoint(
            x: (pixels.x - rect.minX - placed.origin.x) / max(1, placed.size.width),
            y: (pixels.y - rect.minY - placed.origin.y) / max(1, placed.size.height)
        )
    }

    /// The frame's rect (fractions) showing `box` of the picture.
    func frameRect(forPicture box: NormalizedBox) -> CGRect {
        let topLeft = framePoint(forPicture: CGPoint(x: box.x, y: box.y))
        let bottomRight = framePoint(forPicture: CGPoint(x: box.x + box.width, y: box.y + box.height))
        return CGRect(x: topLeft.x, y: topLeft.y, width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y)
    }

    /// The picture's box under `rect` of the frame (fractions).
    func pictureBox(forFrame rect: CGRect) -> NormalizedBox {
        let topLeft = picturePoint(forFrame: OverlayPoint(x: rect.minX, y: rect.minY))
        let bottomRight = picturePoint(forFrame: OverlayPoint(x: rect.maxX, y: rect.maxY))
        return NormalizedBox(x: topLeft.x, y: topLeft.y, width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y)
    }

    // MARK: - Moving

    /// Pixels of the frame (as placed) to fractions, through the keyframes' move and scale around the place's middle.
    private func frame(_ pixels: CGPoint) -> OverlayPoint {
        guard frameSize.width > 0, frameSize.height > 0 else { return .center }
        var point = pixels
        if let motion {
            let center = CGPoint(x: motion.center.x * frameSize.width, y: motion.center.y * frameSize.height)
            point = CGPoint(x: center.x + (pixels.x - rect.midX) * motion.scale, y: center.y + (pixels.y - rect.midY) * motion.scale)
        }
        return OverlayPoint(x: point.x / frameSize.width, y: point.y / frameSize.height)
    }

    /// Fractions of the frame back to its pixels as placed, before the keyframes moved it.
    private func unmoved(_ point: OverlayPoint) -> CGPoint {
        let pixels = CGPoint(x: point.x * frameSize.width, y: point.y * frameSize.height)
        guard let motion, motion.scale > 0 else { return pixels }
        let center = CGPoint(x: motion.center.x * frameSize.width, y: motion.center.y * frameSize.height)
        return CGPoint(x: rect.midX + (pixels.x - center.x) / motion.scale, y: rect.midY + (pixels.y - center.y) / motion.scale)
    }
}
