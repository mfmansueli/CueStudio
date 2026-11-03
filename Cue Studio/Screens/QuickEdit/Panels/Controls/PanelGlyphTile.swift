//
//  PanelGlyphTile.swift
//  Cue Studio
//

import SwiftUI

/// A tile with a big glyph, a name and, in mono capitals, what it is for or whether it is on (the
/// Cover panel's layouts, typefaces, elements and looks). The chosen one has the 2 pt yellow ring on
/// the yellow wash; a suggestion from Cue is violet.
///
/// Its words are never cut, in any language (owner, 02/11/2026: no label is ever cut): the name goes on two lines between
/// words, the caption on up to three, and the tile grows taller than 90 pt for them; a row of tiles keeps one height when it
/// asks its tiles for their ideal height (`.fixedSize(horizontal: false, vertical: true)`), as Cover › Finish does.
struct PanelGlyphTile: View {
    let glyph: String
    var glyphFont: Font = .editorGlyph(EditorGlyph.player, weight: .heavy)
    let title: String
    var caption: String?
    var captionTint: Color = Palette.ink2
    let isOn: Bool
    var isSuggestion = false
    var width: CGFloat = 84
    let identifier: String
    let action: () -> Void

    /// The small capitals under the title, growing with the text size.
    @ScaledMetric(relativeTo: .caption2) private var captionSize: CGFloat = 9

    var body: some View {
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
                WholeWordsLabel(text: title, alignment: .leading, minimumScale: 0.8)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(isSuggestion ? Palette.aiText : Palette.ink)
                if let caption {
                    // Up to three short lines ("AUCUNE / PERSONNE / DÉTECTÉE"): the tile grows for them.
                    Text(caption)
                        .textCase(.uppercase)
                        .monoFont(size: captionSize, weight: .heavy)
                        .interfaceTracking(0.4)
                        .foregroundStyle(isOn ? Palette.accText : captionTint)
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .frame(width: width, alignment: .topLeading)
            .frame(minHeight: 90, maxHeight: .infinity, alignment: .topLeading)
            .editorCard(isOn ? .picked : (isSuggestion ? .filled(Palette.aiFill) : .plain))
            .contentShape(.editorCard)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(caption ?? ""))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(identifier)
    }
}
