//
//  CardRowBackground.swift
//  Cue Studio
//

import SwiftUI

/// The translucent card behind the rows of a grouped list on the sky (07 §3), solid under Reduce Transparency, with the card's
/// shadow (`CardRowSlice`): each row draws its slice of the section's card, so it is told where it sits in it.
private struct CardRowBackground: ViewModifier {
    let position: CardRowPosition

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .cardRowSurface(reduceTransparency ? Palette.surface : Palette.card, position: position)
            .listRowInsets(EdgeInsets(top: 9, leading: 16, bottom: 9, trailing: 16))
            .listRowSeparatorTint(Palette.separator)
    }
}

extension View {
    /// The row sits on a translucent card, with Cue's separator. `position` is where it sits in its section: the first row has the
    /// card's top and the last its bottom (a row alone is the whole card).
    func cardRowBackground(position: CardRowPosition = .only) -> some View {
        modifier(CardRowBackground(position: position))
    }

    /// A grouped list over the shared sky: the system's inset-grouped look, cards drawn by `cardRowBackground()`.
    func cueGroupedList() -> some View {
        listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .skyBackground()
    }
}
