//
//  MotionClip.swift
//  Cue Studio
//

import SwiftUI

/// The motion of one board (`1.3_voyage`, `9.2_live-2026`…): its animated layers (`L12`) and the keyframes they play, read from the baked
/// `screens-motion.json` (`tools/bake_motion.py`, from the design's `motion/screens-motion.json`). A scene asks for the pose of a layer
/// at a second of its timeline and draws the thing there; it never writes the numbers itself.
nonisolated struct MotionClip: Sendable {
    let name: String
    private let layers: [String: [MotionAnimation]]
    private let frames: [String: [MotionFrame]]

    init(name: String, layers: [String: [MotionAnimation]], frames: [String: [MotionFrame]]) {
        self.name = name
        self.layers = layers
        self.frames = frames
    }

    /// Whether the board animates this layer.
    func has(_ layer: String) -> Bool { layers[layer] != nil }

    /// The pose of `layer` at `time` seconds of the board's timeline.
    /// - Parameters:
    ///   - time: the scene's clock. A board that loops plays once in the app, so the caller clamps this at the second the scene is complete.
    ///   - loops: an ambient loop (a halo breathing): the animation repeats instead of holding its last keyframe.
    func pose(of layer: String, at time: Double, loops: Bool = false) -> MotionPose {
        var pose = MotionPose()
        for animation in layers[layer] ?? [] {
            guard let keyframes = frames[animation.kf], animation.duration > 0 else { continue }
            var local = max(0, time - animation.delay)
            if loops, animation.loops { local = local.truncatingRemainder(dividingBy: animation.duration) }
            local = min(local, animation.duration)
            apply(keyframes, animation: animation, at: local, to: &pose)
        }
        return pose
    }

    // MARK: - Sampling

    private func apply(_ keyframes: [MotionFrame], animation: MotionAnimation, at time: Double, to pose: inout MotionPose) {
        let sampler = Sampler(keyframes: keyframes, easing: animation.easing, time: time)
        applyPlacement(sampler, to: &pose)
        applyDrawing(sampler, to: &pose)
        applyColours(sampler, to: &pose)
    }

    /// Where it is: several animations on one layer add up (moves and turns) or multiply (opacity and size).
    private func applyPlacement(_ sampler: Sampler, to pose: inout MotionPose) {
        if let value = sampler.number(\.opacity) { pose.opacity *= value }
        if let value = sampler.number(\.tx) { pose.tx += value }
        if let value = sampler.number(\.ty) { pose.ty += value }
        if let value = sampler.number(\.sx) { pose.sx *= value }
        if let value = sampler.number(\.sy) { pose.sy *= value }
        if let value = sampler.number(\.rot) { pose.rot += value }
        if let value = sampler.number(\.offsetDistancePct) { pose.along = value / 100 }
    }

    /// How it is drawn.
    private func applyDrawing(_ sampler: Sampler, to pose: inout MotionPose) {
        if let value = sampler.number(\.blur) { pose.blur = value }
        if let value = sampler.number(\.dashOffset) { pose.dash = value }
        if let value = sampler.number(\.letterSpacingEm) { pose.letterSpacingEm = value }
        if let value = sampler.number(\.brightness) { pose.brightness = value }
        if let value = sampler.number(\.glowR) { pose.glowRadius = value }
        if let value = sampler.number(\.glowSpread) { pose.glowSpread = value }
        if let value = sampler.number(\.clipRight) { pose.clipRight = value / 100 }
        if let value = sampler.number(\.topPct) { pose.topPct = value }
        if let value = sampler.number(\.radius) { pose.radius = value }
        if let value = sampler.number(\.bgX) { pose.bgX = value }
    }

    private func applyColours(_ sampler: Sampler, to pose: inout MotionPose) {
        if let value = sampler.colour(\.color) { pose.color = value }
        if let value = sampler.colour(\.background) { pose.background = value }
        if let value = sampler.colour(\.glow) { pose.glow = value }
    }

    /// One animation's keyframes at one second.
    private struct Sampler {
        let keyframes: [MotionFrame]
        let easing: MotionEasing
        let time: Double

        func number(_ channel: KeyPath<MotionFrame, Double?>) -> Double? {
            MotionClip.sample(keyframes, channel, easing: easing, at: time)
        }

        func colour(_ channel: KeyPath<MotionFrame, [Double]?>) -> Color? {
            MotionClip.sampleColor(keyframes, channel, easing: easing, at: time)
        }
    }

    /// The channel at `time`: before its first keyframe and after its last it holds; between two it eases with the earlier one's easing
    /// (the animation's when that has none), as CSS does.
    private static func sample(
        _ keyframes: [MotionFrame], _ channel: KeyPath<MotionFrame, Double?>, easing: MotionEasing, at time: Double
    ) -> Double? {
        guard let (from, to, eased) = segment(keyframes, channel, easing: easing, at: time) else { return nil }
        guard let end = to else { return from }
        return from + (end - from) * eased
    }

    private static func sampleColor(
        _ keyframes: [MotionFrame], _ channel: KeyPath<MotionFrame, [Double]?>, easing: MotionEasing, at time: Double
    ) -> Color? {
        let own = keyframes.filter { $0[keyPath: channel] != nil }
        guard let first = own.first, let last = own.last else { return nil }
        func color(_ rgba: [Double]) -> Color {
            Color(.sRGB, red: rgba[0] / 255, green: rgba[1] / 255, blue: rgba[2] / 255, opacity: rgba[3])
        }
        if time <= first.t { return color(first[keyPath: channel] ?? []) }
        if time >= last.t { return color(last[keyPath: channel] ?? []) }
        guard let index = own.lastIndex(where: { $0.t <= time }), index + 1 < own.count,
              let a = own[index][keyPath: channel], let b = own[index + 1][keyPath: channel], a.count == 4, b.count == 4
        else { return nil }
        let span = max(own[index + 1].t - own[index].t, 0.0001)
        let eased = (own[index].easing ?? easing).value(at: (time - own[index].t) / span)
        // CSS mixes colours premultiplied: a fade to transparent keeps its hue.
        let alphaA = a[3]
        let alphaB = b[3]
        let alpha = alphaA + (alphaB - alphaA) * eased
        func mix(_ index: Int) -> Double {
            let from = a[index] * alphaA
            let to = b[index] * alphaB
            let premultiplied = from + (to - from) * eased
            return alpha > 0.0001 ? premultiplied / alpha : b[index]
        }
        return Color(.sRGB, red: mix(0) / 255, green: mix(1) / 255, blue: mix(2) / 255, opacity: alpha)
    }

    /// Where `time` falls among the keyframes that set `channel`: the value it starts from, the one it heads to (nil when it holds), and the
    /// eased progress between them.
    private static func segment(
        _ keyframes: [MotionFrame], _ channel: KeyPath<MotionFrame, Double?>, easing: MotionEasing, at time: Double
    ) -> (Double, Double?, Double)? {
        var previous: MotionFrame?
        var previousValue = 0.0
        for frame in keyframes {
            guard let value = frame[keyPath: channel] else { continue }
            if let before = previous, time < frame.t, time >= before.t {
                let span = max(frame.t - before.t, 0.0001)
                return (previousValue, value, (before.easing ?? easing).value(at: (time - before.t) / span))
            }
            if previous == nil, time <= frame.t { return (value, nil, 0) }
            previous = frame
            previousValue = value
        }
        return previous == nil ? nil : (previousValue, nil, 0)
    }
}
