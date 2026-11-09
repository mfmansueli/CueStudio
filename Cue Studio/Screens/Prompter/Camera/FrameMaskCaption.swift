//
//  FrameMaskCaption.swift
//  Cue Studio
//

import SwiftUI

/// "16:9 · ONLY THE FRAME IS RECORDED": a quiet caption when the frame leaves part of the camera out (16:9, 1:1, 4:5), first in the stack over
/// the controls, where it always has room (the text window ends above that stack). Without it the dark bands of a YouTube frame read as a
/// fault (the owner, 09/11/2026). Only the preview: never recorded.
struct FrameMaskCaption: View {
    let aspect: AspectRatio

    var body: some View {
        Text("\(aspect.label) · Only the frame is recorded")
            .font(.fixed(9, weight: .bold))
            .kerning(0.6)
            .textCase(.uppercase)
            .foregroundStyle(Palette.Camera.frameCaption)
            .shadow(color: Palette.textShadow, radius: 1.5, y: 1)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .accessibilityIdentifier("prompter.frameCaption")
    }
}
