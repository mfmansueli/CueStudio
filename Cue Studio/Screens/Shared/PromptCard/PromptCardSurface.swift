//
//  PromptCardSurface.swift
//  Cue Studio
//

import SwiftUI

/// The Prompt card's look: light moving over `base`, the 26 pt corners and the thin gold border,
/// around whatever the card holds. `PromptCard` (a button into Generate) and `IdeaPromptCard`
/// (the Scripts screen's field) share it, so they can't drift apart. The idea card asks for the
/// aurora and the light running around its border (`AuroraCardBackground`); the Prompt card in
/// New script keeps the quiet wash.
struct PromptCardSurface<Content: View>: View {
    /// The card sits on the sheet (`surface`) or on the screen background, so its base follows.
    var base: Color = Palette.surface2
    var animatesBackground = true
    var usesAurora = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if usesAurora {
                    AuroraCardBackground(base: base, cornerRadius: Metrics.cardRadius, isActive: animatesBackground)
                } else {
                    AnimatedPromptBackground(base: base, isActive: animatesBackground)
                        .clipShape(shape)
                }
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
