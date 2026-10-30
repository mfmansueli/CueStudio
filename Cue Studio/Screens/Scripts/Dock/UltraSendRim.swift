//
//  UltraSendRim.swift
//  Cue Studio
//

import SwiftUI

/// The send arrow while Ultra AI writes the next idea: a thin rim of Cue's violet and gold (`Palette.Scripts.ultraGlow`) going slowly round
/// it, a lap every 4 s, with a soft glow (wider, fainter strokes, never a blur), so at a glance the next script is Ultra AI's. It stops where
/// it is when something covers the dock (`isRunning`) and stands still under Reduce Motion. Decorative.
struct UltraSendRim: View {
    var isRunning: Bool

    /// One lap round the arrow.
    private static let lap = 4.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let colors = Palette.Scripts.ultraGlow
        let still = reduceMotion || !isRunning
        return TimelineView(.animation(minimumInterval: 1.0 / 30, paused: still)) { context in
            let turn = still ? 0 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.lap) / Self.lap * 360
            let gradient = AngularGradient(colors: colors, center: .center, angle: .degrees(turn))
            ZStack {
                Circle().stroke(gradient, lineWidth: 6).opacity(0.16)
                Circle().stroke(gradient, lineWidth: 3).opacity(0.3)
                Circle().stroke(gradient, lineWidth: 1.4)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
