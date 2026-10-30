//
//  WidthSlack.swift
//  Cue Studio
//

import SwiftUI

/// The room a chip of the dock's row may yet need for its widest version, kept at the row's end before the lightbulb: the row's layout
/// (`ScriptsDock.RowWords`) is chosen for the widest, so picking another writer or network never changes the other chips (a Format that
/// lost its word, a voice chip that shortened), and the lightbulb stays put. Its first subview is the chip as it is shown, the others its
/// other versions; all are measured, none is drawn (give them `.hidden()`).
struct WidthSlack: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let widths = subviews.map { $0.sizeThatFits(.unspecified).width }
        guard let shown = widths.first else { return .zero }
        return CGSize(width: max(0, (widths.max() ?? shown) - shown), height: 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            subview.place(at: bounds.origin, proposal: .unspecified)
        }
    }
}
