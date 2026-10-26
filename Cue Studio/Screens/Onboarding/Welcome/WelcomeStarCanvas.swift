//
//  WelcomeStarCanvas.swift
//  Cue Studio
//

import SwiftUI

/// The welcome's star scene (`WelcomeStarPainter`) on a canvas the size of the screen, with the board's 390 × 844 frame centred on it
/// at `scale`.
struct WelcomeStarCanvas: View {
    let time: Double
    /// The seconds since the opening began, past its end: the lit dots keep shining.
    let ambient: Double
    let starPath: PoseTrack
    /// How big the board is drawn (`WelcomeLayout.artScale`), from its top, centred.
    var scale: CGFloat = 1

    var body: some View {
        Canvas { context, size in
            context.translateBy(x: size.width / 2, y: 0)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -WelcomeScript.frame.width / 2, y: 0)
            WelcomeStarPainter(time: time, ambient: ambient, starPath: starPath).paint(in: &context)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
