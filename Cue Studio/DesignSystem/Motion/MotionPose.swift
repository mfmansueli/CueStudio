//
//  MotionPose.swift
//  Cue Studio
//

import SwiftUI

/// How one layer of a board looks at one second: what `MotionClip.pose(of:at:)` returns. Lengths are points of the board's 390 × 844 frame.
/// Channels no animation of the layer sets stay at their neutral value (or nil).
nonisolated struct MotionPose: Sendable {
    var opacity = 1.0
    var tx = 0.0
    var ty = 0.0
    var sx = 1.0
    var sy = 1.0
    /// Degrees.
    var rot = 0.0
    var blur = 0.0
    /// 0...100 of an SVG stroke still undrawn; `drawn` is the part to `trim` to.
    var dash: Double?
    var letterSpacingEm: Double?
    /// 0...1 along the layer's `offset-path`.
    var along: Double?
    var color: Color?
    var background: Color?
    var brightness = 1.0
    var glowRadius = 0.0
    var glowSpread = 0.0
    var glow: Color?
    /// 0...1 of the width hidden from the right (a reveal), when the board clips with `inset(0 n% 0 0)`.
    var clipRight: Double?
    var topPct: Double?
    var radius: Double?
    var bgX: Double?

    /// The part of an SVG stroke that is drawn (`Shape.trim(from: 0, to:)`).
    var drawn: Double { 1 - (dash ?? 0) / 100 }

    var scale: Double { (sx + sy) / 2 }
}
