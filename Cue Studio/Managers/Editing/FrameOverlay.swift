//
//  FrameOverlay.swift
//  Cue Studio
//

import CoreGraphics
import CoreImage

/// Something drawn over the video's frame for a while: a text, a caption line (or one state of
/// it, the word being said). Texts are drawn ahead; captions are drawn when they show
/// (`lazyText`). Keyframes move, scale and fade it over its own time; captions can fade at their
/// edges.
nonisolated struct FrameOverlay: @unchecked Sendable {
    /// Drawn ahead; nil for a caption drawn when it shows.
    let image: CIImage?
    /// Where it goes, in the output frame (Core Image coordinates: origin at the bottom left).
    let origin: CGPoint
    /// Seconds in the edited video; nil for always.
    let span: TimeSpan?
    /// Its drawing's size.
    let size: CGSize
    /// A caption drawn when it shows.
    var lazyText: LazyText?
    /// Seconds it fades in and out at its edges.
    var fade: TimeInterval = 0
    /// Keyframed motion over its own time, on a frame of `frameSize`.
    var motion: OverlayMotion?
    var frameSize: CGSize = .zero

    init(image: CIImage, origin: CGPoint, span: TimeSpan?) {
        self.image = image
        self.origin = origin
        self.span = span
        size = image.extent.size
    }

    init(lazyText: LazyText, size: CGSize, origin: CGPoint, span: TimeSpan?) {
        image = nil
        self.lazyText = lazyText
        self.size = size
        self.origin = origin
        self.span = span
    }

    func isVisible(at time: TimeInterval) -> Bool {
        span?.contains(time) ?? true
    }

    /// Its drawing placed on the frame at `time`: where its keyframes put it, as big and as opaque
    /// as they say, faded at its edges.
    func placed(at time: TimeInterval, cache: OverlayImageCache) -> CIImage? {
        guard let picture = image ?? lazyText.flatMap(cache.image(for:)) else { return nil }
        var transform = CGAffineTransform(translationX: origin.x, y: origin.y)
        var alpha: CGFloat = 1
        if let motion, let span, let state = motion.state(at: time - span.start) {
            let point = state.center.clamped
            let center = CGPoint(x: CGFloat(point.x) * frameSize.width, y: (1 - CGFloat(point.y)) * frameSize.height)
            let scale = CGFloat(state.scale)
            transform = CGAffineTransform(translationX: -size.width / 2, y: -size.height / 2)
                .concatenating(CGAffineTransform(scaleX: scale, y: scale))
                .concatenating(CGAffineTransform(translationX: center.x, y: center.y))
            alpha = CGFloat(state.opacity)
        }
        if fade > 0, let span {
            let edge = min((time - span.start) / fade, (span.end - time) / fade)
            alpha *= CGFloat(min(1, max(0, edge)))
        }
        var placed = picture.transformed(by: transform)
        if alpha < 0.999 {
            placed = placed.applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: alpha)])
        }
        return placed
    }
}
