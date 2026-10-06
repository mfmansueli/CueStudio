//
//  MotionPoseModifier.swift
//  Cue Studio
//

import SwiftUI

/// Puts a view where a board's animation has it: scaled and turned about `anchor` (the CSS `transform-origin`), then moved, with the opacity
/// and the blur of that moment. The order is CSS's (translate · rotate · scale: the scale acts first).
private struct MotionPoseModifier: ViewModifier {
    let pose: MotionPose
    let anchor: UnitPoint

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: pose.sx, y: pose.sy, anchor: anchor)
            .rotationEffect(.degrees(pose.rot), anchor: anchor)
            .offset(x: pose.tx, y: pose.ty)
            .blur(radius: pose.blur)
            .opacity(pose.opacity)
    }
}

extension View {
    /// The view at `pose` of its layer in the board's motion (`MotionClip.pose(of:at:)`).
    func motion(_ pose: MotionPose, anchor: UnitPoint = .center) -> some View {
        modifier(MotionPoseModifier(pose: pose, anchor: anchor))
    }
}
