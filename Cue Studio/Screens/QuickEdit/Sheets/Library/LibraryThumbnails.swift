//
//  LibraryThumbnails.swift
//  Cue Studio
//

import AVFoundation
import ImageIO
import UIKit

/// Small pictures of library files for their cards: a picture read straight at the size it shows (`CGImageSource`), a video's
/// frame a second in; kept while the app runs.
nonisolated enum LibraryThumbnails {
    /// NSCache is safe to use from any thread.
    nonisolated(unsafe) private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 200
        return cache
    }()

    static func image(for url: URL, isVideo: Bool, side: CGFloat) async -> UIImage? {
        let key = "\(url.lastPathComponent)-\(Int(side))" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let image: UIImage?
        if isVideo {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: side, height: side)
            image = (try? await generator.image(at: CMTime(seconds: 1, preferredTimescale: 600)).image).map(UIImage.init(cgImage:))
        } else {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: side,
            ]
            image = CGImageSourceCreateWithURL(url as CFURL, nil)
                .flatMap { CGImageSourceCreateThumbnailAtIndex($0, 0, options as CFDictionary) }
                .map(UIImage.init(cgImage:))
        }
        if let image { cache.setObject(image, forKey: key) }
        return image
    }
}
