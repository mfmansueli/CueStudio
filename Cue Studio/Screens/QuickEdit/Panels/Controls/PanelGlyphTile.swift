//
//  PanelGlyphTile.swift
//  Cue Studio
//

import SwiftUI

/// A tile with a big glyph, a name and, in mono capitals, what it is for or whether it is on (the
/// Cover panel's layouts, typefaces, elements and looks). The chosen one has the 2 pt yellow ring on
/// the yellow wash; a suggestion from Cue is violet.
struct PanelGlyphTile: View {
    let glyph: String
    var glyphFont: Font = .system(size: 22, weight: .heavy)
    let title: String
    var caption: String?
    var captionTint: Color = Palette.ink2
    let isOn: Bool
    var isSuggestion = false
    var width: CGFloat = 84
    let identifier: String
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        Button {
            Haptics.selection()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(glyph)
                    .font(glyphFont)
                    .foregroundStyle(isOn ? Palette.accText : (isSuggestion ? Palette.aiTextStrong : Palette.ink))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSuggestion ? Palette.aiText : Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let caption {
                    Text(caption)
                        .textCase(.uppercase)
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(0.4)
                        .foregroundStyle(isOn ? Palette.accText : captionTint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(10)
            .frame(width: width, height: 90, alignment: .topLeading)
            .background(isOn ? Palette.accTile : (isSuggestion ? Palette.aiFill : Palette.panelCard), in: shape)
            .overlay(shape.strokeBorder(isOn ? Palette.acc : .clear, lineWidth: 2))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(caption ?? ""))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(identifier)
    }
}
