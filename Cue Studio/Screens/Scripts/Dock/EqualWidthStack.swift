//
//  EqualWidthStack.swift
//  Cue Studio
//

import SwiftUI

/// Its subviews one over another, each as wide as the widest: a chip with two looks keeps one width whichever it shows (the dock's writer
/// chip, so the system menu closes back onto the same capsule and nothing in the row moves when the writer changes). Subviews that should
/// fill the width stretch to the width they are given (`IdeaCardChip.stretches`); give the others `.hidden()`.
struct EqualWidthStack: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return CGSize(width: sizes.map(\.width).max() ?? 0, height: sizes.map(\.height).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            subview.place(
                at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center,
                proposal: ProposedViewSize(width: bounds.width, height: bounds.height)
            )
        }
    }
}
