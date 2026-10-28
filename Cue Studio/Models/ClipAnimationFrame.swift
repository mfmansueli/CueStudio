//
//  ClipAnimationFrame.swift
//  Cue Studio
//

import Foundation

/// A clip's picture at a moment of its Animation (`ClipAnimation.frame`): shifted (fractions of the frame, +y down), scaled
/// around its middle, faded over black and blurred (fractions of the frame's width).
nonisolated struct ClipAnimationFrame: Hashable, Sendable {
    static let still = ClipAnimationFrame()

    var dx = 0.0
    var dy = 0.0
    var scale = 1.0
    var opacity = 1.0
    var blur = 0.0
}
