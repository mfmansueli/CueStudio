//
//  TimelineMotion.swift
//  Cue Studio
//

import QuartzCore
import UIKit

/// The timeline's short motions on its layers (`TimelineChange` says when), each 0.35 s or less and never in the way of a
/// finger. With Reduce Motion nothing grows, sinks, rises or slides: what comes in fades in and what goes fades out.
@MainActor
enum TimelineMotion {
    private static var reducesMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    private static func spring(_ keyPath: String, from: Any, to: Any, bounce: CGFloat = 0.3) -> CASpringAnimation {
        let spring = CASpringAnimation(perceptualDuration: 0.35, bounce: bounce)
        spring.keyPath = keyPath
        spring.fromValue = from
        spring.toValue = to
        spring.duration = spring.settlingDuration
        return spring
    }

    private static func fade(from: Float, to: Float, duration: CFTimeInterval) -> CABasicAnimation {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = from
        fade.toValue = to
        fade.duration = duration
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        return fade
    }

    /// Just picked: from 96% back to its size with a short spring (its ring and handles come with it).
    static func pick(_ layer: CALayer) {
        guard !reducesMotion else {
            layer.add(fade(from: 0.6, to: 1, duration: 0.18), forKey: "pick")
            return
        }
        layer.add(spring("transform.scale", from: 0.96, to: 1, bounce: 0.4), forKey: "pick")
    }

    /// A picked item's handle: it springs out from the item as it fades in.
    static func showHandle(_ layer: CALayer) {
        layer.add(fade(from: 0, to: 1, duration: 0.18), forKey: "show")
        guard !reducesMotion else { return }
        layer.add(spring("transform.scale", from: 0.7, to: 1, bounce: 0.4), forKey: "pop")
    }

    /// Came in: it grows across from its start (the playhead, for an add) to its length, uncovered rather than stretched.
    static func grow(_ layer: CALayer) {
        guard !reducesMotion else {
            layer.add(fade(from: 0, to: 1, duration: 0.25), forKey: "grow")
            return
        }
        let mask = CALayer()
        mask.backgroundColor = UIColor.black.cgColor
        mask.anchorPoint = CGPoint(x: 0, y: 0.5)
        mask.bounds = CGRect(origin: .zero, size: layer.bounds.size)
        mask.position = CGPoint(x: 0, y: layer.bounds.midY)
        layer.mask = mask
        let reveal = CABasicAnimation(keyPath: "bounds.size.width")
        reveal.fromValue = min(8, layer.bounds.width)
        reveal.toValue = layer.bounds.width
        reveal.duration = 0.3
        reveal.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.2, 1)
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak layer, weak mask] in
            if let layer, layer.mask === mask { layer.mask = nil }
        }
        mask.add(reveal, forKey: "grow")
        CATransaction.commit()
        layer.add(spring("transform.scale.y", from: 0.85, to: 1), forKey: "rise")
    }

    /// Went away: it shrinks a little and fades out, then leaves its parent.
    static func leave(_ layer: CALayer) {
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak layer] in layer?.removeFromSuperlayer() }
        let out = fade(from: 1, to: 0, duration: 0.2)
        out.fillMode = .forwards
        out.isRemovedOnCompletion = false
        layer.add(out, forKey: "leave")
        if !reducesMotion {
            let shrink = CABasicAnimation(keyPath: "transform.scale")
            shrink.fromValue = 1
            shrink.toValue = 0.86
            shrink.duration = 0.2
            shrink.fillMode = .forwards
            shrink.isRemovedOnCompletion = false
            shrink.timingFunction = CAMediaTimingFunction(name: .easeIn)
            layer.add(shrink, forKey: "shrink")
        }
        CATransaction.commit()
    }

    /// Moved across because something before it went: it slides the rest of the way from where it was.
    static func shift(_ layer: CALayer, by distance: CGFloat) {
        guard !reducesMotion else { return }
        let slide = CABasicAnimation(keyPath: "transform.translation.x")
        slide.fromValue = distance
        slide.toValue = 0
        slide.duration = 0.28
        slide.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.2, 1)
        layer.add(slide, forKey: "shift")
    }

    /// A track brought under the video: it rises 4 pt into place with a spring.
    static func rise(_ layer: CALayer) {
        guard !reducesMotion else { return }
        layer.add(spring("transform.translation.y", from: 4, to: 0), forKey: "arrive")
    }

    /// A short flash over `frame` in `color` that fades out and goes (a track an item came in on).
    static func flash(in parent: CALayer, frame: CGRect, radius: CGFloat, color: UIColor) {
        let glow = CALayer()
        glow.frame = frame
        glow.cornerRadius = radius
        glow.cornerCurve = .continuous
        glow.backgroundColor = color.cgColor
        glow.opacity = 0
        parent.addSublayer(glow)
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak glow] in glow?.removeFromSuperlayer() }
        glow.add(fade(from: 1, to: 0, duration: 0.6), forKey: "flash")
        CATransaction.commit()
    }

    /// The line where the playhead or a handle just stuck (a cut, an item's edge, a beat): yellow, gone in a blink.
    static func snapLine(in parent: CALayer, x: CGFloat, top: CGFloat, height: CGFloat, color: UIColor) {
        let line = CALayer()
        line.frame = CGRect(x: x - 1, y: top, width: 2, height: max(0, height))
        line.cornerRadius = 1
        line.backgroundColor = color.cgColor
        line.opacity = 0
        parent.addSublayer(line)
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak line] in line?.removeFromSuperlayer() }
        line.add(fade(from: 1, to: 0, duration: 0.35), forKey: "snap")
        CATransaction.commit()
    }
}
