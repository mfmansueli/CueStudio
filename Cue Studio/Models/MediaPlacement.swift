//
//  MediaPlacement.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Where a photo or video laid over the take sits on a frame, and how its picture fills that
/// place. Pure, so the preview's handles, the compositor and the tests use the same numbers.
nonisolated enum MediaPlacement {
    /// The media's place on a frame of `size`, from the top left.
    static func rect(for media: MediaOverlay, in size: CGSize) -> CGRect {
        guard media.layout == .window, size.width > 0, size.height > 0 else { return CGRect(origin: .zero, size: size) }
        let aspect = CGFloat(media.shape.aspect ?? media.aspect)
        var width = size.width * CGFloat(min(max(media.width, MediaOverlay.widthRange.lowerBound), MediaOverlay.widthRange.upperBound))
        var height = width / max(aspect, 0.01)
        if height > size.height {
            height = size.height
            width = height * aspect
        }
        let center = media.center.clamped
        var x = CGFloat(center.x) * size.width - width / 2
        var y = CGFloat(center.y) * size.height - height / 2
        // Always whole inside the frame.
        x = min(max(0, x), size.width - width)
        y = min(max(0, y), size.height - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Scale and offset that make a picture of `content` size cover `target` (cropping what spills
    /// over, centered): the picture's origin goes to `offset`, relative to the target's origin.
    static func fill(_ content: CGSize, into target: CGSize) -> (scale: CGFloat, offset: CGPoint) {
        guard content.width > 0, content.height > 0 else { return (1, .zero) }
        let scale = max(target.width / content.width, target.height / content.height)
        let offset = CGPoint(
            x: (target.width - content.width * scale) / 2,
            y: (target.height - content.height * scale) / 2
        )
        return (scale, offset)
    }
}
