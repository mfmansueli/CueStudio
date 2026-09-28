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
    /// The Quick edit timeline's frames, so switching tools doesn't read them again.
    private var timelineFrames: [String: [UIImage?]] = [:]

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

    /// Frames at `times` from one generator, nil where a frame can't be read. Each lands within
    /// `tolerance` of its time rather than exactly on it, so long takes stay quick.
    func frames(for url: URL, at times: [TimeInterval], tolerance: TimeInterval, maxPixelSize: CGFloat = 160) async -> [UIImage?] {
        let key = "\(url.absoluteString)|\(times.count)|\(times.last ?? 0)"
        if let cached = timelineFrames[key] { return cached }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixelSize, height: maxPixelSize)
        let slack = CMTime(seconds: max(0, tolerance), preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = slack
        generator.requestedTimeToleranceAfter = slack
        let requested = times.map { CMTime(seconds: $0, preferredTimescale: 600) }
        var frames = [UIImage?](repeating: nil, count: times.count)
        for await result in generator.images(for: requested) {
            guard let index = requested.firstIndex(of: result.requestedTime), let image = try? result.image else { continue }
            frames[index] = UIImage(cgImage: image)
        }
        if frames.contains(where: { $0 != nil }) {
            // Only the latest timeline's frames are kept: they're the ones on screen.
            timelineFrames = [key: frames]
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
