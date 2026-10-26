//
//  TransitionDim.swift
//  Cue Studio
//

import SwiftUI

/// The app drawn back behind the idea's star (09 §8): darker (brightness −0.4), less saturated (0.7), blurred (10 pt) and smaller (0.94,
/// from a point above the middle), as far as `amount` (0 → 1) says. With Reduce Motion it doesn't shrink.
struct TransitionDim: ViewModifier {
    var amount: Double
    var recedes: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(recedes ? 1 - 0.06 * amount : 1, anchor: UnitPoint(x: 0.5, y: 0.4))
            .brightness(-0.4 * amount)
            .saturation(1 - 0.3 * amount)
            .blur(radius: 10 * amount)
    }
}
