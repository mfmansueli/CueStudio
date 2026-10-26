//
//  SettingsIconLabel.swift
//  Cue Studio
//

import SwiftUI

/// The label of a row on the Settings root: a 32 pt icon tile (radius 9, its family's colour with a thin light along the top, `SettingsIcon`),
/// the title, what is set, and a small tag ("NEW").
struct SettingsIconLabel: View {
    let icon: SettingsIcon
    let title: String
    var titleColor: Color = Palette.ink
    var value: String?
    var badge: String?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let tile = RoundedRectangle(cornerRadius: 9, style: .continuous)
        HStack(spacing: 13) {
            icon.image
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 21, height: 21)
                .foregroundStyle(icon.glyph)
                .frame(width: 32, height: 32)
                .background(icon.tile, in: tile)
                .overlay {
                    // Only the top edge catches the light: a hairline that fades out before the sides.
                    tile.strokeBorder(
                        LinearGradient(colors: [Palette.Settings.tileRim, .clear], startPoint: .top, endPoint: .center), lineWidth: 0.5
                    )
                }
                .accessibilityHidden(true)
            // At the accessibility text sizes the value goes under the name: beside it, the name broke into syllables.
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title).foregroundStyle(titleColor)
                        badgeView
                    }
                    if let value {
                        Text(verbatim: value).foregroundStyle(Palette.ink2)
                    }
                }
                Spacer(minLength: 0)
            } else {
                Text(title).foregroundStyle(titleColor)
                badgeView
                Spacer(minLength: 8)
                if let value {
                    Text(verbatim: value).foregroundStyle(Palette.ink2).lineLimit(1)
                }
            }
        }
        .frame(minHeight: Metrics.listRowContent)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var badgeView: some View {
        if let badge {
            Text(badge)
                .monoFont(size: 10, weight: .heavy)
                .foregroundStyle(Palette.accInk)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .frame(minHeight: 18)
                .background(Palette.acc, in: Capsule())
        }
    }
}

#if DEBUG
#Preview {
    List {
        SettingsIconLabel(icon: .prompter, title: "Prompter", value: "Voice")
        SettingsIconLabel(icon: .personalize, title: "Personalize", badge: "NEW")
        SettingsIconLabel(icon: .pro, title: "Cue Pro", value: "Free · 4 left")
        SettingsIconLabel(icon: .version, title: "Version", value: "1.0 (12)")
    }
    .cueGroupedList()
}
#endif
