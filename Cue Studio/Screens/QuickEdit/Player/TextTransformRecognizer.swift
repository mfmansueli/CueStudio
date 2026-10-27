//
//  TextTransformRecognizer.swift
//  Cue Studio
//

import UIKit

/// One gesture for a text on the preview, the way layers are handled in photo editors: one finger moves it; two move,
/// resize and turn it at once; a finger put down or lifted midway carries on from where the text is, so it never jumps.
/// It starts once the fingers move (a tap fails it, so the text's own tap still works) and only where `shouldStart` says the
/// fingers came down on a text. It never stops another gesture.
final class TextTransformRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    /// Moved since the gesture began, in window points (the fingers' middle).
    private(set) var translation: CGSize = .zero
    /// Times as far apart as the two fingers were.
    private(set) var scale: CGFloat = 1
    /// Turned since the gesture began, in radians, clockwise on the screen.
    private(set) var rotation: CGFloat = 0
    /// The fingers moving the text now (two at most: a third is left out).
    var fingers: Int { tracked.count }

    /// Asked once, at the first move, with how many fingers there are: is this gesture a text's (the caller reads where
    /// the fingers are)? No, and it fails.
    var shouldStart: (_ fingers: Int) -> Bool = { _ in true }

    /// Movement under this many points is still a tap.
    private static let slop: CGFloat = 4
    /// Two fingers closer than this measure their spread from here, so a pinch that starts tight doesn't leap.
    private static let shortestSpread: CGFloat = 8
    /// The angle between two fingers closer than this jitters: they turn the text once they're this far apart.
    private static let steadySpread: CGFloat = 28

    private var tracked: [UITouch] = []
    /// The fingers' middle, spread and angle when their number last changed: the gesture goes on from there.
    private var anchor: (middle: CGPoint, spread: CGFloat, angle: CGFloat)?
    /// The fingers' angle the turn is measured from: nil while they're too close to tell.
    private var angleAnchor: CGFloat?
    /// What the gesture had done when their number last changed (or, for the turn, when their angle became steady).
    private var settled: (translation: CGSize, scale: CGFloat, rotation: CGFloat) = (.zero, 1, 0)
    /// How far the fingers' spread has changed, to tell a pinch from a tap.
    private var spreadChange: CGFloat = 0

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        delegate = self
        cancelsTouchesInView = false
        delaysTouchesEnded = false
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches {
            guard tracked.count < 2 else {
                ignore(touch, for: event)
                continue
            }
            tracked.append(touch)
        }
        rebase()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        follow()
        switch state {
        case .possible:
            guard hasMoved else { return }
            state = shouldStart(tracked.count) ? .began : .failed
        case .began, .changed:
            state = .changed
        default:
            break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        lift(touches, cancelled: false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        lift(touches, cancelled: true)
    }

    override func reset() {
        super.reset()
        tracked = []
        anchor = nil
        angleAnchor = nil
        settled = (.zero, 1, 0)
        spreadChange = 0
        translation = .zero
        scale = 1
        rotation = 0
    }

    // MARK: - Delegate

    /// Never in another gesture's way, nor another in this one's.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }

    // MARK: - Private

    private var hasMoved: Bool {
        hypot(translation.width, translation.height) > Self.slop || spreadChange > Self.slop || abs(rotation) > 0.06
    }

    /// The fingers' middle, how far apart the first two are and at what angle.
    private func pose() -> (middle: CGPoint, spread: CGFloat, angle: CGFloat)? {
        guard let first = tracked.first?.location(in: nil) else { return nil }
        guard tracked.count > 1, let second = tracked.last?.location(in: nil) else { return (first, 0, 0) }
        let middle = CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
        let spread = max(Self.shortestSpread, hypot(second.x - first.x, second.y - first.y))
        return (middle, spread, atan2(second.y - first.y, second.x - first.x))
    }

    /// The fingers changed: what the gesture has done stays, and it goes on from where they are now.
    private func rebase() {
        settled = (translation, scale, rotation)
        anchor = pose()
        angleAnchor = anchor.flatMap { tracked.count > 1 && $0.spread >= Self.steadySpread ? $0.angle : nil }
    }

    private func follow() {
        guard let anchor, let now = pose() else { return }
        translation = CGSize(
            width: settled.translation.width + now.middle.x - anchor.middle.x,
            height: settled.translation.height + now.middle.y - anchor.middle.y
        )
        guard tracked.count > 1, anchor.spread > 0 else { return }
        spreadChange = max(spreadChange, abs(now.spread - anchor.spread))
        scale = settled.scale * now.spread / anchor.spread
        if angleAnchor == nil, now.spread >= Self.steadySpread {
            // Far enough apart to tell their angle: the turn starts from here.
            angleAnchor = now.angle
            settled.rotation = rotation
        }
        // The shortest way round, so crossing the left of the circle doesn't spin it a whole turn.
        if let angleAnchor { rotation = settled.rotation + remainder(now.angle - angleAnchor, 2 * .pi) }
    }

    private func lift(_ touches: Set<UITouch>, cancelled: Bool) {
        tracked.removeAll { touches.contains($0) }
        guard tracked.isEmpty else {
            rebase()
            if state == .began || state == .changed { state = .changed }
            return
        }
        switch state {
        case .began, .changed: state = cancelled ? .cancelled : .ended
        default: state = .failed
        }
    }
}
