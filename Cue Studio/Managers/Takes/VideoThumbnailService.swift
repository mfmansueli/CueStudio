//
//  VideoThumbnailService.swift
//  Cue Studio
//

import AVFoundation
import UIKit

/// Poster frames and filmstrips for takes, cached in memory.
@MainActor
@Observable
final class VideoThumbnailService {
    private let cache = NSCache<NSURL, UIImage>()

    func thumbnail(for url: URL, maxPixelSize: CGFloat = 480) async -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        guard let image = await frame(of: url, at: 0.3, maxPixelSize: maxPixelSize) else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }

    /// Evenly spaced frames across the video.
    func filmstrip(for url: URL, count: Int, duration: TimeInterval, maxPixelSize: CGFloat = 160) async -> [UIImage] {
        guard count > 0, duration > 0 else { return [] }
        var frames: [UIImage] = []
        for index in 0..<count {
            let time = duration * (Double(index) + 0.5) / Double(count)
            if let image = await frame(of: url, at: time, maxPixelSize: maxPixelSize) { frames.append(image) }
        }
        return frames
    }

    private func frame(of url: URL, at seconds: TimeInterval, maxPixelSize: CGFloat) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixelSize, height: maxPixelSize)
        guard let result = try? await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)) else { return nil }
        return UIImage(cgImage: result.image)
    }
}
