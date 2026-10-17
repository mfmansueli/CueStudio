//
//  CoverCompositionRenderer+ItemImage.swift
//  Cue Studio
//

import UIKit

/// A cover graphic drawn on its own transparent picture, turned, with room for its shadow: what a graphic over the video is
/// (`TextOverlayRenderer`), so a graphic looks the same on the cover and in the video.
nonisolated extension CoverCompositionRenderer {
    /// `item` drawn as it would be on a cover `coverWidth` wide (its center in the middle of the picture).
    static func image(of item: CoverItem, coverWidth: CGFloat) -> UIImage? {
        let cover = CGSize(width: coverWidth, height: coverWidth * 16 / 9)
        let shape = size(of: item, coverSize: cover)
        guard shape.width > 0, shape.height > 0 else { return nil }
        let turned = CGRect(origin: .zero, size: shape).applying(CGAffineTransform(rotationAngle: CGFloat(item.rotation)))
        let margin = coverWidth * 0.02
        let canvas = CGSize(width: (abs(turned.width) + margin * 2).rounded(.up), height: (abs(turned.height) + margin * 2).rounded(.up))
        var placed = item
        placed.center = OverlayPoint(x: Double(canvas.width / 2 / cover.width), y: Double(canvas.height / 2 / cover.height))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: canvas, format: format).image { renderer in
            draw(placed, size: cover, in: renderer.cgContext)
        }
    }
}
