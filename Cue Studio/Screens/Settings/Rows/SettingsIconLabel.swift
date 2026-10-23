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
            Text(title).foregroundStyle(titleColor)
            if let badge {
                Text(badge)
                    .monoFont(size: 10, weight: .heavy)
                    .foregroundStyle(Palette.accInk)
                    .padding(.horizontal, 6)
                    .frame(height: 18)
                    .background(Palette.acc, in: Capsule())
            }
            Spacer(minLength: 8)
            if let value {
                Text(verbatim: value).foregroundStyle(Palette.ink2).lineLimit(1)
            }
        }
        .frame(minHeight: Metrics.listRowContent)
        .contentShape(Rectangle())
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
