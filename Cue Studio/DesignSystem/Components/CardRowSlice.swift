//
//  CardRowSlice.swift
//  Cue Studio
//

import SwiftUI

/// One row's slice of its section's card, for `listRowBackground`: the fill, and the card's shadow and top light where this row is the
/// top or the bottom of the card. It draws its own corners (`Metrics.groupedListRadius`, the system's own radius or a little more),
/// so the fill, the hairline and the shadow are one shape and the corners are as defined as on Scripts.
struct CardRowSlice: View {
    let fill: Color
    let position: CardRowPosition

    var body: some View {
        let shape = UnevenRoundedRectangle(cornerRadii: position.cornerRadii(Metrics.groupedListRadius), style: .continuous)
        shape
            .fill(fill)
            .cardDepth(shape, openEdges: position.openEdges)
    }
}

extension View {
    /// The row sits on `fill`, as one slice of the card its section makes, with the card's shadow (`CardRowPosition`).
    func cardRowSurface(_ fill: Color, position: CardRowPosition) -> some View {
        listRowBackground(CardRowSlice(fill: fill, position: position))
    }
}
