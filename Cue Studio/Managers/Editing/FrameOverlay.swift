//
//  FrameOverlay.swift
//  Cue Studio
//

import CoreGraphics
import CoreImage

/// Something drawn over the video's frame for a while: a text, a caption line (or one state of
/// it, the word being said). Texts are drawn ahead; captions are drawn when they show
/// (`lazyText`); a text's effect is drawn at each moment (`effect`). Keyframes move, scale, turn and fade it over its own
/// time; captions can fade at their edges.
nonisolated struct FrameOverlay: @unchecked Sendable {
    /// Drawn ahead; nil for a caption drawn when it shows, or an effect drawn at each moment.
    let image: CIImage?
    /// Where its box goes, in the output frame (Core Image coordinates: origin at the bottom left).
    let origin: CGPoint
    /// Seconds in the edited video; nil for always.
    let span: TimeSpan?
    /// Its box's size: what it is placed, scaled and turned by.
    let size: CGSize
    /// How far its drawing reaches past its box on every side (a box's shadow, an effect's halo or depth).
    var bleed: CGFloat = 0
    /// Its drawing is this many times bigger than it shows (drawn for keyframes that enlarge it, so it stays sharp).
    var drawnScale: CGFloat = 1
    /// Turned around its box's center, in radians, clockwise on the screen; keyframes turn it instead when they move it.
    var rotation: Double = 0
    /// A caption drawn when it shows.
    var lazyText: LazyText?
    /// A text's effect, drawn at each moment it shows.
    var effect: TextEffectPlayback?
    /// Seconds it fades in and out at its edges.
    var fade: TimeInterval = 0
    /// A line coming in or going out (the first and the last state of a caption line): it fades in
    /// over `fadeIn`, out over `fadeOut`, and grows to size from `popScale` over `popDuration`.
    var fadeIn: TimeInterval = 0
    var fadeOut: TimeInterval = 0
    var popScale = 1.0
    var popDuration: TimeInterval = 0
    /// A line rising as it comes in: it starts `riseDistance` lower and reaches its place over `riseDuration`, easing out.
    var riseDistance: CGFloat = 0
    var riseDuration: TimeInterval = 0
    /// When the line this state belongs to comes in and goes out, so its way in and out runs across its states (a word lit in
    /// the first 45 ms of a line doesn't cut its fade short); nil: this state's own edges.
    var entryStart: TimeInterval?
    var exitEnd: TimeInterval?
    /// Keyframed motion over its own time, on a frame of `frameSize`.
    var motion: OverlayMotion?
    var frameSize: CGSize = .zero
    /// The text this draws (`TextOverlay.id`); nil for a caption.
    var textID: UUID?
    /// Drawn for the editor's preview, where the picked text shows whole while paused (`PreviewMotionHold`).
    var readsPreviewHold = false

    init(image: CIImage, origin: CGPoint, span: TimeSpan?) {
        self.image = image
        self.origin = origin
        self.span = span
        size = image.extent.size
    }

    /// A drawing of a box `box` big that reaches `bleed` past it on every side.
    init(image: CIImage, box: CGSize, bleed: CGFloat, origin: CGPoint, span: TimeSpan?) {
        self.image = image
        self.origin = origin
        self.span = span
        size = box
        self.bleed = bleed
    }

    /// A text's effect, its box `box` big, its drawing reaching `bleed` past it.
    init(effect: TextEffectPlayback, box: CGSize, bleed: CGFloat, origin: CGPoint, span: TimeSpan?) {
        image = nil
        self.effect = effect
        self.origin = origin
        self.span = span
        size = box
        self.bleed = bleed
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

    /// Its drawing placed on the frame at `time`: where its keyframes put it, as big, as turned and
    /// as opaque as they say, faded at its edges.
    func placed(at shown: TimeInterval, cache: OverlayImageCache) -> CIImage? {
        // The editor's preview, paused on the picked text: drawn as it is once in (`PreviewMotionHold`).
        let time = readsPreviewHold ? span.map { $0.start + PreviewMotionHold.shared.local(shown - $0.start, of: textID) } ?? shown : shown
        let local = span.map { time - $0.start } ?? time
        guard let picture = effect?.image(at: local) ?? image ?? lazyText.flatMap(cache.image(for:)) else { return nil }
        var center = CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
        var scale: CGFloat = 1
        var turn = CGFloat(rotation)
        var alpha: CGFloat = 1
        var moved = false
        var rise: CGFloat = 0
        if let motion, span != nil, let state = motion.state(at: local) {
            let point = state.center.clamped
            center = CGPoint(x: CGFloat(point.x) * frameSize.width, y: (1 - CGFloat(point.y)) * frameSize.height)
            scale = CGFloat(state.scale)
            turn = CGFloat(state.rotation)
            alpha = CGFloat(state.opacity)
            moved = true
        }
        if fade > 0, let span {
            let edge = min((time - span.start) / fade, (span.end - time) / fade)
            alpha *= CGFloat(min(1, max(0, edge)))
        }
        if let span {
            let comesIn = entryStart ?? span.start
            let goesOut = exitEnd ?? span.end
            if fadeIn > 0 { alpha *= CGFloat(min(1, max(0, (time - comesIn) / fadeIn))) }
            if fadeOut > 0 { alpha *= CGFloat(min(1, max(0, (goesOut - time) / fadeOut))) }
            if riseDuration > 0, riseDistance != 0, motion == nil {
                let progress = min(1, max(0, (time - comesIn) / riseDuration))
                let eased = 1 - pow(1 - progress, 3)
                // Core Image's y grows upward: lower is a smaller y.
                rise = riseDistance * CGFloat(1 - eased)
                center.y -= rise
            }
            if popDuration > 0, popScale != 1, motion == nil {
                scale = CGFloat(PopEase.scale(from: popScale, elapsed: time - comesIn, duration: popDuration))
            }
        }
        let transform: CGAffineTransform
        if !moved, scale == 1, turn == 0, drawnScale == 1 {
            // Still and upright: on whole pixels, as it was drawn.
            transform = CGAffineTransform(translationX: origin.x - bleed, y: origin.y - bleed - rise)
        } else {
            let half = CGPoint(x: (size.width / 2 + bleed) * drawnScale, y: (size.height / 2 + bleed) * drawnScale)
            // Core Image turns counterclockwise: clockwise on the screen is the other way.
            transform = CGAffineTransform(translationX: -half.x, y: -half.y)
                .concatenating(CGAffineTransform(scaleX: scale / drawnScale, y: scale / drawnScale))
                .concatenating(CGAffineTransform(rotationAngle: -turn))
                .concatenating(CGAffineTransform(translationX: center.x, y: center.y))
        }
        var placed = picture.transformed(by: transform)
        if alpha < 0.999 {
            placed = placed.applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: alpha)])
        }
        return placed
    }
}
