//
//  NightAuroraBackground.swift
//  Cue Studio
//

import SwiftUI

extension View {
    /// The night aurora behind this view, cut to `shape`.
    func nightAurora<S: Shape>(in shape: S, yellowTouch: Bool = false) -> some View {
        background { NightAuroraBackground(yellowTouch: yellowTouch).clipShape(shape) }
    }
}

/// The night aurora behind the plan card on Profile and the Pro screen: the surface with a violet
/// glow from the top corner and, with `yellowTouch`, a little yellow from the opposite one. Still;
/// the moving aurora belongs to the idea card.
struct NightAuroraBackground: View {
    var base: Color = Palette.surface
    /// A touch of yellow from the bottom corner: Pro is active, or the paywall is up.
    var yellowTouch = false

    var body: some View {
        base
            .overlay(
                LinearGradient(
                    stops: [.init(color: Palette.aiGlow, location: 0), .init(color: Palette.aiGlowFaint, location: 0.65)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay {
                if yellowTouch {
                    LinearGradient(
                        stops: [.init(color: Palette.accGlowFaint, location: 0.5), .init(color: Palette.accGlow.opacity(0.5), location: 1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
            }
    }
}
