//
//  HUDLine.swift
//  Cue Studio
//

import SwiftUI

/// A status line in monospaced capitals: an optional dot and the values, joined by "·"
/// ("● MIC · SETUP ›", "✓ FITS", "06 SCRIPTS · 14 TAKES"). Yellow text is a HUD signal, so the
/// default tint is `accText`; pass `Palette.successText` for "ready", `Palette.ink2` for a quiet one.
/// Pass the values already localized.
struct HUDLine: View {
    var values: [String]
    /// What goes between the values: " · " by default, " / " for a count ("12 TAKES / 05 VIDEOS").
    var separator = " · "
    var dotColor: Color?
    var tint: Color = Palette.accText

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: 6) {
            if let dotColor { ColorDot(color: dotColor, size: 6) }
            Text(values.joined(separator: separator))
                .font(CueStudioFont.hud)
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(tint)
                // With the biggest text sizes the line wraps instead of dropping the end of what it says.
                .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                .minimumScaleFactor(typeSize.isAccessibilitySize ? 1 : 0.8)
                .fixedSize(horizontal: false, vertical: typeSize.isAccessibilitySize)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(values.joined(separator: ", ")))
    }
}

#if DEBUG
#Preview {
    VStack(alignment: .leading, spacing: 12) {
        HUDLine(values: ["06 scripts", "14 takes"])
        HUDLine(values: ["Mic", "Setup ›"], dotColor: Palette.live)
        HUDLine(values: ["✓ Fits"], tint: Palette.successText)
        HUDLine(values: ["Take 4", "TikTok setup"], tint: Palette.ink2)
    }
    .padding()
    .background(Palette.bg)
}
#endif
