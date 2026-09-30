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
        guard let drawn = TextOverlayRenderer.image(
            for: lazy.text, frameWidth: lazy.frameWidth, widthFraction: lazy.widthFraction, emphasis: lazy.emphasis
        ), let image = CIImage(image: drawn) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}
