//
//  AIAura.swift
//  Cue Studio
//

import SwiftUI

/// The light that turns around the border of a card while the AI writes: a 2 pt conic gradient
/// (lilac → yellow → soft yellow → pale violet) going round once every 2.8 s. It fades in over 0.5 s
/// when `isActive` becomes true and out over 0.9 s when it ends. Still under Reduce Motion.
struct AIAura: ViewModifier {
    var isActive: Bool
    var cornerRadius: CGFloat = Metrics.cardRadius

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isActive || reduceMotion)) { context in
                let turn = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate / CueMotion.Duration.auraTurn
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        AngularGradient(
                            colors: [Color(hex: 0xB4A7FF), Palette.acc, Color(hex: 0xFFF6C2), Color(hex: 0xE4DEFF), Color(hex: 0xB4A7FF)],
                            center: .center, angle: .degrees(turn * 360)
                        ),
                        lineWidth: 2
                    )
                    .shadow(color: Color(hex: 0xB4A7FF).opacity(0.5), radius: 8)
            }
            .opacity(isActive ? 1 : 0)
            .animation(.easeInOut(duration: isActive ? 0.5 : 0.9), value: isActive)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

extension View {
    /// The AI aura around this card while `isActive`.
    func aiAura(isActive: Bool, cornerRadius: CGFloat = Metrics.cardRadius) -> some View {
        modifier(AIAura(isActive: isActive, cornerRadius: cornerRadius))
    }
}
