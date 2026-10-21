//
//  CardRowBackground.swift
//  Cue Studio
//

import SwiftUI

/// The card behind the rows of a grouped list on the sky, with the card's shadow (`CardRowSlice`): each row draws its slice of the
/// section's card, so it is told where it sits in it. Solid `surface`, the same card as Profile's and Takes' (the owner's call,
/// 20/10/2026: Settings' translucent cards let the sky through and looked unlike the rest of the app).
private struct CardRowBackground: ViewModifier {
    let position: CardRowPosition

    func body(content: Content) -> some View {
        content
            .cardRowSurface(Palette.surface, position: position)
            .listRowInsets(EdgeInsets(top: 9, leading: 16, bottom: 9, trailing: 16))
            .listRowSeparatorTint(Palette.separator)
    }
}

extension View {
    /// The row sits on Cue's card, with Cue's separator. `position` is where it sits in its section: the first row has the
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
