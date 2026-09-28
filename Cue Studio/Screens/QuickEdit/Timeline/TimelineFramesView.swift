//
//  TimelineFramesView.swift
//  Cue Studio
//

import SwiftUI

/// The recording's frames under the timeline: each section shows its own part of the take. Drawn
/// in one Canvas that doesn't depend on the playhead, so it stays still while the video plays.
///
/// Zoomed in, the frames of what shows (and a screen either side) are read again for the tiles'
/// own times, so the strip shows that moment and not a stretched frame from seconds away; and when
/// frames are wide enough (`TimelineZoom.isFramePrecise`) a tick marks where each one starts.
struct TimelineFramesView: View {
    let videoURL: URL
    let layout: TimelineLayout
    /// Frames read, evenly across the recording.
    let frameCount: Int
    /// The take's frame rate: marks each frame when zoomed in far enough. Nil: no marks.
    var frameRate: Double?
    /// Reads the frames of what shows when zoomed in.
    var readsZoomedFrames = false

    @Environment(VideoThumbnailService.self) private var thumbnails
    @State private var frames: [UIImage?] = []
    /// The frames read for the zoomed-in stretch, by time.
    @State private var zoomedFrames = ZoomedFrames(times: [], images: [], reach: 0)
    @State private var tileHeight: CGFloat = 0

    var body: some View {
        Canvas { context, size in
            let placeholder = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [Palette.thumbnailTop, Palette.thumbnailBottom]),
                startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)
            )
            let tileWidth = size.height * frameAspect
            let step = max(1, tileWidth)
            for region in layout.regions where region.width > 0.5 {
                let rect = CGRect(x: region.minX, y: 0, width: region.width, height: size.height)
                // Only the tiles on screen: zoomed in, a section can be thousands of points wide.
                let visibleMin = max(rect.minX, 0)
                let visibleMax = min(rect.maxX, size.width)
                guard visibleMax > visibleMin else { continue }
                var regionContext = context
                regionContext.clip(to: Path(rect))
                var x = rect.minX + ((visibleMin - rect.minX) / step).rounded(.down) * step
                while x < visibleMax {
                    let tile = CGRect(x: x, y: 0, width: tileWidth, height: size.height)
                    if let image = frame(at: layout.sourceTime(atX: min(tile.midX, rect.maxX - 0.5))) {
                        draw(image, filling: tile, in: regionContext)
                    } else {
                        regionContext.fill(Path(tile), with: placeholder)
                    }
                    x += step
                }
            }
            drawFrameTicks(in: context, size: size)
        }
        .task(id: FramesKey(url: videoURL, count: frameCount, duration: layout.timeline.sourceDuration)) {
            await loadFrames()
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { tileHeight = $0 }
        .task(id: zoomedRequest) {
            await loadZoomedFrames()
        }
        .accessibilityHidden(true)
    }

    /// Width over height of the frames; portrait until the first one arrives.
    private var frameAspect: CGFloat {
        guard let size = frames.lazy.compactMap({ $0?.size }).first, size.height > 0 else { return 9.0 / 16.0 }
        return size.width / size.height
    }

    private func frame(at time: TimeInterval) -> UIImage? {
        zoomedFrames.image(at: time) ?? evenFrame(at: time)
    }

    /// The nearest of the frames read evenly across the recording.
    private func evenFrame(at time: TimeInterval) -> UIImage? {
        let duration = layout.timeline.sourceDuration
        guard !frames.isEmpty, duration > 0 else { return nil }
        let index = min(frames.count - 1, max(0, Int(time / duration * Double(frames.count))))
        return frames[index]
    }

    /// Scales the frame to cover the tile, cropping what spills over.
    private func draw(_ image: UIImage, filling tile: CGRect, in context: GraphicsContext) {
        guard image.size.width > 0, image.size.height > 0 else { return }
        var tileContext = context
        tileContext.clip(to: Path(tile))
        let scale = max(tile.width / image.size.width, tile.height / image.size.height)
        let drawn = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        tileContext.draw(Image(uiImage: image), in: CGRect(
            x: tile.midX - drawn.width / 2, y: tile.midY - drawn.height / 2,
            width: drawn.width, height: drawn.height
        ))
    }

    /// A short tick at the start of each frame on screen, once frames are wide enough to tell apart.
    private func drawFrameTicks(in context: GraphicsContext, size: CGSize) {
        guard let frameRate, layout.pointsPerSecond > 0,
              TimelineZoom.isFramePrecise(pointsPerSecond: layout.pointsPerSecond, frameRate: frameRate) else { return }
        let grid = FrameGrid(rate: frameRate)
        let height: CGFloat = 12
        for region in layout.regions {
            let lo = max(region.minX, 0)
            let hi = min(region.maxX, size.width)
            guard hi > lo else { continue }
            let span = TimeSpan(
                start: region.source.start + Double((lo - region.minX) / layout.pointsPerSecond),
                end: region.source.start + Double((hi - region.minX) / layout.pointsPerSecond)
            )
            for start in grid.frameStarts(in: span) {
                let x = region.minX + CGFloat(start - region.source.start) * layout.pointsPerSecond
                context.fill(Path(CGRect(x: x - 0.5, y: size.height - height, width: 1, height: height)), with: .color(Palette.frameTick))
            }
        }
    }

    private func loadFrames() async {
        let duration = layout.timeline.sourceDuration
        guard frameCount > 0, duration > 0 else { return }
        let step = duration / Double(frameCount)
        let times = (0..<frameCount).map { (Double($0) + 0.5) * step }
        frames = await thumbnails.frames(for: videoURL, at: times, tolerance: step / 2)
    }

    // MARK: - Zoomed in

    /// The tiles' own times on screen and a screen either side, when the frames read evenly are
    /// too far apart for them; nil otherwise. Tiles sit on a grid from each section's start, so a
    /// small scroll asks for the same times again (and the cache answers).
    private var zoomedRequest: ZoomedRequest? {
        guard readsZoomedFrames, tileHeight > 0, layout.pointsPerSecond > 0, frameCount > 0 else { return nil }
        let duration = layout.timeline.sourceDuration
        guard duration > 0 else { return nil }
        let tileWidth = max(1, tileHeight * frameAspect)
        let tileSeconds = Double(tileWidth / layout.pointsPerSecond)
        guard tileSeconds < duration / Double(frameCount) * 0.75 else { return nil }
        var times: [TimeInterval] = []
        for region in layout.regions where region.width > 0.5 {
            let lo = max(region.minX, -layout.width)
            let hi = min(region.maxX, 2 * layout.width)
            guard hi > lo else { continue }
            let first = Int(((lo - region.minX) / tileWidth).rounded(.down))
            let last = Int(((hi - region.minX) / tileWidth).rounded(.up))
            for index in first..<max(first, last) {
                let time = region.source.start + (Double(index) + 0.5) * tileSeconds
                times.append(min(time, region.source.end - 0.001))
            }
        }
        guard !times.isEmpty, times.count <= 120 else { return nil }
        return ZoomedRequest(times: times, tolerance: tileSeconds / 2)
    }

    private func loadZoomedFrames() async {
        guard let request = zoomedRequest else { return }
        // Waits for a scroll or a zoom to settle.
        try? await Task.sleep(for: .milliseconds(120))
        guard !Task.isCancelled else { return }
        let images = await thumbnails.frames(for: videoURL, at: request.times, tolerance: request.tolerance)
        guard !Task.isCancelled else { return }
        zoomedFrames = ZoomedFrames(times: request.times, images: images, reach: request.tolerance * 1.5)
    }

    private struct FramesKey: Hashable {
        let url: URL
        let count: Int
        let duration: TimeInterval
    }

    private struct ZoomedRequest: Hashable {
        let times: [TimeInterval]
        let tolerance: TimeInterval
    }

    /// Frames read at `times` (in order); each stands in for a tile within `reach` of its time.
    private struct ZoomedFrames {
        let times: [TimeInterval]
        let images: [UIImage?]
        let reach: TimeInterval

        func image(at time: TimeInterval) -> UIImage? {
            guard !times.isEmpty, times.count == images.count else { return nil }
            var low = 0
            var high = times.count - 1
            while low < high {
                let middle = (low + high) / 2
                if times[middle] < time { low = middle + 1 } else { high = middle }
            }
            let nearest = [low - 1, low].filter({ times.indices.contains($0) })
                .min(by: { abs(times[$0] - time) < abs(times[$1] - time) }) ?? low
            guard abs(times[nearest] - time) <= reach else { return nil }
            return images[nearest]
        }
    }
}
