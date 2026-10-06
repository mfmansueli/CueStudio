//
//  MotionFrame.swift
//  Cue Studio
//

import Foundation

/// One keyframe of a board's `@keyframes`, baked by `tools/bake_motion.py`: the second it sits at and only the channels that keyframe
/// sets (a channel is interpolated between the keyframes that set it). The easing is the one of the stretch that starts here.
nonisolated struct MotionFrame: Decodable, Sendable {
    var t: Double
    var opacity: Double?
    var tx: Double?
    var ty: Double?
    var sx: Double?
    var sy: Double?
    var rot: Double?
    var blur: Double?
    /// 0...100 of an SVG stroke still undrawn (`stroke-dashoffset` on a path of length 100): draw with `trim`.
    var dashOffset: Double?
    var letterSpacingEm: Double?
    /// 0...100, how far along its `offset-path` the thing is.
    var offsetDistancePct: Double?
    /// `[r, g, b, a]` with r, g, b in 0...255 and a in 0...1.
    var color: [Double]?
    var background: [Double]?
    var brightness: Double?
    /// The first shadow's blur radius, spread and colour (`text-shadow` and `box-shadow`).
    var glowR: Double?
    var glowSpread: Double?
    var glow: [Double]?
    /// `clip-path: inset(...)`; the right inset, in % of the width when `clipRightPct` is 1.
    var clipRight: Double?
    var clipRightPct: Double?
    var clipLeft: Double?
    var topPct: Double?
    var radius: Double?
    var bgX: Double?
    var tilt: Double?
    var easing: MotionEasing?
}
