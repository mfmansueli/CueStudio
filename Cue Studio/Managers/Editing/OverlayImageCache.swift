//
//  OverlayImageCache.swift
//  Cue Studio
//

import CoreImage
import UIKit
import Foundation

/// Captions drawn by the compositor as they show, the last few kept: playback asks for the same
/// line on every frame it shows, and memory stays small however long the video is.
nonisolated final class OverlayImageCache: @unchecked Sendable {
    private let cache: NSCache<NSString, CIImage> = {
        let cache = NSCache<NSString, CIImage>()
        cache.countLimit = 48
        return cache
    }()

    func image(for lazy: LazyText) -> CIImage? {
        let key = lazy.key as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let drawn: UIImage?
        if let settings = lazy.collection {
            drawn = CaptionCollectionRenderer.image(lazy.text.text, settings: settings,
                                                     frame: CGSize(width: lazy.frameWidth, height: lazy.frameHeight), emphasis: lazy.emphasis)
        } else {
            drawn = TextOverlayRenderer.image(
                for: lazy.text, frameWidth: lazy.frameWidth, widthFraction: lazy.widthFraction, emphasis: lazy.emphasis
            )
        }
        guard let drawn, let image = CIImage(image: drawn) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}
