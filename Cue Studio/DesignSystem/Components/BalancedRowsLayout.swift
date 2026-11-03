//
//  BalancedRowsLayout.swift
//  Cue Studio
//

import SwiftUI

/// Items in equal columns on the fewest rows where every one fits its column, its words shrunk at most to `minimumScale` (they carry a
/// `minimumScaleFactor` that far) and never cut: one row while they all fit, then two balanced rows (3 + 3), and so on (owner,
/// 02/11/2026: "Tam…", "Mar…" on Studio's bar; no label is ever cut, in any language or text size). A shorter last row is centered.
struct BalancedRowsLayout: Layout {
    var spacing: CGFloat = 8
    var minimumScale: CGFloat = 0.8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let ideals = subviews.map { $0.sizeThatFits(.unspecified).width }
        let width = proposal.width ?? (ideals.reduce(0, +) + spacing * CGFloat(subviews.count - 1))
        let grid = Self.grid(ideals: ideals.map { $0 * minimumScale }, in: width, spacing: spacing)
        let height = rowHeight(subviews, columnWidth: grid.columnWidth)
        return CGSize(width: width, height: CGFloat(grid.rows) * height + CGFloat(grid.rows - 1) * spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let ideals = subviews.map { $0.sizeThatFits(.unspecified).width * minimumScale }
        let grid = Self.grid(ideals: ideals, in: bounds.width, spacing: spacing)
        let height = rowHeight(subviews, columnWidth: grid.columnWidth)
        for (index, subview) in subviews.enumerated() {
            let row = index / grid.columns
            let column = index % grid.columns
            let inRow = min(grid.columns, subviews.count - row * grid.columns)
            // A shorter last row sits in the middle.
            let inset = CGFloat(grid.columns - inRow) * (grid.columnWidth + spacing) / 2
            let origin = CGPoint(
                x: bounds.minX + inset + CGFloat(column) * (grid.columnWidth + spacing),
                y: bounds.minY + CGFloat(row) * (height + spacing)
            )
            subview.place(at: origin, proposal: ProposedViewSize(width: grid.columnWidth, height: height))
        }
    }

    /// The fewest rows (and their columns) where each of `ideals` fits a column of `width`.
    static func grid(ideals: [CGFloat], in width: CGFloat, spacing: CGFloat) -> (rows: Int, columns: Int, columnWidth: CGFloat) {
        let count = max(1, ideals.count)
        for rows in 1...count {
            let columns = Int((Double(count) / Double(rows)).rounded(.up))
            let columnWidth = (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
            if ideals.allSatisfy({ $0 <= columnWidth }) || columns == 1 {
                return (Int((Double(count) / Double(columns)).rounded(.up)), columns, columnWidth)
            }
        }
        return (count, 1, width)
    }

    private func rowHeight(_ subviews: Subviews, columnWidth: CGFloat) -> CGFloat {
        subviews.map { $0.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height }.max() ?? 0
    }
}
