//
//  ProgressOrbit.swift
//  Cue Studio
//

import SwiftUI

/// How much of the script is written, as an orbit round the star while it waits (`StarTransitionOverlay`): a faint full circle and, over it,
/// an arc in Apple Intelligence's colours (`Palette.Scripts.dockGlow`) that closes as the words arrive, with a bright head where it is
/// now. It closes whole when the script is there. The "42%" under the phrase says the same in words. Decorative.
struct ProgressOrbit: View {
    let meter: WritingProgressMeter

    static let diameter: CGFloat = 66

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: meter.isFinished)) { _ in
            let fraction = max(0.02, min(1, meter.fraction))
            ZStack {
                Circle()
                    .stroke(Palette.Scripts.transitionOrbitTrack, lineWidth: 1.5)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(
                        AngularGradient(colors: Palette.Scripts.dockGlow, center: .center, startAngle: .degrees(0), endAngle: .degrees(360)),
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Palette.aiText.opacity(0.6), radius: 4)
                // The head of the arc: a small light where the writing is now.
                Circle()
                    .fill(.white)
                    .frame(width: 4, height: 4)
                    .shadow(color: Palette.aiText, radius: 4)
                    .offset(y: -Self.diameter / 2)
                    .rotationEffect(.degrees(360 * fraction))
            }
            .frame(width: Self.diameter, height: Self.diameter)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: fraction)
        }
        .accessibilityHidden(true)
    }
}
