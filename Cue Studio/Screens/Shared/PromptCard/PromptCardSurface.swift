//
//  PromptCardSurface.swift
//  Cue Studio
//

import SwiftUI

/// The idea card's look: the violet aurora and the light running around its border
/// (`AuroraCardBackground`) over `base`, the 26 pt corners and the thin violet border, around
/// whatever the card holds.
struct PromptCardSurface<Content: View>: View {
    /// The card sits on the sheet (`surface`) or on the screen background, so its base follows.
    var base: Color = Palette.surface2
    var animatesBackground = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                AuroraCardBackground(base: base, cornerRadius: Metrics.cardRadius, isActive: animatesBackground)
            }
            .overlay(shape.strokeBorder(Palette.aiBorder, lineWidth: 0.5))
            .contentShape(shape)
    }
}

/// "✦ LET'S CUE" in yellow mono (the three stars twinkle in place of the one).
struct PromptCardHeader: View {
    var animatesBackground = true

    var body: some View {
        HStack(spacing: 8) {
            PromptCardStarTwinkle(isActive: animatesBackground)
            Text("Let’s Cue")
                .font(CueStudioFont.hud)
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(Palette.accText)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
        }
    }
}
