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
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(Palette.warnText)
                .accessibilityHidden(true)
            Text("Written with Apple Intelligence. AI can get facts wrong — check dates, names and numbers before you record.")
                .font(.footnote)
                .foregroundStyle(Palette.ink.opacity(0.86))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Button("Checked", action: onChecked)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.accText)
                .frame(minHeight: Metrics.hitTarget)
                .accessibilityHint(Text("Hides this reminder"))
                .accessibilityIdentifier("detail.factCheckedButton")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
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
