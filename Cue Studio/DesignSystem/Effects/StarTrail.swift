//
//  StarTrail.swift
//  Cue Studio
//

import SwiftUI

/// The star of the first flight with its tail: the same head four times, each a little behind the one before (0.06 s) and smaller,
/// dimmer and warmer (11, 7.5, 6 and 5 pt). A scene gives it the pose of each copy at the second it is drawing (`MotionClip`: the board's
/// `unst` layers), so the tail follows the head without a clock of its own.
struct StarTrail: View {
    /// The copies from the head to the last of the tail; each pose places it (`tx`, `ty` from the screen's top left) and fades it.
    let poses: [MotionPose]

    private static let looks: [(size: CGFloat, color: Color)] = [
        (11, .white), (7.5, Palette.Universe.starCream), (6, Palette.Universe.starWarm), (5, Palette.Universe.starGold),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Back to front: the tail first, so the head is on top.
            ForEach(Array(poses.enumerated()).reversed(), id: \.offset) { index, pose in
                let look = Self.looks[min(index, Self.looks.count - 1)]
                GlowDot(diameter: look.size, color: look.color, glow: Palette.Universe.starCream.opacity(0.9), glowRadius: 7)
                    .position(x: pose.tx, y: pose.ty)
                    .opacity(pose.opacity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
