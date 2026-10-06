//
//  ProPlanRow.swift
//  Cue Studio
//

import SwiftUI

/// The two plans of the Pro screen side by side (11.4): Yearly takes 1.2 parts of the width and Monthly 1, 10 pt apart (the board's `flex: 1.2` and `flex: 1`).
struct ProPlanRow: Layout {
    var weights: [CGFloat] = [1.2, 1]
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 0, height: subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let total = weights.prefix(subviews.count).reduce(0, +)
        guard total > 0 else { return }
        let available = bounds.width - spacing * CGFloat(max(0, subviews.count - 1))
        var x = bounds.minX
        for (index, subview) in subviews.enumerated() {
            let width = available * weights[min(index, weights.count - 1)] / total
            subview.place(at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading, proposal: ProposedViewSize(width: width, height: bounds.height))
            x += width + spacing
        }
    }
}
