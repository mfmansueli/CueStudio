//
//  FactCheckBanner.swift
//  Cue Studio
//

import SwiftUI

/// On AI scripts about factual topics, and on every Ultra draft, until the creator says they reviewed the claims of this version ("I
/// checked", recorded with the date); an AI rewrite that changes the words brings it back.
struct FactCheckBanner: View {
    /// Ultra AI's drafts say who wrote them (the Cue server's model), with nothing that checks its claims.
    var engine: ScriptEngine = .apple
    let onChecked: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        // Everything on the card's middle line: the star, the words (one or two lines) and Checked, with the same room above and below.
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(Palette.warnText)
                .accessibilityHidden(true)
            Text(engine == .ultra
                ? "Ultra AI can get facts wrong · Check before you record"
                : "AI can get facts wrong · Check before you record")
                .cueFont(.footnote)
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Button("I checked", action: onChecked)
                .cueFont(.footnote, weight: .semibold)
                .foregroundStyle(Palette.accText)
                .frame(minHeight: Metrics.hitTarget)
                .accessibilityLabel(Text("I reviewed the claims"))
                .accessibilityHint(Text("Records that you reviewed this version"))
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
