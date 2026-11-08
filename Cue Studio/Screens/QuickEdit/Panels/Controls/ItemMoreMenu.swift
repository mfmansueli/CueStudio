//
//  ItemMoreMenu.swift
//  Cue Studio
//

import SwiftUI

/// "•••" on a style, cover look, brand kit or library item: the same system menu holding it opens, in sight (owner, 07/11/2026,
/// D3). It sits beside the item's own button, never inside it, so opening it never picks or applies the item; tapping the card
/// still does. Its touch area is larger than the mark, and the mark never sits on a card's ★, check or "Default".
struct ItemMoreMenu<Content: View>: View {
    enum Look {
        /// On a picture (a style or cover sample, a library thumbnail): white on the dark badge the card's other marks use.
        case onPicture
        /// On a card's own surface (a brand kit's row): the secondary ink, no badge.
        case onCard
    }

    var look: Look = .onPicture
    let identifier: String
    @ViewBuilder var content: Content

    @ScaledMetric(relativeTo: .caption2) private var badgeSize: CGFloat = 24

    var body: some View {
        Menu {
            content
        } label: {
            mark
                .frame(width: look == .onPicture ? 40 : Metrics.hitTarget, height: look == .onPicture ? 40 : Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel(Text("More options"))
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder private var mark: some View {
        switch look {
        case .onPicture:
            Image(systemName: "ellipsis")
                .font(.system(.caption2, weight: .bold))
                .foregroundStyle(Palette.chipOn)
                .frame(width: badgeSize, height: badgeSize)
                .background(Palette.Editor.presetCardBadge, in: Circle())
        case .onCard:
            Image(systemName: "ellipsis.circle")
                .font(.editorGlyph(EditorGlyph.large))
                .foregroundStyle(Palette.ink2)
        }
    }
}
