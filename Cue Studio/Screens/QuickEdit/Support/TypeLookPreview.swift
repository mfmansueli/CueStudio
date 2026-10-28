//
//  TypeLookPreview.swift
//  Cue Studio
//

import UIKit

/// A sample of a type look drawn exactly as the export draws it (`TextOverlayRenderer`), its shadow and effect included, at
/// three pixels per point so it stays sharp in a small card. Kept once drawn (the presets don't change), up to `mostKept`.
enum TypeLookPreview {
    private struct Key: Hashable {
        let look: TextLook
        let use: TextUse
        let sample: String
    }

    private static var cache: [Key: UIImage] = [:]
    /// Samples kept at most: past it, they're drawn again as they're asked for.
    private static let mostKept = 96

    static func image(_ look: TextLook, use: TextUse, sample: String) -> UIImage? {
        let key = Key(look: look, use: use, sample: sample)
        if let cached = cache[key] { return cached }
        let span = TimeSpan(start: 0, end: 1)
        let text: TextOverlay
        switch use {
        case .title:
            var title = TextOverlay(role: .title, look: look, preset: nil, span: span)
            title.text = sample
            text = title
        case .caption:
            text = TextOverlay.caption(sample, look: look, position: .middle, span: span)
        }
        let width = TextOverlayRenderer.referenceWidth * 3
        let fraction = use == .caption ? TextOverlayRenderer.captionWidthFraction : TextOverlayRenderer.maxWidthFraction
        guard let drawn = TextOverlayRenderer.drawing(for: text, frameWidth: width, widthFraction: fraction)?.image,
              let cgImage = drawn.cgImage else { return nil }
        let image = UIImage(cgImage: cgImage, scale: 3, orientation: .up)
        if cache.count >= mostKept { cache.removeAll() }
        cache[key] = image
        return image
    }
}
