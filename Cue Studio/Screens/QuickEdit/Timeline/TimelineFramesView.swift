//
//  TimelineFramesView.swift
//  Cue Studio
//

import SwiftUI

/// The recording's frames under the timeline. Each piece shows its own part of the take, and the
/// dimmed ends show what the handles can bring back. Drawn in one Canvas that doesn't depend on
/// the playhead, so it stays still while the video plays.
struct TimelineFramesView: View {
    let videoURL: URL
    let layout: TimelineLayout
    /// Frames read, evenly across the recording.
    let frameCount: Int

    @Environment(VideoThumbnailService.self) private var thumbnails
    @State private var frames: [UIImage?] = []

    var body: some View {
        Canvas { context, size in
            let placeholder = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [Palette.thumbnailTop, Palette.thumbnailBottom]),
                startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)
            )
            let tileWidth = size.height * frameAspect
            for region in layout.regions where region.width > 0.5 {
                let rect = CGRect(x: region.minX, y: 0, width: region.width, height: size.height)
                var regionContext = context
                regionContext.clip(to: Path(rect))
                var x = rect.minX
                while x < rect.maxX {
                    let tile = CGRect(x: x, y: 0, width: tileWidth, height: size.height)
                    if let image = frame(at: layout.sourceTime(atX: min(tile.midX, rect.maxX - 0.5))) {
                        draw(image, filling: tile, in: regionContext)
                    } else {
                        regionContext.fill(Path(tile), with: placeholder)
                    }
                    x += max(1, tileWidth)
                }
                if region.kind == .head || region.kind == .tail {
                    regionContext.fill(Path(rect), with: .color(Palette.trimDim))
                }
            }
        }
        .task(id: FramesKey(url: videoURL, count: frameCount, duration: layout.timeline.sourceDuration)) {
            await loadFrames()
        }
        .accessibilityHidden(true)
    }

    /// Width over height of the frames; portrait until the first one arrives.
    private var frameAspect: CGFloat {
        guard let size = frames.lazy.compactMap({ $0?.size }).first, size.height > 0 else { return 9.0 / 16.0 }
        return size.width / size.height
    }

    private func frame(at time: TimeInterval) -> UIImage? {
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

    private func loadFrames() async {
        let duration = layout.timeline.sourceDuration
        guard frameCount > 0, duration > 0 else { return }
        let step = duration / Double(frameCount)
        let times = (0..<frameCount).map { (Double($0) + 0.5) * step }
        frames = await thumbnails.frames(for: videoURL, at: times, tolerance: step / 2)
    }

    private struct FramesKey: Hashable {
        let url: URL
        let count: Int
        let duration: TimeInterval
    }
}
