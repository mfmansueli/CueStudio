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
    /// A line coming in or going out (the first and the last state of a caption line): it fades in
    /// over `fadeIn`, out over `fadeOut`, and grows to size from `popScale` over `popDuration`.
    var fadeIn: TimeInterval = 0
    var fadeOut: TimeInterval = 0
    var popScale = 1.0
    var popDuration: TimeInterval = 0
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
        if let span {
            if fadeIn > 0 { alpha *= CGFloat(min(1, max(0, (time - span.start) / fadeIn))) }
            if fadeOut > 0 { alpha *= CGFloat(min(1, max(0, (span.end - time) / fadeOut))) }
            if popDuration > 0, popScale != 1, motion == nil {
                let scale = CGFloat(Self.popScale(from: popScale, elapsed: time - span.start, duration: popDuration))
                if scale != 1 {
                    transform = CGAffineTransform(translationX: -size.width / 2, y: -size.height / 2)
                        .concatenating(CGAffineTransform(scaleX: scale, y: scale))
                        .concatenating(CGAffineTransform(translationX: origin.x + size.width / 2, y: origin.y + size.height / 2))
                }
            }
        }
        var placed = picture.transformed(by: transform)
        if alpha < 0.999 {
            placed = placed.applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: alpha)])
        }
        return placed
    }

    /// The size of a line `elapsed` seconds after it came in, as a share of its full size: it starts
    /// at `start` and grows to full over `duration`, going a little past it on the way (ease-out
    /// with a small overshoot), so a caption lands rather than appears. 1 before and after.
    static func popScale(from start: Double, elapsed: TimeInterval, duration: TimeInterval) -> Double {
        guard duration > 0, elapsed < duration else { return 1 }
        let progress = min(max(elapsed / duration, 0), 1)
        // Ease-out-back: overshoots the end by about 10% of the way, then settles.
        let c1 = 1.2
        let c3 = c1 + 1
        let eased = 1 + c3 * pow(progress - 1, 3) + c1 * pow(progress - 1, 2)
        return start + (1 - start) * eased
    }
}
