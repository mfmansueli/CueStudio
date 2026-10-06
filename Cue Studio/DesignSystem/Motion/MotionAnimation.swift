//
//  MotionAnimation.swift
//  Cue Studio
//

import Foundation

/// One CSS animation on one layer of a board: which keyframes, how long, how late, with which default easing, and whether it loops in the
/// board.
nonisolated struct MotionAnimation: Decodable, Sendable {
    var kf: String
    var duration: Double
    var delay: Double
    var easing: MotionEasing
    var loops: Bool
}
