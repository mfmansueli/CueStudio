//
//  PromptCardSurface.swift
//  Cue Studio
//

import SwiftUI

/// The Prompt card's look: the yellow light moving over `base`, the 26 pt corners and the thin gold
/// border, around whatever the card holds. `PromptCard` (a button into Generate) and `IdeaPromptCard`
/// (the empty Scripts screen's field) share it, so they can't drift apart.
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
                AnimatedPromptBackground(base: base, isActive: animatesBackground)
                    .clipShape(shape)
            }
            .overlay(shape.strokeBorder(Palette.accBorder, lineWidth: 0.5))
            .contentShape(shape)
    }
}

/// The three stars and the title on one line, "Apple Intelligence" at the end.
struct PromptCardHeader: View {
    let title: LocalizedStringKey
    var animatesBackground = true

    var body: some View {
        HStack(spacing: 8) {
            PromptCardStarTwinkle(isActive: animatesBackground)
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            Text("Apple Intelligence")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.ink2)
        }
    }
}
