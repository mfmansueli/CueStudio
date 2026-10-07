//
//  FactCheckBanner.swift
//  Cue Studio
//

import SwiftUI

/// On AI scripts about factual topics, until the creator confirms the facts.
struct FactCheckBanner: View {
    let onChecked: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        // Everything on the card's middle line: the star, the words (one or two lines) and Checked, with the same room above and below.
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(Palette.warnText)
                .accessibilityHidden(true)
            Text("AI can get facts wrong · Check before you record")
                .font(.footnote)
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Button("Checked", action: onChecked)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.accText)
                .frame(minHeight: Metrics.hitTarget)
                .accessibilityHint(Text("Hides this reminder"))
                .accessibilityIdentifier("detail.factCheckedButton")
        }
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
        .background(Palette.warnWash, in: shape)
        .overlay(shape.strokeBorder(Palette.warnBorder, lineWidth: 0.5))
    }
}

#if DEBUG
#Preview {
    FactCheckBanner(onChecked: {})
        .padding()
        .background(Palette.bg)
}
#endif
