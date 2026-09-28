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
    /// Timeline and filmstrip frames, so switching tools or screens doesn't read them again. Only
    /// the latest few sets are kept: they're the ones on screen.
    @ObservationIgnored private var timelineFrames: [FramesKey: [UIImage?]] = [:]
    @ObservationIgnored private var timelineOrder: [FramesKey] = []
    private static let timelineFramesLimit = 4

    func thumbnail(for url: URL, maxPixelSize: CGFloat = 480) async -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        guard let image = await frame(of: url, at: 0.3, maxPixelSize: maxPixelSize) else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }

    /// Frames at `times` from one generator, nil where a frame can't be read. Each lands within
    /// `tolerance` of its time rather than exactly on it, so long takes stay quick.
    func frames(for url: URL, at times: [TimeInterval], tolerance: TimeInterval, maxPixelSize: CGFloat = 160) async -> [UIImage?] {
        let key = FramesKey(url: url, times: times, maxPixelSize: maxPixelSize)
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
        if frames.contains(where: { $0 != nil }) { remember(frames, for: key) }
        return frames
    }

    private func remember(_ frames: [UIImage?], for key: FramesKey) {
        timelineFrames[key] = frames
        timelineOrder.removeAll { $0 == key }
        timelineOrder.append(key)
        while timelineOrder.count > Self.timelineFramesLimit {
            timelineFrames[timelineOrder.removeFirst()] = nil
        }
    }

    private func frame(of url: URL, at seconds: TimeInterval, maxPixelSize: CGFloat) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixelSize, height: maxPixelSize)
        guard let result = try? await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)) else { return nil }
        return UIImage(cgImage: result.image)
    }

    private struct FramesKey: Hashable {
        let url: URL
        let times: [TimeInterval]
        let maxPixelSize: CGFloat
    }
}
