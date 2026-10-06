//
//  WelcomeStarCanvas.swift
//  Cue Studio
//

import SwiftUI

/// The welcome's star scene (`WelcomeStarPainter`) on a canvas the size of the screen, with the board's 390 × 844 frame centred on it.
struct WelcomeStarCanvas: View {
    let time: Double
    let starPath: PoseTrack

    var body: some View {
        Canvas { context, size in
            context.translateBy(x: (size.width - WelcomeScript.frame.width) / 2, y: 0)
            WelcomeStarPainter(time: time, starPath: starPath).paint(in: &context)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
