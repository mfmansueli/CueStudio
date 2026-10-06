//
//  WelcomeShootingStar.swift
//  Cue Studio
//

import SwiftUI

/// The streak that crosses the top of the welcome at 6.2 s, after the star has exploded (the board's `.shoot`): 130 × 1.5 pt at x 230, y 64,
/// white at the head (its right end, the pivot), turned 160°, it flies 380 pt down and to the left in 0.84 s, lit for the first 1% of its
/// cycle and gone by 6% of it.
struct WelcomeShootingStar: View {
    let time: Double

    /// Where its box starts in the board's frame (`left`, `top`), when it begins and how long it lasts.
    private static let origin = CGPoint(x: 230, y: 64)
    private static let start = 6.2
    private static let duration = 0.84
    private static let litBy = 0.14

    var body: some View {
        let local = time - Self.start
        let isFlying = local >= 0 && local <= Self.duration
        let travel = -60 + 380 * min(max(local / Self.duration, 0), 1)
        let angle = 160.0 * .pi / 180
        let opacity = local < Self.litBy ? max(local, 0) / Self.litBy : max(0, 1 - (local - Self.litBy) / (Self.duration - Self.litBy))
        Capsule()
            .fill(LinearGradient(
                stops: [
                    .init(color: .white.opacity(0), location: 0), .init(color: Palette.aiTextStrong.opacity(0.55), location: 0.6),
                    .init(color: .white, location: 1),
                ],
                startPoint: .leading, endPoint: .trailing
            ))
            .frame(width: 130, height: 1.5)
            .shadow(color: .white.opacity(0.55), radius: 8)
            // The streak is turned about its head; the travel is along its own (turned) axis.
            .rotationEffect(.radians(angle), anchor: .trailing)
            .offset(x: Self.origin.x + travel * cos(angle), y: Self.origin.y + travel * sin(angle))
            .opacity(isFlying ? opacity : 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
