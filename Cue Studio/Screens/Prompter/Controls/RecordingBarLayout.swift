//
//  RecordingBarLayout.swift
//  Cue Studio
//

import SwiftUI

/// The Selfie navigation bar while a take records: the REC pill, then the take's name, side by side in one toolbar item that never grows past
/// the room the bar has (`maxWidth`, the screen less the bar's margins). The first view keeps its own size; each next one gets what is left
/// and no more than it wants, so on a narrow iPhone, with a long language or a large text size, the name shrinks instead of running under the
/// clock. A toolbar item is laid out at its ideal size, which is why the room is given here rather than taken from the bar.
struct RecordingBarLayout: Layout {
    var maxWidth: CGFloat
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = sizes(of: subviews)
        let width = sizes.reduce(0) { $0 + $1.width } + spacing * CGFloat(max(0, sizes.count - 1))
        return CGSize(width: width, height: sizes.map(\.height).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (subview, size) in zip(subviews, sizes(of: subviews)) {
            subview.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(size))
            x += size.width + spacing
        }
    }

    /// Each view's size: the first at its ideal, the others offered what is left of `maxWidth` (never more than they want).
    private func sizes(of subviews: Subviews) -> [CGSize] {
        var left = maxWidth
        return subviews.enumerated().map { index, subview in
            let ideal = subview.sizeThatFits(.unspecified)
            guard index > 0 else {
                left -= ideal.width + spacing
                return ideal
            }
            let room = max(0, min(ideal.width, left))
            let size = subview.sizeThatFits(ProposedViewSize(width: room, height: nil))
            left -= room + spacing
            return CGSize(width: min(size.width, room), height: size.height)
        }
    }
}
