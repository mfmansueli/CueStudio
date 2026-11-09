//
//  FrameMaskCaption.swift
//  Cue Studio
//

import SwiftUI

/// "16:9 · ONLY THE FRAME IS RECORDED": a quiet caption on the darkened part of the camera when the frame leaves some of it out (16:9, 1:1,
/// 4:5), in the first free strip under the frame and the text window, above the controls, or else over them; none when neither has room.
/// Without it the dark bands of a YouTube frame read as a fault (the owner, 09/11/2026). Only the preview: never recorded.
struct FrameMaskCaption: View {
    let aspect: AspectRatio
    /// Its middle, in screen points (the frame's middle across, `centerY` down).
    let center: CGPoint

    nonisolated static let height: CGFloat = 12
    nonisolated static let gap: CGFloat = 2

    /// Where the caption's middle goes: under the frame and the window when that strip is free down to the controls, else above both when
    /// that is free up to the top bar; nil when neither fits (it is never drawn over the words or the controls).
    nonisolated static func centerY(frame: CGRect, window: CGRect?, top: CGFloat, bottom: CGFloat) -> CGFloat? {
        let below = max(frame.maxY, window?.maxY ?? frame.maxY) + gap
        if below + height <= bottom - gap { return below + height / 2 }
        let above = min(frame.minY, window?.minY ?? frame.minY) - gap - height
        if above >= top + gap { return above + height / 2 }
        return nil
    }

    var body: some View {
        Text("\(aspect.label) · Only the frame is recorded")
            .font(.fixed(9, weight: .bold))
            .kerning(0.6)
            .textCase(.uppercase)
            .foregroundStyle(Palette.Camera.frameCaption)
            .shadow(color: Palette.textShadow, radius: 1.5, y: 1)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(height: Self.height)
            .position(center)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
