//
//  PersonalizeFeelRow.swift
//  Cue Studio
//

import SwiftUI

/// A switch of Settings › Personalize › Feel: its icon on a tile of its family (violet for what the app shows, grey for the rest,
/// `Palette.Settings`), the title and what it does; switched on, it answers at once (`onEnable`: the sparkles of a celebration felt,
/// the first tap of the haptics), so the creator feels what they turned on.
struct PersonalizeFeelRow: View {
    @Binding var isOn: Bool
    let symbol: String
    let isAI: Bool
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let onEnable: () -> Void

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 13) {
                Image(systemName: symbol)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isAI ? Palette.Settings.aiGlyph : Palette.Settings.generalGlyph)
                    .frame(width: 32, height: 32)
                    .background(tile, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(Palette.ink)
                    Text(detail).font(.footnote).foregroundStyle(Palette.ink2)
                }
            }
        }
        .tint(Palette.success)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .onChange(of: isOn) { _, on in
            if on { onEnable() }
        }
    }

    private var tile: LinearGradient {
        let colors = isAI
            ? [Palette.Settings.aiTileTop, Palette.Settings.aiTileBottom]
            : [Palette.Settings.generalTileTop, Palette.Settings.generalTileBottom]
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }
}
