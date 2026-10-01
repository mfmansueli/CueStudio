//
//  TimelineFrameCache.swift
//  Cue Studio
//

import AVFoundation
import UIKit

/// The frames under the clips, read in the background (`AVAssetImageGenerator`) and kept by their
/// time in the recording, so scrolling and zooming find them again. Times are rounded to a grid
/// that follows the zoom: a tile far zoomed out stands for seconds, zoomed in for a tenth. While a
/// frame is on its way, the nearest one already read stands in. Only the latest few hundred stay.
@MainActor
final class TimelineFrameCache {
    /// Called when frames arrive (at most a few times a second).
    var onChange: (() -> Void)?

    private struct Key: Hashable {
        let url: URL
        /// Milliseconds into the recording.
        let millis: Int
    }

    private var images: [Key: UIImage] = [:]
    /// Least recently used first.
    private var order: [Key] = []
    private var queued: [(key: Key, tolerance: TimeInterval)] = []
    private var waiting: Set<Key> = []
    private var generators: [URL: AVAssetImageGenerator] = [:]
    private var worker: Task<Void, Never>?
    private var notifyTask: Task<Void, Never>?

    static let limit = 500
    /// Grid steps, in seconds of the recording.
    static let grids: [TimeInterval] = [0.1, 0.25, 0.5, 1, 2, 4, 8]
    /// Frames this tall (pixels): sharp at the tallest track on a 3× screen.
    static let pixelHeight: CGFloat = 170

    /// The grid for tiles that each stand for `seconds` of the recording.
    static func grid(forTile seconds: TimeInterval) -> TimeInterval {
        grids.last { $0 <= seconds } ?? grids[0]
    }

    /// The frame at `time` of `url` on `grid`, or the nearest already read; nil when none of that
    /// recording is in yet. Asks for the missing one.
    func image(for url: URL, at time: TimeInterval, grid: TimeInterval) -> UIImage? {
        let key = Self.key(url, time, grid)
        if let image = images[key] {
            touch(key)
            return image
        }
        request(key, tolerance: grid / 2)
        return nearest(to: key)
    }

    func cancel() {
        worker?.cancel()
        notifyTask?.cancel()
        queued = []
        waiting = []
    }

    // MARK: - Private

    private static func key(_ url: URL, _ time: TimeInterval, _ grid: TimeInterval) -> Key {
        let snapped = (max(0, time) / grid).rounded(.down) * grid + grid / 2
        return Key(url: url, millis: Int((snapped * 1000).rounded()))
    }

    private func nearest(to key: Key) -> UIImage? {
        var best: (distance: Int, image: UIImage)?
        for (candidate, image) in images where candidate.url == key.url {
            let distance = abs(candidate.millis - key.millis)
            if best.map({ distance < $0.distance }) ?? true { best = (distance, image) }
        }
        return best?.image
    }

    private func touch(_ key: Key) {
        if let index = order.lastIndex(of: key), index < order.count - 1 {
            order.remove(at: index)
            order.append(key)
        }
    }

    private func request(_ key: Key, tolerance: TimeInterval) {
        guard !waiting.contains(key) else { return }
        waiting.insert(key)
        queued.append((key, tolerance))
        guard worker == nil else { return }
        worker = Task { [weak self] in
            await self?.work()
        }
    }

    /// Reads what is queued, newest first (what's on screen now), a batch per recording at a time.
    private func work() async {
        while !Task.isCancelled, let url = queued.last?.key.url {
            let batch = Array(queued.filter { $0.key.url == url }.suffix(24))
            let keys = Set(batch.map(\.key))
            queued.removeAll { keys.contains($0.key) }
            let generator = generator(for: url)
            let tolerance = CMTime(seconds: batch.map(\.tolerance).min() ?? 0.05, preferredTimescale: 600)
            generator.requestedTimeToleranceBefore = tolerance
            generator.requestedTimeToleranceAfter = tolerance
            let times = batch.map { CMTime(value: CMTimeValue($0.key.millis), timescale: 1000) }
            for await result in generator.images(for: times) {
                guard !Task.isCancelled else { break }
                let millis = Int((result.requestedTime.seconds * 1000).rounded())
                let key = Key(url: url, millis: millis)
                waiting.remove(key)
                if let image = try? result.image { store(UIImage(cgImage: image), for: key) }
            }
            for key in keys { waiting.remove(key) }
        }
        worker = nil
    }

    private func store(_ image: UIImage, for key: Key) {
        images[key] = image
        order.append(key)
        while order.count > Self.limit {
            images[order.removeFirst()] = nil
        }
        scheduleNotify()
    }

    private func scheduleNotify() {
        guard notifyTask == nil else { return }
        notifyTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            self?.notifyTask = nil
            self?.onChange?()
        }
    }

    private func generator(for url: URL) -> AVAssetImageGenerator {
        if let generator = generators[url] { return generator }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: Self.pixelHeight, height: Self.pixelHeight)
        generators[url] = generator
        return generator
    }
}
