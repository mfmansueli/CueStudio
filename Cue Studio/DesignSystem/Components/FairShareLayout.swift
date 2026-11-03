//
//  FairShareLayout.swift
//  Cue Studio
//

import SwiftUI

/// Slots side by side that never cut a word: each gets an equal share of the row while every one fits in it; otherwise each gets its own
/// width plus an equal part of what is left; only past that do the shares fall, in proportion (and the labels shrink, never cut: they
/// carry a `minimumScaleFactor`). Its ideal width is the slots' own widths added up, so a `ViewThatFits` around it moves on to another
/// arrangement (stacked, or without symbols) as soon as the words would not fit side by side (owner, 02/11/2026: no label is ever cut,
/// in any language).
///
/// With `underlay`, the first subview isn't a slot: it is laid under that slot, as a segmented control's thumb, and glides to another one
/// when `underlay` changes inside an animation.
struct FairShareLayout: Layout {
    var spacing: CGFloat = 0
    var underlay: Int?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ideals = slots(subviews).map { $0.sizeThatFits(.unspecified) }
        let width = proposal.width ?? (ideals.reduce(0) { $0 + $1.width } + totalSpacing(ideals.count))
        let height = proposal.height ?? ideals.map(\.height).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let slots = slots(subviews)
        let ideals = slots.map { $0.sizeThatFits(.unspecified).width }
        let widths = Self.widths(ideals: ideals, in: bounds.width - totalSpacing(ideals.count))
        var x = bounds.minX
        for (index, slot) in slots.enumerated() {
            let size = CGSize(width: widths[index], height: bounds.height)
            let origin = CGPoint(x: x, y: bounds.minY)
            if index == underlay, let thumb = subviews.first {
                thumb.place(at: origin, proposal: ProposedViewSize(size))
            }
            slot.place(at: origin, proposal: ProposedViewSize(size))
            x += widths[index] + spacing
        }
    }

    /// Each slot's width in `width`: an equal share when every slot's own width fits in one, else its own width plus an equal part of what
    /// is left, else its own width scaled down with the rest.
    static func widths(ideals: [CGFloat], in width: CGFloat) -> [CGFloat] {
        guard !ideals.isEmpty else { return [] }
        let count = CGFloat(ideals.count)
        let share = width / count
        if ideals.allSatisfy({ $0 <= share }) { return ideals.map { _ in share } }
        let sum = ideals.reduce(0, +)
        if sum <= width { return ideals.map { $0 + (width - sum) / count } }
        return ideals.map { sum > 0 ? $0 * width / sum : share }
    }

    private func slots(_ subviews: Subviews) -> Subviews {
        underlay == nil ? subviews[...] : subviews.dropFirst()
    }

    private func totalSpacing(_ count: Int) -> CGFloat {
        spacing * CGFloat(max(0, count - 1))
    }
}
