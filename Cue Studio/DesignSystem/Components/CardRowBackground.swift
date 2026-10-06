//
//  CardRowBackground.swift
//  Cue Studio
//

import SwiftUI

/// The translucent card behind the rows of a grouped list on the sky (07 §3), solid under Reduce Transparency.
private struct CardRowBackground: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .listRowBackground(reduceTransparency ? Palette.surface : Palette.card)
            .listRowInsets(EdgeInsets(top: 9, leading: 16, bottom: 9, trailing: 16))
            .listRowSeparatorTint(Palette.separator)
    }
}

extension View {
    /// The row sits on a translucent card, with Cue's separator.
    func cardRowBackground() -> some View {
        modifier(CardRowBackground())
    }

    /// A grouped list over the shared sky: the system's inset-grouped look, cards drawn by `cardRowBackground()`.
    func cueGroupedList() -> some View {
        listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .skyBackground()
    }
}
