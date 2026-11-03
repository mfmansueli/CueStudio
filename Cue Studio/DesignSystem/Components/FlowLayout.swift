//
//  FlowLayout.swift
//  Cue Studio
//

import SwiftUI

/// Lays children out left to right, wrapping to a new line when the row is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6
    /// Where each row sits in the width: `.leading` (the default), `.center` or `.trailing`.
    var alignment: HorizontalAlignment = .leading
    /// Lays the rows out in the narrowest width that keeps their count, so the lines come out about as long as each other
    /// (a title doesn't end on one word alone).
    var balanced = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: lineWidth(proposal.width ?? .infinity, subviews: subviews), subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(0, rows.count - 1))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: lineWidth(bounds.width, subviews: subviews), subviews: subviews) {
            let room = bounds.width - row.width
            var x = bounds.minX + (alignment == .center ? room / 2 : alignment == .trailing ? room : 0)
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    /// The width the rows are made in: `width`, or with `balanced` the narrowest one that needs no more rows than `width` does.
    private func lineWidth(_ width: CGFloat, subviews: Subviews) -> CGFloat {
        guard balanced, width.isFinite else { return width }
        let rows = arrange(width: width, subviews: subviews).count
        guard rows > 1 else { return width }
        var low = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        var high = width
        for _ in 0..<12 where high - low > 1 {
            let middle = (low + high) / 2
            if arrange(width: middle, subviews: subviews).count > rows { low = middle } else { high = middle }
        }
        return high
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width && !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

#if DEBUG
#Preview {
    FlowLayout {
        ForEach(["Lifestyle", "Wellness", "Beauty", "Fitness", "Food", "Tech", "Finance"], id: \.self) {
            FilterChip(label: $0, isSelected: $0 == "Tech", height: 30)
        }
    }
    .padding()
    .background(Palette.bg)
}
#endif
